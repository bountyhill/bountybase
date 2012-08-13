require_relative 'test_helper'

class Neo4jTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def test_ping
    neo4j = Neography::Rest.new(Bountybase.config.neo4j)
    neo4j.ping
  end

  def test_ping_fails
    VCR.use_cassette('test_neo4j_ping_fails', :record => :once, :allow_playback_repeats => true) do
      assert_raise(SocketError) do 
        neo4j = Neography::Rest.new("http://i.dont.exist.test")
        neo4j.ping
      end
    end

    assert_raise(Errno::ECONNREFUSED) do
      neo4j = Neography::Rest.new("http://localhost:64642")
      neo4j.ping
    end
  end
end
