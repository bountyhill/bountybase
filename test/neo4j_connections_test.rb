require_relative 'test_helper'

::Event::Listeners.add :console
::Event.route :all => :console

class Neo4jConnectionsTest < Test::Unit::TestCase
  include Bountybase::TestCase

  Neo4j = Bountybase::Neo4j

  def setup
    Neo4j::Node.purge!
  end

  def test_connection_api
    foo1 = Neo4j::Node.create "foo", 1
    bar1 = Neo4j::Node.create "bar", 1
    foo2 = Neo4j::Node.create "foo", 2
    bar2 = Neo4j::Node.create "bar", 2

    # This builds two named connections
    Neo4j::Connections.expects(:build).with "name", foo1, bar1, :attr => :value
    Neo4j::Connections.expects(:build).with "name", foo2, bar2, :attr => :value

    Neo4j.connect "name", foo1 => bar1, foo2 => bar2, :attr => :value
    
    # This builds two unnamed connections
    Neo4j::Connections.expects(:build).with 'connects', foo1, bar1, :attr => :value
    Neo4j::Connections.expects(:build).with 'connects', foo2, bar2, :attr => :value

    Neo4j.connect foo1 => bar1, foo2 => bar2, :attr => :value
    
    # This builds one unnamed connection
    Neo4j::Connections.expects(:build).with 'connects', foo1, bar1, :attr => :value

    Neo4j.connect foo1, bar1, :attr => :value
    
    # This builds two named connections
    Neo4j::Connections.expects(:build).with "name", foo1, bar1, :attr => :value
    Neo4j::Connections.expects(:build).with "name", foo2, bar2, :attr => :value

    Neo4j.connect "name", foo1, bar1, foo2, bar2, :attr => :value
  end
  
  def test_connection
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

    ap results.inspect
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

    Neo4j::Node.purge!
  end
  
  def test_huge_graphs
    return
    
    build_graph :count => 100_000, :factors => [2,3,5,7]

    find_paths 1, 2
    find_paths 1, 4
    find_paths 1, 6
    find_paths 1, 72
    find_paths 1, 512
    find_paths 1, 9216
    find_paths 1, 61740

    Neo4j::Node.purge!
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
