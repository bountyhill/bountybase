require_relative "../event"

module Bountybase::Graph
end

#
# The Graph module deals with everything related to building and querying the Bountytweet graph.
# The Bountytweet graph combines identities, tweets and quests.
# 
# ## Node types
# 
# - *"identities"*: an identity is defined by an identity id string, which consists of two parts: the name of the social network
#   and the identifier in that network, for example "twitter://1234". Additional attributes include 
#   - `screen_name`
#   - `updated_followers_at`
# - *"quests"*: a quest is defined by its numerical id. Additional attributes include 
#   - `authoritative_url`
# - *"tweets"*: this is just a backstore of tweets received by the system for later inspection and analysis.
# 
# All nodes have additional *"created_at"* and *"updated_at"* timestamp attributes.
# 
# All timestamp attributes `"*_at"` are stored as the number of seconds since epoch.
# 
# ## Relationships between nodes.
# 
# ### `known_by`
# 
# The `known_by` relationship is set whenever we know that an identity knows about a quest (or could have known about a quest). 
# We use this relationship to check whether or not an identity already knows about a specific quest. This is probably optional.
# 
#     quest --(known_by)--> identity
# 
# ### `forwarded_<NNN>_to`
#     
# The `forwarded_<NNN>_to` relationship is a directed relationship, set whenever the origin of the relationship - the *sender identity* - 
# forwards or has forwarded the NNN quest to the *receiving identity*. The   
#   
#     quest --(forwarded_NNN_to)--> identity
#     identity --(forwarded_NNN_to)--> identity
# 
# This relationship type is parametrized - adding a new relationship type per quest. The reason for this is that 
# the Cypher query language allows to filter relationships by type, but not by its attributes.
# 
# ### `follows`/`followed_by`
#     
# The `follows` and `followed_by` relationships try to model the relationships amongst identities in existing social networks. 
# This information is needed when trying to register tweets without knowing who was that tweet's origin, because in that case
# we try to find the origin within the sender's followees.
# 
#     identity --(follows)--> identity
#     identity --(followed_by)--> identity
# 
# Relationships of this type are only created on demand due to the high cost of calculation involved: Twitter only
# tells us about ~1.5 mio (at max) of such relationships per hour.
# 
# # Object management
# 
# - All nodes are connected to a root node.
# - Each node is indexed in an index named after its node type ("identities", "quests"), 
#   with an "uid" attribute which expresses the unique id of that node. 
# - Additional, nonunique indices might be introduced at a later point.
# 
# # Cypher code examples
# 
# ## find all shortest path from quest NNN to target node, limited at a length of 7 identities.
# 
#     START quest=node:quests(uid = quest.uid), target=node:identities(uid = identity.uid)
#     MATCH paths = allShortestPaths( (quest)-[:forwarded_NNN_to*:8]->(target) ) 
#     RETURN paths
# 
# Note that we'll have only a single path (or none) from each quest to each identity:
# 
#     START quest=node:quests(uid = quest.uid), target=node:identities(uid = identity.uid)
#     MATCH path = shortestPath( (quest)-[:forwarded_NNN_to*:8]->(target) ) 
#     RETURN path
# 
# ### Is an identity connected to a quest?
# 
# With the shortcut `known_by` relationship type:
# 
#     START quest=node:quests(uid = quest.uid), target=node:identities(uid = identity.uid)
#     MATCH (quest)-[relationship:known_by]->(target)
#     RETURN relationship
# 
# returns `null` when these two are not connected.
# 
module Bountybase::Graph
  extend self
  
  Neo4j = Bountybase::Neo4j

  # Connect this thread to Neo4j
  def setup
    Neo4j.connection
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
  def register_tweet(options = {})
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

    return if Neo4j::Node.find("tweets", options[:tweet_id])
    Neo4j::Node.create("tweets", options[:tweet_id], options)

    connect_tweet(options)
  end
  
  def connect_tweet(options)
    quest_id = Bountybase.resolve_quest_url(options[:quest_url])

    # get a quest node. Note: As we don't supply any attributes, this would
    # just return any existing node instead of recreating it.
    quest = Neo4j::Node.create("quests", quest_id)

    # We have the id of the sender of the tweet. Get a node for it. Note: As we don't supply any
    # attributes, this would just return any existing node instead of recreating it.
    sender_id, sender_name = *options.values_at(:sender_id, :sender_name)
    sender = twitter_identity(sender_id, sender_name)

    # The source has seen the quest: connect it if there is none yet.
    tweet_connection quest, sender

    # TODO: How does the sender know the quest? If the sender_id is not yet set,
    # then the sender probably knows it from one of its followees. find_sender_id
    # picks the sender_id from the array of followees of the source_id that are
    # known to have seen the quest, and then the followee that posted (or just
    # received) the quest first.
    source_id, source_name = *options.values_at(:source_id, :source_name)
    source_id ||= find_sender_id_for :quest_id => quest_id, :from_followees_of => sender_id
    
    # if we know the source we connect the quest to it.
    if source_id
      source = twitter_identity(source_id, source_name) 
      tweet_connection quest, source
    end

    Neo4j.connect "forwarded_#{quest.uid}", (source || quest) => sender
  
    # If there are a number of additional receivers (i.e. accounts that have been mentioned
    # in the tweet, of which we assume that they will receive this tweet) we connect them
    # from the sender.
    receiver_ids, receiver_names = *options.values_at(:receiver_ids, :receiver_names)
    if receiver_ids
      receivers = receiver_ids.zip(receiver_names || []).map { |receiver_id, receiver_name| 
        twitter_identity(receiver_id, receiver_name) 
      }
      tweet_connection quest, sender, *receivers
    end
  end

  def find_sender_id_for(options)
    nil
  end
  
  # Look up twitter_identity node, creates and/or updates it if necessary.
  #
  # If the node does not exist, it will be created.
  # If the node exists, and screen_name is set, the screen_name attribute will
  # be updated if necessary.
  def twitter_identity(uid, screen_name = nil)
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
  
  def tweet_connection(quest, source, *receivers)
    options = receivers.last.is_a?(Hash) ? receivers.pop : {}
    
    expect! quest => Neo4j::Node, quest.type => "quests", source => Neo4j::Node, receivers => Array

    receivers.each { |receiver| expect! receiver => Neo4j::Node }

    known_by     = [ quest, source ]
    known_by    += receivers.map { |receiver| [ quest, receiver ] }.flatten
    Neo4j.connect "known_by", *known_by, options

    forwarded_to = receivers.map { |receiver| [ source, receiver ] }.flatten
    Neo4j.connect "forwarded_#{quest.uid}", *forwarded_to, options
  end
end
