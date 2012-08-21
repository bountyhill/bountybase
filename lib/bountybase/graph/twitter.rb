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
    
    # Did we register this tweet already? If not, just keep it.
    return if Neo4j::Node.find("tweets", options[:tweet_id])
    Neo4j::Node.create("tweets", options[:tweet_id], options)

    # We have the id of the sender of the tweet. Get a node for it. Note: As we don't supply any
    # attributes, this would just return any existing node instead of recreating it.
    sender = identity(options[:sender_id], options[:sender_name])

    # The source has seen the quest: connect it if there is none yet.
    tweet_connection quest, sender

    # TODO: How does the sender know the quest? If the sender_id is not yet set,
    # then the sender probably knows it from one of its followees. find_sender_id
    # picks the sender_id from the array of followees of the source_id that are
    # known to have seen the quest, and then the followee that posted (or just
    # received) the quest first.
    if options[:source_id]
      source = identity(options[:source_id], options[:source_name]) 
      tweet_connection quest, source
    else
      source = find_source_by_quest_and_sender quest, sender
    end

    Neo4j.connect "forwarded_#{quest.uid}", (source || quest) => sender
  
    # If there are a number of additional receivers (i.e. accounts that have been mentioned
    # in the tweet, of which we assume that they will receive this tweet) we connect them
    # from the sender.
    receiver_ids, receiver_names = *options.values_at(:receiver_ids, :receiver_names)
    if receiver_ids
      receivers = receiver_ids.zip(receiver_names || []).map { |receiver_id, receiver_name| 
        identity(receiver_id, receiver_name) 
      }
      tweet_connection quest, sender, *receivers
    end
  end
  
  private
  
  def find_source_by_quest_and_sender(quest, sender)
    nil
  end
  
  def tweet_connection(quest, source, *receivers)
    expect! quest => Neo4j::Node, quest.type => "quests", source => Neo4j::Node, receivers => Array

    receivers.each { |receiver| expect! receiver => Neo4j::Node }

    known_by     = [ quest, source ]
    known_by    += receivers.map { |receiver| [ quest, receiver ] }.flatten
    Neo4j.connect "known_by", *known_by

    forwarded_to = receivers.map { |receiver| [ source, receiver ] }.flatten
    Neo4j.connect "forwarded_#{quest.uid}", *forwarded_to
  end
end
