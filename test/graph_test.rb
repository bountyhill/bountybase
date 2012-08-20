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
  
  def test_register_tweet
    # Register two tweets. 
    
    freeze_time(123457)

    # Register the initial tweet.
    Graph.register_tweet :tweet_id => 1,                  # The id of the tweet 
      :sender_id => 456,                                  # The twitter user id of the user sent this tweet 
      :quest_url => "http://bountyhill.local/quest/23",
      # :receiver_ids => [12, 34, 56],                      # An array of user ids of twitter users, that also receive this tweet.
      :text => "My first #bountytweet",                   # The tweet text
      :lang => "en"                                       # The tweet language
  
    # This creates 3 nodes:
    # the node for the quest with id 23
    # the node for the twitter user account #456
    # the node for the tweet
    assert_equal(3, Neo4j::Node.count)
    pp Neo4j::Node.all.map(&:uuid)

    assert_not_nil n = Neo4j::Node.find("quests", 23)
    assert_equal n.attributes, "created_at"=>123457, "type"=>"quests", "uid"=>23

    assert_not_nil n = Neo4j::Node.find("tweets", "1")
    assert_equal n.attributes, "created_at"=>123457,
        "lang"=>"en",
        "quest_url"=>"http://bountyhill.local/quest/23",
        "sender_id"=>456,
        "text"=>"My first #bountytweet",
        "tweet_id"=>1,
        "type"=>"tweets",
        "uid"=>1
        
    assert_not_nil n = Neo4j::Node.find("twitter_identities", 456)
    assert_equal n.attributes, "created_at"=>123457, "type"=>"twitter_identities", "uid"=>456
    
#    pp Neo4j::Node.all.each(&:attributes)
  end

  def test_register_two_tweets
    return
    
    # Register two tweets. 
    logger.benchmark :warn, "register_tweet", :min => 0 do
      # Register the initial tweet.
      Graph.register_tweet :tweet_id => 1,                  # The id of the tweet 
        :sender_id => 456,                                  # The twitter user id of the user sent this tweet 
        :quest_url => "http://bountyhill.local/quest/23",
        # :receiver_ids => [12, 34, 56],                      # An array of user ids of twitter users, that also receive this tweet.
        :text => "My first #bountytweet",                   # The tweet text
        :lang => "en"                                       # The tweet language

      #
      # The next tweet is a retweet of the initial tweet.
      Graph.register_tweet :tweet_id => 123,                # The id of the tweet 
        :sender_id => 789,                                  # The twitter user id of the user sent this tweet 
        :source_id => 456,                                  # The twitter user id of the user from where the sender knows about this bounty.
        :quest_url => "http://bountyhill.local/quest/23",
        # :receiver_ids => [12, 34, 56],                      # An array of user ids of twitter users, that also receive this tweet.
        :text => "My first #bountytweet",                   # The tweet text
        :lang => "en"                                       # The tweet language
    
      pp Neo4j::Node.all.each(&:attributes)
    end
  end
end
