require_relative 'test_helper'

class GraphTwitterTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def setup
    Neo4j.purge!
  end
  
  def test_register_tweet
    freeze_time(123457)
    
    # Register an initial tweet.
    register_tweet :tweet_id => 1, :sender_id => 456
  
    # This creates 3 nodes:
    # the node for the quest with id 23
    # the node for the twitter user account #456
    # the node for the tweet
    assert_equal(3, Neo4j::Node.count)

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

    # We should have two paths now; e.g.
    #
    # - <node#22868: quests#23> --[<rel#4400:known_by>]--> <node#22869: twitter_identities#456>
    # - <node#22868: quests#23> --[<rel#4401:forwarded_23>]--> <node#22869: twitter_identities#456>
    
    paths = Neo4j.query <<-CYPHER
    START src=node:quests(uid='23'), target=node(*)
    MATCH path = src-[*]->target 
    RETURN path
CYPHER
    assert_equal 2, paths.length

    forwarded_paths = Neo4j.query <<-CYPHER
        START src=node:quests(uid='23'), target=node(*)
        MATCH path = src-[:forwarded_23]->target 
        RETURN path
    CYPHER

    assert_equal 1, forwarded_paths.length
    assert_equal 1, forwarded_paths[0].length
  end

  def test_register_two_tweets
    # Register two tweets. This generates 5 paths
    #
    # <<quests#23> --[<known_by>]--> <twitter_identities#456>>,
    # <<quests#23> --[<forwarded_23>]--> <twitter_identities#456>>,
    # <<quests#23> --[<known_by>]--> <twitter_identities#456> --[<forwarded_23>]--> <twitter_identities#789>>,
    # <<quests#23> --[<known_by>]--> <twitter_identities#789>>,
    # <<quests#23> --[<forwarded_23>]--> <twitter_identities#456> --[<forwarded_23>]--> <twitter_identities#789>>]
    logger.benchmark :warn, "register 2 tweets", :min => 0 do
      # Register the initial tweet.
      register_tweet :tweet_id => 1, :sender_id => 456

      #
      # The next tweet is a retweet of the initial tweet.
      register_tweet :tweet_id => 123, # The id of the tweet 
        :sender_id => 789,             # The twitter user id of the user sent this tweet 
        :source_id => 456              # The twitter user id of the user from where the sender knows about this bounty.
    end
    
    logger.benchmark :warn, "querying 2 tweet results", :min => 0 do

      paths = Neo4j.query <<-CYPHER
        START src=node:quests(uid='23'), target=node(*)
        MATCH path = src-[:known_by]->target 
        RETURN path
      CYPHER

      # The query above returns
      #
      # <<quests#23> --[<known_by>]--> <twitter_identities#456>>,
      # <<quests#23> --[<known_by>]--> <twitter_identities#789>>,
      paths = paths.sort_by { |p| p.end.uid }
      
      assert_equal [ Neo4j::Node.find("twitter_identities", 456), Neo4j::Node.find("twitter_identities", 789) ], paths.map(&:end)
      assert_equal([1, 1], paths.map(&:length))
#
      paths = Neo4j.query <<-CYPHER
        START src=node:quests(uid='23'), target=node(*)
        MATCH path = src-[:forwarded_23*]->target 
        RETURN path
      CYPHER

      # The query above returns
      #
      # <<quests#23> --[<forwarded_23>]--> <twitter_identities#456>>,
      # <<quests#23> --[<forwarded_23>]--> <twitter_identities#456> --[<forwarded_23>]--> <twitter_identities#789>>]

      paths = paths.sort_by { |p| p.end.uid }

      assert_equal [ Neo4j::Node.find("twitter_identities", 456), Neo4j::Node.find("twitter_identities", 789) ], paths.map(&:end)
      assert_equal([1, 2], paths.map(&:length))
    end
  end

  def test_twitter_names
    node1 = Graph::Twitter.identity(123, "foo")
    node2 = Neo4j::Node.find("twitter_identities", 123)
    assert_equal node1, node2
    assert_equal "twitter_identities", node2["type"]
    assert_equal "foo", node2["screen_name"]
  end

  def test_twitter_name_updates
    Graph::Twitter.identity(123)
    node = Neo4j::Node.find("twitter_identities", 123)
    assert_equal nil, node["screen_name"]

    Graph::Twitter.identity(123, "foo")
    node = Neo4j::Node.find("twitter_identities", 123)
    assert_equal "foo", node["screen_name"]

    Graph::Twitter.identity(123, "bar")
    node = Neo4j::Node.find("twitter_identities", 123)
    assert_equal "bar", node["screen_name"]

    Graph::Twitter.identity(123)
    node = Neo4j::Node.find("twitter_identities", 123)
    assert_equal "bar", node["screen_name"]
  end
  
  def test_twitter_with_no_sender
    # Register the initial tweet.
    register_tweet :tweet_id => 1, :sender_id => 456

    Bountybase::Graph::Twitter.expects(:find_source_for_tweet).returns(nil)
      
    # The next tweet is a tweet of the same query; it doesn't have a 
    # source_id though; so we are trying to use the followees 
    # as returned by Twitter.
    register_tweet :tweet_id => 123,
      :sender_id => 789

    # The code is correct if both twitter identities are connected 
    # directly to the quest.

    paths = Neo4j.query <<-CYPHER
      START src=node(*), target=node(*)
      MATCH path = src-[:forwarded_23]->target 
      RETURN path
    CYPHER

    assert_equal [ Neo4j::Node.find("quests", 23), Neo4j::Node.find("quests", 23) ], 
      paths.map(&:start)
  end

  def test_twitter_with_sender
    # Register the initial tweet.
    register_tweet :tweet_id => 1, :sender_id => 456

    Bountybase::Graph::Twitter.expects(:find_source_for_tweet).
      returns(Graph::Twitter.identity(456))
      
    # The next tweet is a tweet of the same query; it doesn't have a 
    # source_id though; so we are trying to use the followees 
    # as returned by Twitter.
    register_tweet :tweet_id => 123,
      :sender_id => 789

    # The code is correct if both twitter identities are connected 
    # directly to the quest.

    paths = Neo4j.query <<-CYPHER
      START src=node(*), target=node(*)
      MATCH path = src-[:forwarded_23]->target 
      RETURN path
    CYPHER

    W "paths", paths.each(&:fetch)
    assert_equal(2, paths.length)
    p0, p1 = *paths
    
    assert_equal Neo4j::Node.find("quests", 23), p0.start
    assert_equal Neo4j::Node.find("twitter_identities", 456), p0.end

    assert_equal Neo4j::Node.find("twitter_identities", 456), p1.start
    assert_equal Neo4j::Node.find("twitter_identities", 789), p1.end
  end

  def test_register_followers
    Graph::Twitter.register_followers 1 => [20, 21, 22, 23, 24, 25], 
                                      2 => [20, 21, 32, 33, 34, 35]

    rels = Neo4j.query <<-CYPHER
      START src=node(*), target=node(*)
      MATCH path = src-[rel:follows]->target 
      RETURN rel
    CYPHER
    
    assert_equal 12, rels.length
    assert_equal 12, rels.map(&:start_node).uniq.length
    assert_equal  2, rels.map(&:end_node).map(&:uid).uniq.length
  end
end
