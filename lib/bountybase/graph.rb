require_relative "../event"

module Bountybase::Graph
end

require_relative "graph/twitter"

#
# The Graph module deals with everything related to building and querying
# the Bountytweet graph. The Bountytweet graph combines identities, tweets 
# and quests.
# 
# == Nodes
#
# All nodes are defined via a node *type* and a node *uid*. Each node 
# has *created_at* and *updated_at* timestamp attributes, that are
# set to the current time when creating respective updating the node.
# These timestamp attributes are stored as the number of seconds since 
# epoch.
#
# For more information see Neo4j::Node.
#
# == Relationships
#
# All relationships have a type, which is just a string. A relationship
# might have additional attributes; there are, however, no attributes
# defined by default.
#
# For more information see Neo4j::Relationship.
#
# == Node types
# 
# - *twitter_identities*: a twitter_identity denotes a user id on the twitter network.
#
#      twitter_identity = Neo4j::Node.find("twitter_identities", 123456)
#
#   Additional attributes include
#
#   - +screen_name+: the twitter user name.
#   - +updated_followees_at+: set to the current time when the 
#     followees of this node have been updated.
#
# - *quests*: a quest is defined by its numerical id. Currently a quest node
#   does not have any additional attributes. 
#
# - *tweets*: this is just a backstore of tweets received by the system for 
#   later inspection and analysis.
# 
# == Relationships between nodes.
#
# - <b><tt>forwarded_<NNN></tt></b>: The <tt>forwarded_<NNN></tt> 
#   relationship is set whenever the origin of the relationship - the 
#   <em>sender identity</em> - is forwarding or did forward the NNN quest
#   to the <em>receiving identity</em>. The relationship type is 
#   parametrized: the NNN part always contains the numerical id of the
#   quest. The reason for this is that the Cypher query language
#   allows to filter relationships by type, but not by attribute.
#   
#       quest     --[forwarded_NNN]-> identity
#       identity  --[forwarded_NNN]-> identity
# 
# - <b>+known_by+</b>: The +known_by+ relationship type is used whenever 
#   an identity is known to either know or being able to know about a quest. 
#   It is used to check whether or not an identity already knows about a 
#   specific quest. 
#
#   +known_by+ relationships are not strictly necessary: if an identity 
#   knows about a quest then it is also connected via a number of 
#   <tt>forwarded_<NNN></tt> relationships; so we might probably drop it.
# 
# - <b><tt>follows</tt></b>: The <tt>follows</tt> relationship tries
#   to model the social graph amongst identities in existing social networks. 
#   It is needed to find the source of the knowledge of a quest - where does
#   the user know the quest from? - when this source is not embedded in, say,
#   the tweet.
# 
#       identity --(follows)--> identity
# 
#   Relationships of this type are only created on demand due to the high cost:
#   Twitter only tells us about ~1.5 mio (at max) of such relationships per hour.
# 
module Bountybase::Graph
  extend self
  
  Neo4j = Bountybase::Neo4j

  # Setup the Neo4j database. Note that the neography gem, is not threadsafe;
  # therefore Neo4j.connection maintains one connection per thread. 
  def setup
    Neo4j.connection
  end

  # Returns the quest node for the quest with a given url. If the url
  # does not resolve to a quest, return nil.
  #
  #   Bountybase::Graph.quest(12)                                     # --> <quests/12>
  #   Bountybase::Graph.quest("http://bountyhill.com/quests/23")      # --> <quests/23>
  #
  def quest(url)
    quest_id = self.quest_id(url)
    Neo4j::Node.create("quests", quest_id) if quest_id
  end

  # resolves the URL of a quest into the quest's id. If the URL is a number
  # it is assumed to be the quest's id. If it is a bountyhill bounty URL,
  # the quest ID is taken from the URL directly; in any other case the method
  # tries to resolve the URL into a bountyhill quest URL.
  #
  #   Bountybase::Graph.quest_id(12)                                  # --> 12
  #   Bountybase::Graph.quest_id("http://bountyhill.com/quests/23")   # --> 23
  #   Bountybase::Graph.quest_id("http://google.com")                 # --> nil
  #
  def quest_id(url, allow_resolve = true)
    expect! url => [String, Integer]
    
    case url
    when Integer 
      url
    when /^(?:http|https):\/\/[a-z.]*\bbountyhill\.(?:com|local)\/(?:q|quest|quests)\/(\d+)\b/
      Integer($1)
    when /^(?:http|https):\/\/[a-z.]*\bbountyhill\.(?:com|local)\//
      nil
    else
      if allow_resolve
        quest_id Bountybase::HTTP.resolve(url), false 
      end
    end
  end

  # returns the quest ID for that URL, but raises an error if there is none.
  def quest_id!(url)
    self.quest_id(url) ||
      raise("This is not a quest ID: #{url.inspect}")
  end
  
  # returns the number of identities that have seen a specific quest.
  # The +quest+ parameter can be an URL or the ID of a quest.
  #
  #   Bountybase::Graph.propagation(12)                                  # --> a number
  #   Bountybase::Graph.propagation("http://bountyhill.com/quests/23")   # --> a number
  #   Bountybase::Graph.propagation("http://google.com")                 # --> raises exception
  #
  def propagation(quest)
    query = <<-CYPHER
      START src=node:quests(uid='#{quest_id!(quest)}')
      MATCH src-[:known_by]->target 
      RETURN count(*) 
    CYPHER
    
    Neo4j.ask(query) || 0
  end
  
  # returns the bounty chain from a quest to a (successful) vendor.
  #
  #   Graph.chain 12, 2345
  #   Graph.chain "http://bountyhill.com/quests/12", 2345
  #
  # Returns all nodes in the chain from <tt><quests/12></tt> to 
  # <tt><twitter_identities/2345></tt>; including the ending node 
  # (<tt><twitter_identities/2345></tt>), but omitting the starting
  # node (<tt><quests/12></tt>). 
  # 
  # Note that the +twitter_identity_id+ must be the numerical ID
  # of the twitter_identity for now. Expect this to change once we
  # support multiple identity types.
  def chain(quest, twitter_identity_id)
    expect! twitter_identity_id => Integer

    quest_id = self.quest_id!(quest)
    
    path = Neo4j.ask <<-CYPHER
      START quest=node:quests(uid='#{quest_id}'), target=node:twitter_identities(uid='#{twitter_identity_id}')
      MATCH p = quest-[:forwarded_#{quest_id}*]->target 
      RETURN p
    CYPHER
    
    if path
      # The first node in the returned path is the quest itself. 
      # All other nodes form the chain.
      path.nodes[1..-1]
    end
  end
end
