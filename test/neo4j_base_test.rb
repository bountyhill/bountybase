require_relative 'test_helper'
require 'vcr'

# ::Event::Listeners.add :console
# ::Event.route :all => :console

class Neo4jBaseTest < Test::Unit::TestCase
  include Bountybase::TestCase

  Neo4j = Bountybase::Neo4j
  
  def setup
    Neo4j.purge!
  end
  
  def teardown
  end

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

  def test_database_is_empty
    assert_equal(0, Neo4j.count)
  end
end
