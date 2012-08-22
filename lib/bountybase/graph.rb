require_relative "../event"

module Bountybase::Graph
end

require_relative "graph/twitter"

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

  # Returns the quest node for the quest with a given url. If the url does not 
  # resolve to a quest, return nil.
  def quest(url)
    quest_id = self.quest_id(url)
    Neo4j::Node.create("quests", quest_id) if quest_id
  end

  # resolves the URL of a quest into the quest's id. If the URL is a number
  # it is assumed to be the quest's id. If it is a bountyhill bounty URL,
  # the quest ID is taken from the URL directly; in any other case the method
  # tries to resolve the URL into a bountyhill quest URL.
  def quest_id(url, allow_resolve = true)
    expect! url => [String, Integer]
    
    case url
    when Integer 
      url
    when /^(?:http|https):\/\/[a-z.]*\bbountyhill\.(?:com|local)\/quest\/(\d+)\b/
      Integer($1)
    when /^(?:http|https):\/\/[a-z.]*\bbountyhill\.(?:com|local)\//
      nil
    else
      quest_id Bountybase::HTTP.resolve(url), false if allow_resolve
    end
  end

  # returns the quest ID for that URL, but raises an error if there is none.
  def quest_id!(url)
    self.quest_id(url) ||
      raise("This is not a quest ID: #{url.inspect}")
  end
  
end
