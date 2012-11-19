require_relative 'test_helper'

# Test that twitter followees are built correctly. This uses a prerecorded
# Twitter API response.
class GraphTwitterFolloweesTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def setup
    Neo4j.purge!
  end

  def test_update_followees
    benchmark :warn, "register followees" do |bm| 
      assert_equal 0, Neo4j::Node.count

      # 11754212 is radiospiel's user id. The recorded sample has 220 followers.
      VCR.use_cassette('followees_11754212', :record => :once, :allow_playback_repeats => true) do
        Graph::Twitter.update_followees(Graph::Twitter.identity(11754212))
      end

      # we now have 1 node for identity 11754212 and 220 followee nodes.  
      assert_equal 226, Neo4j::Node.count
      assert_equal 225, Neo4j::Relationship.count(:follows)
    end
  end
end
