require_relative 'test_helper'
require 'vcr'

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
    assert_equal(0, Neo4j::Node.count)
  end
  
  def test_purging_w_existing_relationships
    foo1 = Neo4j::Node.create "foo", 1
    bar1 = Neo4j::Node.create "bar", 1
    foo2 = Neo4j::Node.create "foo", 2
    bar2 = Neo4j::Node.create "bar", 2

    Neo4j.connect foo1 => bar1, bar1 => bar2
    Neo4j.connect foo1 => foo2, foo2 => bar2

    assert_equal 4, Neo4j::Node.count
    Neo4j.purge!
    assert_equal 0, Neo4j::Node.count
  end
end
