require 'neography'
require_relative "neo4j/neography_extensions"
require_relative "neo4j/neography_curb"

module Bountybase::Neo4j
  extend self

  def build(neography)
    expect! neography => [String, Hash]

    case neography
    when String then build_from_url(neography) 
    when Hash   then 
      if neography.key?("self")
        build_from_url(neography["self"])
      elsif neography.key?("start")
        Path.new neography 
      else
        expect! neography => :fail
      end
    end
  end
  
  private
  
  def build_from_url(url)
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
    
    data = data.map do |row|
      row = row.map do |item|
        if item.key?("start")
          item = Path.new(item)
        end
      end
    
      row = row.first if row.length == 1
      row
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
