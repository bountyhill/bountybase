require_relative "../event"
require 'neography'

class Neography::Rest
  # The ping method tries to contact the Neo4J server and verifies the expected result.
  def ping
    url = @protocol + @server + ':' + @port.to_s + @directory
    ping = evaluate_response HTTParty.get(url, @authentication.merge(@parser))
    
    raise "Cannt ping neo4j database at #{ping_url}" unless ping.is_a?(Hash) && ping.keys.include?("data")
    ping
  end
end

#
# The Graph module deals with everything related to building and querying the Bountytweet graph.
module Bountybase::Graph
  extend self
  
  module Neo4J
    extend self
    
    # returns a connection. Each thread has its own connection
    def connection
      Thread.current[:neography_connection] ||= connect!
    end
    
    # Executes a Cypher query with a single return value per returned selection. 
    # Returns an array of hashes. 
    def query(query)
      result = connection.execute_query(query)
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
      execute_query("start n=node(#{pattern}) return n").length
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
  
  # Purge all nodes in the Neo4J database
  def purge!
    Neo4J.purge!
  end
    
  # Connect this thread to Neo4J
  def setup
    Neo4J.connection
  end
  
  # whenever a bountytweet is found we add some connections in the graph database.
  #
  # These are the parameters:
  #
  # - *tweet-id*: the tweet id
  # - *quest*: the URL of the quest
  # - *sender*: the identity of the sender (e.g. "twitter://radiospiel"). This is the sender account.
  # - *source*: the identity of the source (e.g. "twitter://radiospiel"). This is the in_reply_to account
  # - (e.g. "twitter://radiospiel"): an array of identities that we assume will have received the tweet (i.e. accounts
  #   that have been mentioned in the tweet.)
  # - *text*: the tweet text
  # - *lang*: the tweet language 
  #
  # The sender and source parameters might seem confusing. This is their meaning:
  # If the sender is just retweeting the source is who it is retweeting from.
  
  # a) source has been seen the quest, from an unknown source.
  # b) sender has been seen the quest, from source
  #
  def register_tweet(options = {})
    # register the tweet itself.
    connect tweet_root => tweet

    # How does sender know the quest? If it is not set, then probably from one of
    # its followees.
    source ||= if connection = oldest_connection(quest => sender.followees)
      connection[:receiver]
    end
    #
    # If there is a source then we'll make sure the source is connected
    # to the quest. 
    if source
      unless connected?(quest => source)
        connect quest => source, :by => tweet        # source has seen the quest.
      end
      unless connected?(quest => sender)
        connect source => sender, :by => tweet       # sender has received the quest.
      end
    else
      # if not, the sender will be directly connected to the quest.
      unless connected?(quest, sender)
        connect quest => sender, :by => tweet
      end
    end
  end

  #
  # find a connection from quest to account. This returns an array with these entries:
  #
  # [ { :source => source, :dest => dest, :connected_at => Timestamp }]
  #
  def connections(options)
    connections, options = *parse_options(options)
    nil
  end

  def oldest_connection(options)
    connections = self.connections(quest => sender.followees)
    connections.sort_by { |connection| connection[:connected_at] }.first
  end

  # build connection(s)
  def connect(options)
    connections, options = *parse_options(options)
    options = Hash[*options]

    connections.each do |src, dest| 
      Single.connect(source, dest, options)
    end
  end
  
  # returns true if any of the passed in connections exist.
  def connected?(options)
    connections, options = *parse_options(options)
    connections.any? do |source, dest|
      Single.connected?(source, dest, options)
    end
  end

  # Deal with individual connections.
  module Single
    def self.connected?(source, dest, options)
      by = options[:by]
    end

    def self.connect(src, dest, options)
      by = options[:by]
    end
  end
  
  # Splits all key/value pairs in the options hash depending on whether or not they
  # have Symbol keys - meaning these are options instead of connections - and returns
  # both groups. 
  def parse_options(options) #:nodoc:
    options, connections = options.partition { |k,v| k.is_a?(Symbol) }
    [ connections, Hash[options] ]
  end
end
