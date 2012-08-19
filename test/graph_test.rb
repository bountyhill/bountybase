require_relative 'test_helper'

class GraphTest < Test::Unit::TestCase
  include Bountybase::TestCase

  Graph = Bountybase::Graph
  Neo4j = Bountybase::Neo4j


  def setup
    Neo4j.purge!
  end
  
  def test_dummy
    assert_raise(ArgumentError) do  
      Graph.register_tweet 
    end
  end
  
  def test_simple_tweet
    logger.benchmark :warn, "register_tweet", :min => 0 do
      Graph.register_tweet :tweet_id => 123,                # The id of the tweet 
        :sender_id => 456,                                  # The twitter user id of the user sent this tweet 
        :source_id => 789,                                  # The twitter user id of the user from where the sender knows about this bounty.
        :quest_url => "http://bountyhill.local/quest/23",
        # :receiver_ids => [12, 34, 56],                      # An array of user ids of twitter users, that also receive this tweet.
        :text => "My first #bountytweet",                   # The tweet text
        :lang => "de"                                       # The tweet language
    end
  end
end
