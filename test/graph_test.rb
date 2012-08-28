require_relative 'test_helper'

class GraphTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def setup
    Graph::Twitter.stubs(:update_followees!).returns(nil)
    Neo4j.purge!
  end
  
  def test_argument_gets_checked
    assert_raise(ArgumentError) do  Graph::Twitter.register     end
    assert_raise(ArgumentError) do  Graph::Twitter.register({}) end
  end

  def one_tweet
    register_tweet :sender_id => 456, # The twitter user id of the user sent this tweet 
      :sender_name => "sender456"
  end

  def one_tweet_with_source
    register_tweet :source_id => 1000, :sender_id => 1001, :quest_url => "http://bountyhill.local/quest/1"
  end

  def two_tweets
    register_tweet :source_id => 1000, :sender_id => 1001, :quest_url => "http://bountyhill.local/quest/1"
    register_tweet :source_id => 1001, :sender_id => 1002, :quest_url => "http://bountyhill.local/quest/1"
  end

  def seven_tweets
    register_tweet :source_id => 1000, :sender_id => 1001, :quest_url => "http://bountyhill.local/quest/1"
    register_tweet :source_id => 1001, :sender_id => 1002, :quest_url => "http://bountyhill.local/quest/1"
    register_tweet :source_id => 1002, :sender_id => 1003, :quest_url => "http://bountyhill.local/quest/1"
    register_tweet :source_id => 1001, :sender_id => 1004, :quest_url => "http://bountyhill.local/quest/1"
    register_tweet :source_id => 1000, :sender_id => 1006, :quest_url => "http://bountyhill.local/quest/1"

    register_tweet :source_id => 1000, :sender_id => 1001, :quest_url => "http://bountyhill.local/quest/2"
    register_tweet :source_id => 1001, :sender_id => 1003, :quest_url => "http://bountyhill.local/quest/2"
  end

  def test_single_tweet
    one_tweet

    n = Neo4j::Node.find("twitter_identities", 456)
    assert_equal "sender456", n["screen_name"]

    relationships = Neo4j::Relationship.all.map(&:fetch)
    assert_equal 2, relationships.length
  end

  def test_single_tweet_with_source
    # The one_tweet_with_source is different from the one_tweet scenario in that
    # the tweet has a source which means the source would have known the quest
    # before already. It therefore will be connected to the quest, too.
    one_tweet_with_source

    # <quests/1                 -[:forwarded_1]-> twitter_identities/1000>
    # <twitter_identities/1000  -[:forwarded_1]-> twitter_identities/1001>
    # <quests/1                 -[:known_by]-> twitter_identities/1000>
    # <quests/1                 -[:known_by]-> twitter_identities/1001>
    
    assert_equal 2, Neo4j::Relationship.all(:forwarded_1).length
    assert_equal 0, Neo4j::Relationship.all(:forwarded_2).length
    assert_equal 2, Neo4j::Relationship.all(:known_by).length
  end

  def test_with_nonexisting_nodes
    two_tweets

    # The quest has propagated to 3 twitter identities: 1000, 1001, 1002
    assert_equal 0, Graph.propagation(2) 
    assert_equal nil, Graph.chain(1, 1006)  # non-existing twitter_identity
    assert_equal nil, Graph.chain(2, 1000)  # non-existing quest
  end
  
  def test_chain
    two_tweets

    # <quests/1                 -[:forwarded_1]-> twitter_identities/1000>
    # <twitter_identities/1000  -[:forwarded_1]-> twitter_identities/1001>
    # <twitter_identities/1001  -[:forwarded_1]-> twitter_identities/1002>

    assert_equal 3, Neo4j::Relationship.all(:forwarded_1).count

    # The quest has propagated to 3 twitter identities: 1000, 1001, 1002
    assert_equal 3, Graph.propagation(1) 

    assert_equal [1000], Graph.chain(1, 1000).map(&:uid)
    assert_equal [1000, 1001], Graph.chain(1, 1001).map(&:uid)
    assert_equal [1000, 1001, 1002], Graph.chain(1, 1002).map(&:uid)
  end
  
  def test_chain_1
    seven_tweets

    # <quests/1                -[:forwarded_1]-> twitter_identities/1000>
    # <twitter_identities/1000 -[:forwarded_1]-> twitter_identities/1001>
    # <twitter_identities/1001 -[:forwarded_1]-> twitter_identities/1002>
    # <twitter_identities/1002 -[:forwarded_1]-> twitter_identities/1003>
    # <twitter_identities/1001 -[:forwarded_1]-> twitter_identities/1004>
    # <twitter_identities/1000 -[:forwarded_1]-> twitter_identities/1006>
    #
    # <quests/2                -[:forwarded_2]-> twitter_identities/1000>
    # <twitter_identities/1000 -[:forwarded_2]-> twitter_identities/1001>
    # <twitter_identities/1001 -[:forwarded_2]-> twitter_identities/1003>
    
    # How many users have seen which quests?
    assert_equal 6, Graph.propagation(1)
    assert_equal 3, Graph.propagation(2)
    assert_equal 0, Graph.propagation(3)

    # Which users build which chain?
    assert_equal [1000, 1006], Graph.chain(1, 1006).map(&:uid)
    assert_equal [1000, 1001, 1002, 1003], Graph.chain(1, 1003).map(&:uid)
    assert_equal [1000, 1001, 1004], Graph.chain(1, 1004).map(&:uid)

    # Which users build which chain?
    assert_equal [1000, 1001], Graph.chain(2, 1001).map(&:uid)
    assert_equal [1000, 1001, 1003], Graph.chain(2, 1003).map(&:uid)
  end
end
