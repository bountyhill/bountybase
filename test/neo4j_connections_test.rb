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
end
