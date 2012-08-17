require 'neography'
require_relative "neo4j/neography_extensions"

module Bountybase::Neo4j
  extend self

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
        item = Path.new(item) || item
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
