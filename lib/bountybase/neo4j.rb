require 'neography'
require_relative "neo4j/neography_extensions"

module Bountybase::Neo4j
  extend self
  
  # returns a connection. Each thread has its own connection
  def connection
    Thread.current[:neography_connection] ||= connect!
  end
  
  # Executes a Cypher query with a single return value per returned selection. 
  # Returns an array of hashes. 
  def query(query)
    result = connection.execute_query(query) || {"data" => []}
    expect! result => Hash
    nodes, columns = *result.values_at("data", "columns")
    nodes
  end
  
  # returns the URLs of all matching nodes.
  #
  # Parameters: 
  # - pattern the pattern to match
  def nodes(pattern = "*")
    query("start n=node(#{pattern}) return n").map do |node|
      hash = node.first
      hash["self"]
    end
  end
  
  # returns the number of matching nodes.
  #
  # Parameters: see nodes
  def count(pattern = "*")
    query("start n=node(#{pattern}) return n").length
  end
  
  # purges all nodes and their relationships.
  #
  # Parameters: see nodes
  def purge!(pattern = '*')
    logger.benchmark :error, "purge" do
      nodes(pattern).map do |node|
        connection.delete_node! node
      end
    end
  end
  
  private
  
  # connect to a database, return connection object
  def connect! #:nodoc:
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
