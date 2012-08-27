require_relative 'test_helper'

class Neo4jInspectTest < Test::Unit::TestCase
  include Bountybase::TestCase

  Neo4j = Bountybase::Neo4j

  def setup
    Neo4j.purge!
  end

  def test_node
    Neo4j::Node.create("foo", 1)
    
    node = Neo4j::Node.find("foo", 1)
    assert node.inspect =~ /^<node:\d+>$/
    assert node.to_s =~ /^node:\d+$/

    node.fetch
    assert_equal "<foo/1>", node.inspect
    assert_equal "foo/1", node.to_s
  end

  def test_node_w_attributes
    Neo4j::Node.create "foo", 1, "bar" => "baz"

    node = Neo4j::Node.find("foo", 1)

    # neither to_s nor inspect do load attributes...
    assert node.inspect =~ /^<node:\d+>$/
    assert node.to_s =~ /^node:\d+$/
    assert !node.fetched?

    # ...but make use once they are loaded.
    node.fetch
    assert_equal "<foo/1 {bar: \"baz\"}>", node.inspect
    assert_equal "foo/1", node.to_s
  end

  def test_relationship
    foo1 = Neo4j::Node.create("foo", 1)
    foo2 = Neo4j::Node.create("foo", 2)
    Neo4j.connect foo1 => foo2
    
    relationship = Neo4j::Relationship.all.first

    # neither to_s nor inspect do load attributes...
    assert !relationship.fetched?
    assert relationship.inspect =~ /^<rel:\d+>$/
    assert relationship.to_s =~ /^rel:\d+$/
    assert !relationship.fetched?

    # ...but make use once they are loaded.
    relationship.fetch
    assert_equal "<foo/1 -[:connects]-> foo/2>", relationship.inspect
    assert_equal "-[:connects]->", relationship.to_s
  end
end
