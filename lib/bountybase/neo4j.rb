require 'neography'
require_relative "neo4j/neography_extensions"
require_relative "neo4j/neography_curb"

module Bountybase::Neo4j
  extend self

  # Executes a Cypher query with a single return value per returned selection. 
  # This method is for internal use only; it is used, e.g. in the 
  # Neo4j::Node::Finder module.
  def raw_query(query) #:nodoc:
    logger.benchmark "cypher: #{query}" do
      result = connection.execute_query(query)
      if result
        result["data"]
      else
        []
      end
    end
  end
  
  # Run a cypher query, returning an array of values. 
  #
  # Usually the returned array contains a single Array per returned row.
  # If a row contains only a single value - because the CYPHER query's 
  # +RETURN+ clause contains only a single expression, the returned array
  # contains those values directly. 
  # 
  # The query method builds corresponding Neo4j::Node, Neo4j::Relationship,
  # or Neo4j::Path objects, if these are returned from the query.
  #
  #   targets = Neo4j.ask <<-CYPHER
  #     START src=node:quests(uid='12')
  #     MATCH src-[:known_by]->target 
  #     RETURN target
  #   CYPHER
  def query(query)
    raw_query(query).map do |row|
      row = row.map do |item| 
        # If the row entry is a String, it is the result already, and not, as 
        # Neo4j.build would expect, the URL of a Neo4j node or relationship. The
        # same is true for all non-hashes.
        next item unless item.is_a?(Hash)
        build_from_hash(item)
      end
      
      row = row.first if row.length == 1
      row
    end
  end
  
  # Run a cypher query, returning a single value. 
  #
  # In contrast to Neo4j.query this method is intended to query only a 
  # single value from the Neo4j database. It therefore does not need to
  # return an array, but can just return the query result. 
  #
  # It returns a Neo4j::Node, Neo4j::Relationship, or Neo4j::Path object
  # if necessary.
  #
  # This method returns +nil+ if there is no value to return.
  #
  #   count = Neo4j.ask <<-CYPHER
  #     START src=node:quests(uid='#{quest_id!(quest)}')
  #     MATCH src-[:known_by]->target 
  #     RETURN count(*) 
  #   CYPHER
  def ask(query)
    (self.query(query) || []).first
  end
  
  # Builds a Neo4j object from the value passed in. The value can be anything either
  # returned from a Cypher query or from any of the neography functions. 
  # <b>This does not create anything in the Neo4j database, it just builds a 
  # ruby representation of what is in the database!</b> To create a node use Node.create,
  # to create a relationship use Neo4j.connect.
  #
  # Note that a string denotes just the string itself if this is a query result, 
  # or the URL of a Neo4j object otherwise.
  def build(neography)
    expect! neography => [String, Hash]

    case neography
    when String   then build_from_url(neography) 
    when Hash     then build_from_hash(neography)
    else          neography
    end
  end
  
  private
  
  def build_from_hash(hash) #:nodoc:
    expect! {
      hash["self"] || hash["start"]
    }
    
    if url = hash["self"]
      build_from_url(url)
    else
      Path.new hash
    end
  end
  
  def build_from_url(url) #:nodoc:
    # the URL, as reported from Neo4j, describes the type of an object.
    # URL examples are:
    # - http://localhost:7474/db/data/node/1426  
    # - http://localhost:7474/db/data/relationship/1426  
    kind = url.split("/")[-2]
    expect! kind => [ "node", "relationship" ]
    case kind
    when "node"         then Node.new(url)
    when "relationship" then Relationship.new(url)
    end
  end
  

end

require_relative "neo4j/connection.rb"
require_relative "neo4j/base.rb"
require_relative "neo4j/base_attributes.rb"
require_relative "neo4j/connection.rb"
require_relative "neo4j/node.rb"
require_relative "neo4j/node_classmethods.rb"
require_relative "neo4j/node_finder.rb"
require_relative "neo4j/purge.rb"
require_relative "neo4j/relationship.rb"
require_relative "neo4j/connections.rb"
require_relative "neo4j/path.rb"
