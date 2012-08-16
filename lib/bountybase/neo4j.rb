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
  def raw_query(query)
    result = logger.benchmark "cypher: #{query}" do
      connection.execute_query(query) || {"data" => []}
    end

    expect! result => Hash
    result.values_at("data", "columns")
  end
  
  def query(query)
    data, columns = *raw_query(query)
    # expect! columns.length => 1
    
    data = data.map do |row|
      row = row.map do |item|
        item = Path.new(item) || item
      end
    
      row = row.first if row.length == 1
      row
    end
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

  class Path < OpenStruct
    def self.new(hash)
      start, nodes, length, relationships, end_ = *hash.values_at(*%w(start nodes length relationships end))
      
      return unless start && end_
      super hash
    end
    
    def urls
      urls = []
      nodes.each_with_index do |node_url, index|
        urls << relationships[index - 1] if index > 0
        urls << node_url
      end
      urls
    end
    
    def inspect
      index = -1
      "<" + urls.map do |url|
        index += 1
        url = url.gsub "http://localhost:7474/db/data/", ""
        if index.even?
          url
        else
          "--[#{url.gsub("relationship", "rel")}]-->"
        end
      end.join(" ") + ">"
    end
  end
end

require_relative "neo4j/base.rb"
require_relative "neo4j/node.rb"
require_relative "neo4j/relationship.rb"
require_relative "neo4j/connections.rb"
