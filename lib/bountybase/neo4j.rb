require 'neography'
require_relative "neo4j/neography_extensions"
require_relative "neo4j/neography_curb"

module Bountybase::Neo4j
  extend self

  # Builds a Neo4j object from the value passed in. The value can be anything either
  # returned from a Cypher query or from any of the neography functions.
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
      return build_from_url(url)
    end

    Path.new hash 
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
  
  public
  
  # Executes a Cypher query with a single return value per returned selection. 
  # Returns an array of hashes. 
  def raw_query(query)
    result = logger.benchmark "cypher: #{query}" do
      connection.execute_query(query) || {"data" => []}
    end

    expect! result => Hash
    result.values_at("data", "columns")
  end
  
  def query(query)
    data, columns = *raw_query(query)
    
    data.map do |row|
      row = row.map { |item| 
        # If the row entry is a String, it is the result already, and not, as 
        # Neo4j.build would expect, the URL of a Neo4j node or relationship. The
        # same is true for all non-hashes.
        next item unless item.is_a?(Hash)
        build(item)
      }
      row = row.first if row.length == 1
      row
    end
  end
  
  def ask(query)
    (self.query(query) || []).first
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
