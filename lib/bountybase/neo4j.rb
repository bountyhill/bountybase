require 'neography'
require_relative "neo4j/neography_extensions"

module Bountybase::Neo4j
  extend self
  
  # returns a connection. Each thread has its own connection
  def connection
    Thread.current[:neography_connection] ||= connect_to_neo4j!
  end
  
  # Executes a Cypher query with a single return value per returned selection. 
  # Returns an array of hashes. 
  def query(query)
    result = connection.execute_query(query) || {"data" => []}
    expect! result => Hash
    nodes, columns = *result.values_at("data", "columns")
    nodes
  end
  
  private
  
  # connect to a database, return connection object
  def connect_to_neo4j! #:nodoc:
    url = Bountybase.config.neo4j
    expect! url => /[^\/]$/

    Neography::Rest.new(url).tap do |connection|
      next if @created_first_connection

      Bountybase.logger.benchmark :warn, "Connected to neo4j at", url, :min => 0 do
        connection.ping
      end

      @created_first_connection = true
    end
  end
end

require_relative "neo4j/base.rb"
require_relative "neo4j/node.rb"
require_relative "neo4j/relationship.rb"
require_relative "neo4j/connections.rb"
