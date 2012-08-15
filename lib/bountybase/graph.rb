require_relative "../event"

module Bountybase::Graph
end

require_relative "graph/neo4j_base"
require_relative "graph/neo4j_objects"

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
    
  # Connect this thread to Neo4j
  def setup
    Neo4j.connection
  end
  
  # whenever a bountytweet is found we add some connections in the graph database.
  #
  # These are the parameters:
  #
  # - *tweet-id*: the tweet id
  # - *quest*: the URL of the quest
  # - *sender-id*: the identity of the sender (e.g. "twitter://radiospiel"). This is the sender account.
  # - *sender-name*: the identity of the sender (e.g. "twitter://radiospiel"). This is the sender account.
  # - *source-id*: the identity of the source (e.g. "twitter://radiospiel"). This is the in_reply_to account
  # - *source-name*: the identity of the source (e.g. "twitter://radiospiel"). This is the in_reply_to account
  # - (e.g. "twitter://radiospiel"): an array of identities that we assume will have received the tweet (i.e. accounts
  #   that have been mentioned in the tweet.)
  # - *text*: the tweet text
  # - *lang*: the tweet language 
  #
  # The sender and source parameters might seem confusing. This is their meaning:
  # If the sender is just retweeting the source is who it is retweeting from.
  
  # a) source has been seen the quest, from an unknown source.
  # b) sender has been seen the quest, from source
  #
  def register_tweet(options = {})
    expect! options, 
      :tweet_id => Integer,
      :quest_url => String,
      :sender_id => Integer,
      :sender => String,
      :source_id => Integer,
      :source => String,
      :receivers => [Array, nil],
      :text => String,
      :lang => String
      
    return if registered_tweet?(tweet)
    
    # register the tweet itself.
    connect tweet_root => tweet

    # How does sender know the quest? If it is not set, then probably from one of
    # its followees.
    source ||= if connection = oldest_connection(quest => sender.followees)
      connection[:receiver]
    end
    #
    # If there is a source then we'll make sure the source is connected
    # to the quest. 
    if source
      unless connected?(quest => source)
        connect quest => source, :by => tweet        # source has seen the quest.
      end
      unless connected?(quest => sender)
        connect source => sender, :by => tweet       # sender has received the quest.
      end
    else
      # if not, the sender will be directly connected to the quest.
      unless connected?(quest, sender)
        connect quest => sender, :by => tweet
      end
    end
  end

  #
  # find a connection from quest to account. This returns an array with these entries:
  #
  # [ { :source => source, :dest => dest, :connected_at => Timestamp }]
  #
  def connections(options)
    connections, options = *parse_options(options)
    nil
  end

  def oldest_connection(options)
    connections = self.connections(quest => sender.followees)
    connections.sort_by { |connection| connection[:connected_at] }.first
  end

  # build connection(s)
  def connect(options)
    connections, options = *parse_options(options)
    options = Hash[*options]

    connections.each do |src, dest| 
      Single.connect(source, dest, options)
    end
  end
  
  # returns true if any of the passed in connections exist.
  def connected?(options)
    connections, options = *parse_options(options)
    connections.any? do |source, dest|
      Single.connected?(source, dest, options)
    end
  end

  # Deal with individual connections.
  module Single
    def self.connected?(source, dest, options)
      by = options[:by]
    end

    def self.connect(src, dest, options)
      by = options[:by]
    end
  end
  
  # Splits all key/value pairs in the options hash depending on whether or not they
  # have Symbol keys - meaning these are options instead of connections - and returns
  # both groups. 
  def parse_options(options) #:nodoc:
    options, connections = options.partition { |k,v| k.is_a?(Symbol) }
    [ connections, Hash[options] ]
  end
end
