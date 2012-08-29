require_relative 'test_helper'

# Tests on how the graph is built from tweets. These tests should not
# access the Twitter API at all.
class GraphTwitterTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def setup
    Neo4j.purge!
    Graph::Twitter.stubs(:update_followees!).returns(nil)
    # Graph::Twitter.stubs(:update_followees!).returns(nil)
  end
  
  def test_register_tweet
    freeze_time(123457)
    
    # Register an initial tweet.
    register_tweet :sender_id => 456, :tweet_id => 1
  
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
        "quest_id"=>23,
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
      register_tweet :sender_id => 456

      #
      # The next tweet is a retweet of the initial tweet.
      register_tweet :sender_id => 789,   # The twitter user id of the user sent this tweet 
        :source_id => 456                 # The twitter user id of the user from where the sender knows about this bounty.
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
      paths = paths.sort_by { |p| p.end_node.uid }
      end_nodes = paths.map(&:end_node)
      
      assert_equal [ Neo4j::Node.find("twitter_identities", 456), Neo4j::Node.find("twitter_identities", 789) ], end_nodes
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

      paths = paths.sort_by { |p| p.end_node.uid }

      end_nodes = paths.map(&:end_node)
      assert_equal [ Neo4j::Node.find("twitter_identities", 456), Neo4j::Node.find("twitter_identities", 789) ], end_nodes
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
    register_tweet :sender_id => 456

    # The next tweet is a tweet of the same query; it doesn't have a 
    # source_id though; so we are trying to use the followees 
    # as returned by Twitter.
    register_tweet :sender_id => 789

    # The code is correct if both twitter identities are connected 
    # directly to the quest.

    paths = Neo4j.query <<-CYPHER
      START src=node(*), target=node(*)
      MATCH path = src-[:forwarded_23]->target 
      RETURN path
    CYPHER

    assert_equal [ Neo4j::Node.find("quests", 23), Neo4j::Node.find("quests", 23) ], 
      paths.map(&:start_node)
  end

  def test_twitter_with_sender
    # Register the initial tweet.
    register_tweet :sender_id => 456

    Bountybase::Graph::Twitter.expects(:source_for_tweet).
      returns(Graph::Twitter.identity(456))
      
    # The next tweet is a tweet of the same query; it doesn't have a 
    # source_id though; so we are trying to use the followees 
    # as returned by Twitter.
    register_tweet :sender_id => 789

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
    
    assert_equal Neo4j::Node.find("quests", 23), p0.start_node
    assert_equal Neo4j::Node.find("twitter_identities", 456), p0.end_node

    assert_equal Neo4j::Node.find("twitter_identities", 456), p1.start_node
    assert_equal Neo4j::Node.find("twitter_identities", 789), p1.end_node
  end

  def test_register_followees
    benchmark :warn, "register_followees", :min => 0 do
      Graph::Twitter.register_followees 20 => 1, 21 => 1, 22 => 1, 23 => 1, 24 => 1, 25 => 1
      Graph::Twitter.register_followees 20 => 2, 21 => 2, 32 => 2, 33 => 2, 34 => 2, 35 => 2
    end

    rels = Neo4j.query <<-CYPHER
      START src=node(*), target=node(*)
      MATCH path = src-[rel:follows]->target 
      RETURN rel
    CYPHER
    
    uids = rels.map do |rel|
      assert_equal "follows", rel.type
      assert_equal "twitter_identities", rel.start_node.type 
      assert_equal "twitter_identities", rel.end_node.type
      [rel.start_node.uid, rel.end_node.uid]
    end.sort_by do |start_uid, end_uid|
      (start_uid * 1000) + end_uid
    end
    
    expected = [ 
      [ 20, 1 ], [ 20, 2 ], [ 21, 1 ], [ 21, 2 ], [ 22, 1 ], 
      [ 23, 1 ], [ 24, 1 ], [ 25, 1 ], 
      [ 32, 2 ], [ 33, 2 ], [ 34, 2 ], [ 35, 2 ] 
    ]
    
    assert_equal(expected, uids)
  end
  
  def test_source_for_tweet
    freeze_time(2) 
    register_tweet :sender_id => 2, :quest_id => 1
    register_tweet :sender_id => 2, :quest_id => 2
    
    freeze_time(3) 
    register_tweet :sender_id => 1, :quest_id => 1

    freeze_time(4) 
    register_tweet :sender_id => 11, :quest_id => 3

    freeze_time(1)
    register_tweet :sender_id => 3, :quest_id => 1
    
    sender = Graph::Twitter.identity(10)
    Graph::Twitter.register_followees sender => [1, 2, 3]

    # connecting to quest 1: The identities 1, 2, and 3 follow quest 1;
    # the sender will be connected to identity #3, as it is the oldest
    quest = Neo4j::Node.find("quests", 1)

    source = Graph::Twitter.source_for_tweet(sender, quest)
    assert_equal(Graph::Twitter.identity(3), source)
    
    # connecting to quest 2: Only identity #2 follows that questM
    # the sender will be connected to identity #2.
    quest = Neo4j::Node.find("quests", 2)

    source = Graph::Twitter.source_for_tweet(sender, quest)
    assert_equal(Graph::Twitter.identity(2), source)
    
    # connecting to quest 3: None of the senders followees follow quest 3;
    # the sender will be connected directly to the quest.
    quest = Neo4j::Node.find("quests", 3)

    source = Graph::Twitter.source_for_tweet(sender, quest)
    assert_nil(source)
  end
end
