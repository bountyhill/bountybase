require 'neography'
require_relative "neography_extensions"

module Bountybase::Graph::Neo4j
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
  
  NODE_INDEX_NAME = "node_index"
  
  def node_index
    @node_index_created ||= begin
      unless node_indices.include?(NODE_INDEX_NAME)
        connection.create_node_index(NODE_INDEX_NAME)
      end
      NODE_INDEX_NAME
    end
  end

  def node_indices
    connection.list_node_indexes.keys
  end
  
  private
  
  def known_node_indices #:nodoc:
    @known_node_indices ||= []
  end
  
  def create_node_index(name)
    unless known_node_indices.include?(name)
      connection.create_node_index(name)
      known_node_indices << name
    end
  end
  
  public
  
  # create a node of a given type. This
  #
  # a) creates an index for that type, if that is needed,
  # b) creates the node uniquely with the given uid within this index
  #
  def create_node(index, uid, options = {})
    expect! { options.keys.all? { |k| k.is_a?(String) } }
    
    create_node_index index
    
    options.update "uid" => uid

    # Add node to index with the given key/value pair
    connection.create_unique_node(index, "uid", uid, options).tap do |attrs|
      if !attrs
        raise("Object cannot be created: #{uid}")
      elsif attrs["data"] != options
        # ap attrs["data"]
        # ap options
        raise(DuplicateKeyError, "Object already exists #{uid}") 
      end
    end
  end
  
  class DuplicateKeyError < RuntimeError; end
  
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