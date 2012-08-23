#
# Everything that is in the graph related to Twitter
module Bountybase::Graph::Twitter
  extend self

  Neo4j = Bountybase::Neo4j
  Graph = Bountybase::Graph
    
  # Look up identity node, creates and/or updates it if necessary.
  #
  # If the node does not exist, it will be created.
  # If the node exists, and screen_name is set, the screen_name attribute will
  # be updated if necessary.
  def identity(uid, screen_name = nil)
    expect! uid => Integer, screen_name => [String, nil]

    if node = Neo4j::Node.find("twitter_identities", uid)
      if screen_name && node["screen_name"] != screen_name
        node["screen_name"] = screen_name
      end
      node
    else
      Neo4j::Node.create("twitter_identities", uid, "screen_name" => screen_name)
    end
  end
  
  # Register a bountytweet. Takes a option hash with these parameters:
  #
  # - *tweet-id*: the tweet id
  # - *sender-id*: the identity of the sender (e.g. "twitter://radiospiel"). This is the sender account.
  # - *source-id*: the identity of the source (e.g. "twitter://radiospiel"). This is the in_reply_to account
  # - *quest_url*: the URL of the bounty quest
  # - *receiver_ids*: an optional array of twitter user ids, that also receive this tweet
  # - *text*: the tweet text
  # - *lang*: the tweet language
  #
  def register(options = {})
    expect! options => {
      :tweet_id     => Integer,         # The id of the tweet 
      :sender_id    => Integer,         # The twitter user id of the user sent this tweet 
      :sender_name  => [String, nil],   # The twitter screen name of the user sent this tweet 
      :source_id    => [Integer, nil],  # The twitter user id of the user from where the sender knows about this bounty.
      :source_name  => [String, nil],   # The twitter screen name of the user from where the sender knows about this bounty.
      :quest_url    => /http.*$/,       # The url for the quest.
      :receiver_ids => [Array, nil],    # An array of user ids of twitter users, that also receive this tweet.
      :receiver_names => [Array, nil],  # An array of screen names of twitter users, that also receive this tweet.
      :text         => String,          # The tweet text
      :lang         => String           # The tweet language
    }

    # Is this really a quest?
    quest = Graph.quest options[:quest_url]
    return if quest.nil?
    
    # We don't have to register this tweet twice...
    return if Neo4j::Node.find("tweets", options[:tweet_id])
    Neo4j::Node.create("tweets", options[:tweet_id], options)

    sender = identity(options[:sender_id], options[:sender_name])

    # If the sender is not yet connected then we must connect it, preferably via an
    # extra source node. If there is no source, then the sender probably knows the
    # quest directly from the website, and is therefore entitled to a direct
    # connection to the quest.
    unless connected?(quest, sender)
      Neo4j.connect "known_by", quest, sender, :created_at => Time.now.to_i

      source = tweet_source(quest, options)
      Neo4j.connect "forwarded_#{quest.uid}", (source || quest) => sender
    end 

    # connect additional receivers
    receiver_ids = options[:receiver_ids] || []
    receiver_names = options[:receiver_names] || []

    receiver_ids.each_with_index do |receiver_id, idx|
      receiver_name = receiver_names[idx] 
      receiver = identity(receiver_id, receiver_name) 
      next if connected?(quest, receiver)
      
      Neo4j.connect "known_by", quest, receiver, :created_at => Time.now.to_i
      Neo4j.connect "forwarded_#{quest.uid}", quest, sender
    end
  end
  
  private

  def connected?(quest, receiver)
    expect! quest => Neo4j::Node, receiver => Neo4j::Node
    
    Neo4j.ask <<-CYPHER
      START src=node:quests(uid='#{quest.uid}'), target=node:twitter_identities(uid='#{receiver.uid}')
      MATCH src-[relationship:known_by]->target 
      RETURN relationship
    CYPHER
  end
  
  # How does the sender know the quest? If the source_id is not set, then the sender
  # probably knows it from one of its followees. This methods picks the all user ids
  # from the followees of source_id that are known to already have seen the quest. If
  # there is more than one of such followees the followee that posted (or just received)
  # the quest first - by evaluating the created_at attribute of the :known_by relationship.
  #
  # This method also guarantees that the source is properly connected to the quest by
  # connecting if needed. This can only occur if the source is set via the :source_id
  # option.
  def tweet_source(quest, options)
    if options[:source_id]
      source = identity(options[:source_id], options[:source_name]) 
      unless connected?(quest, source)
        Neo4j.connect "known_by", quest, source, :created_at => Time.now.to_i
        Neo4j.connect "forwarded_#{quest.uid}", quest => source
      end
      source
    else
      find_source_by_quest_and_sender quest, options
    end
  end
  
  def find_source_by_quest_and_sender(quest, options)
    nil
  end
end
