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
    node1 = Neo4j::Node.create "foo", 1
    node2 = Neo4j::Node.create "bar", 1
    node3 = Neo4j::Node.create "foo2", 1
    node4 = Neo4j::Node.create "bar2", 1

    # This builds two named connections
    Neo4j::Connections.expects(:build).with "name", node1, node2, :attr => :value
    Neo4j::Connections.expects(:build).with "name", node3, node4, :attr => :value

    Neo4j.connect "name", node1 => node2, node3 => node4, :attr => :value
    
    # This builds two unnamed connections
    Neo4j::Connections.expects(:build).with nil, node1, node2, :attr => :value
    Neo4j::Connections.expects(:build).with nil, node3, node4, :attr => :value

    Neo4j.connect node1 => node2, node3 => node4, :attr => :value
    
    # This builds one unnamed connection
    Neo4j::Connections.expects(:build).with nil, node1, node2, :attr => :value

    Neo4j.connect node1, node2, :attr => :value
    
    # This builds two named connections
    Neo4j::Connections.expects(:build).with "name", node1, node2, :attr => :value
    Neo4j::Connections.expects(:build).with "name", node3, node4, :attr => :value

    Neo4j.connect "name", node1, node2, node3, node4, :attr => :value
  end
end
