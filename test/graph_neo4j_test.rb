require_relative 'test_helper'

::Event::Listeners.add :console
::Event.route :all => :console

class Neo4jTest < Test::Unit::TestCase
  include Bountybase::TestCase

  Neo4j = Bountybase::Graph::Neo4j
  
  def setup
    Neo4j.purge!
  end
  
  def teardown
  end

  def test_database_is_empty
    assert_equal(0, Neo4j.count)
  end

  def test_node_attributes_must_have_string_keys
    assert_raise(ArgumentError) {  
      Neo4j.create_node "bar", 1, :bar => :baz
    }
  end
    
  def test_create_node
    Neo4j.create_node "foo", 1
    assert_equal(1, Neo4j.count)

    # can create a different node
    Neo4j.create_node "foo", 2
    assert_equal(2, Neo4j.count)

    # creating an already existing identical node is ignored.
    Neo4j.create_node "foo", 1
    assert_equal(2, Neo4j.count)

    # cannot create with the same uid and a different set of attributes
    assert_raise(Neo4j::DuplicateKeyError) do
      Neo4j.create_node "foo", 1, "bar" => "baz"
    end
    
    assert_equal(2, Neo4j.count)

    # but can create an identical node in a different "namespace", i.e. 
    # in a different index.
    Neo4j.create_node "bar", 1, "bar" => "baz"
    
    # assert_equal(0, Bountybase::Graph::Neo4j.count)
  end
end
