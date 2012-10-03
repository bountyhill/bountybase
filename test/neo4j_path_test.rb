require_relative 'test_helper'

class Neo4jPathTest < Test::Unit::TestCase
  include Bountybase::TestCase

  Neo4j = Bountybase::Neo4j

  def setup
    Neo4j.purge!
  end

  def test_can_connect
    foo1 = Neo4j::Node.create "foo", 1
    bar1 = Neo4j::Node.create "bar", 1

    assert_equal(0, Neo4j::Relationship.count)

    Neo4j.connect "name", foo1 => bar1
    assert_equal(1, Neo4j::Relationship.count)

    Neo4j.connect "other_name", foo1 => bar1
    assert_equal(2, Neo4j::Relationship.count)
  end

  def test_find_paths
    foo1 = Neo4j::Node.create "foo", 1, :foo1 => "foo1"
    bar1 = Neo4j::Node.create "bar", 1, :bar1 => "bar1"
    Neo4j.connect "name", foo1 => bar1

    results = Neo4j.query <<-CYPHER
    START src=node:foo(uid='1'), target=node:bar(uid='1')
    MATCH path = src-[*]->target 
    RETURN path
CYPHER

    assert_equal(1, results.length)
    path = results.first

    assert_kind_of(Neo4j::Path, path)
    
    assert_equal foo1,            path.start_node
    assert_equal foo1.attributes, path.start_node.attributes

    assert_equal bar1,            path.end_node
    assert_equal bar1.attributes, path.end_node.attributes

    assert_equal 3, path.members.length
  end
  
  def test_cannot_connect_to_itself
    foo1 = Neo4j::Node.create "foo", 1
    foo2 = Neo4j::Node.create "foo", 1
  
    assert_equal(0, Neo4j::Relationship.count)

    Neo4j.connect "name", foo1 => foo2
    assert_equal(0, Neo4j::Relationship.count)
  end
  
  def test_cannot_connect_twice
    foo1 = Neo4j::Node.create "foo", 1
    bar1 = Neo4j::Node.create "bar", 1

    assert_equal(0, Neo4j::Relationship.count)

    Neo4j.connect "name", foo1 => bar1
    assert_equal(1, Neo4j::Relationship.count)

    Neo4j.connect "other_name", foo1 => bar1
    assert_equal(2, Neo4j::Relationship.count)

    Neo4j.connect "name", foo1 => bar1
    assert_equal(2, Neo4j::Relationship.count)
  end
  
  def test_connect
    foo1 = Neo4j::Node.create "foo", 1
    bar1 = Neo4j::Node.create "bar", 1
    foo2 = Neo4j::Node.create "foo", 2
    bar2 = Neo4j::Node.create "bar", 2

    # This builds two named connections
    Neo4j.connect "name", foo1, bar1, foo1 => foo2, foo2 => bar2, :attr => :value
    
    assert_equal(3, Neo4j::Relationship.count)
    Neo4j::Relationship.all.each do |rel|
      assert_equal rel.attributes, "attr" => "value"
      assert_equal "name", rel.type
    end
  end
  
  def test_query_rel
    foo1 = Neo4j::Node.create "foo", 1
    bar1 = Neo4j::Node.create "bar", 1

    Neo4j.connect foo1 => bar1

    # return the path
    assert_equal 1, Neo4j::Relationship.count
    relationship = Neo4j::Relationship.all.first
    assert_kind_of Neo4j::Relationship, relationship
    assert_equal("-foo/1->bar/1", relationship.rid)
  end

  def test_query_path
    foo1 = Neo4j::Node.create "foo", 1
    bar1 = Neo4j::Node.create "bar", 1
    bar2 = Neo4j::Node.create "bar", 2

    Neo4j.connect "alongconnectiontypename", foo1 => bar1, bar1 => bar2

    # return the path
    results = Neo4j.query <<-CYPHER
    START src=node:foo(uid='1'), target=node:bar(uid='2')
    MATCH path = src-[*]->target 
    RETURN path
CYPHER

    # we should have two result.
    assert_equal(1, results.length)
    assert_equal([Neo4j::Path], results.map(&:class))

    path = results.first

    assert_equal(foo1, path.start_node)
    assert_equal(bar2, path.end_node)
    assert_equal([foo1, bar1, bar2], path.nodes)
  end

  def test_two_connections
    foo1 = Neo4j::Node.create "foo", 1
    bar1 = Neo4j::Node.create "bar", 1
    foo2 = Neo4j::Node.create "foo", 2
    bar2 = Neo4j::Node.create "bar", 2

    # assert_equal 4, Neo4j::Node.count

    Neo4j.connect foo1 => bar1, bar1 => bar2
    Neo4j.connect foo1 => foo2, foo2 => bar2

    # return the path
    results = Neo4j.query <<-CYPHER
    START src=node:foo(uid='1'), target=node:bar(uid='2')
    MATCH path = src-[*]->target 
    RETURN path
CYPHER

    # we should have two result.
    assert_equal(2, results.length)
    assert_equal([Neo4j::Path, Neo4j::Path], results.map(&:class))
  end

  def build_graph(options)
    count, factors = *options.values_at(:count, :factors)
    expect! count => Integer, factors => Array
  
    nodes = Bountybase.logger.benchmark :warn, "Creating #{count} nodes" do
      (0...count).map do |i|
        Neo4j::Node.create "foo", i
      end
    end

    Bountybase.logger.benchmark :warn, "Connecting nodes" do |benchmark|
      connections = 0

      # connect each node to its 2x node

      factors.each do |factor|
        nodes.each_with_index do |node, idx|
          next if idx == 0
          target = nodes[idx * factor]
          next unless target

          Neo4j.connect node => target
          connections += 1
        end
      end

      benchmark.message += " (#{connections} connections)"
    end
  end

  def test_graph
    build_graph :count => 70, :factors => [2,3,5]
    
    assert_equal(1, count_paths(1, 2))
    assert_equal(1, count_paths(1, 4))
    assert_equal(2, count_paths(1, 6))
    assert_equal(0, count_paths(1, 72))
    
    assert_equal([2,3,5].permutation.to_a.uniq.length, count_paths(1, 2*3*5))
    assert_equal([2,2,3,5].permutation.to_a.uniq.length, count_paths(1, 2*2*3*5))

    Neo4j.purge!
  end
  
  def test_graph_1000
    return unless performance_tests?
    
    build_graph :count => 1_000, :factors => [2,3,5,7]

    find_paths 1, 2
    find_paths 1, 4
    find_paths 1, 6
    find_paths 1, 72
    find_paths 1, 512
    find_paths 0, 9216
    find_paths 0, 61740

    Neo4j.purge!
  end
  
  def test_huge_graphs
    return unless performance_tests?
    return
    
    build_graph :count => 100_000, :factors => [2,3,5,7]

    find_paths 1, 2
    find_paths 1, 4
    find_paths 1, 6
    find_paths 1, 72
    find_paths 1, 512
    find_paths 1, 9216
    find_paths 1, 61740

    Neo4j.purge!
  end
  
  def count_paths(from, to)
    find_paths(from, to).length
  end
  
  def find_paths(from, to)
    Bountybase.logger.benchmark :warn, "path #{from} => #{to}", :min => 0 do |benchmark|
      query = <<-CYPHER
        START src=node:foo(uid='#{from}'), target=node:foo(uid='#{to}')
        MATCH path = src-[*]->target 
        RETURN path
        CYPHER
      
      results = Neo4j.query(query)
      benchmark.message += " #{results.length} results"
      results
    end
  end
end
