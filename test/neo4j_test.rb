require_relative 'test_helper'
require 'vcr'

class Neo4jTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def neo4j(url=nil)
    @neo4j = nil if url
    @neo4j ||= Neography::Rest.new(url || Bountybase.config.neo4j)
  end
  
  def test_ping
    assert_nothing_raised() { neo4j.ping }
  end

  def test_ping_fails
    VCR.use_cassette('test_neo4j_ping_fails', :record => :once, :allow_playback_repeats => true) do
      assert_raise(SocketError) do 
        neo4j("http://i.dont.exist.test").ping
      end
    end

    assert_raise(Errno::ECONNREFUSED) do
      neo4j("http://localhost:64642").ping
    end
  end

  def test_index_creation_and_deletion
    neo4j.create_node_index("foo_index")
    assert_equal true, Bountybase::Graph::Neo4j.node_indices.include?("foo_index")

    neo4j.delete_node_index("foo_index")
    assert_equal false, Bountybase::Graph::Neo4j.node_indices.include?("foo_index")
  end
  
end
