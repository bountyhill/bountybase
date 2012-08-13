require_relative "../event"

#
# The Graph module deals with everything related to building and querying the Bountytweet graph.
module Bountybase::Graph
  extend self
  
  def setup
    # connect to neo4j database
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
