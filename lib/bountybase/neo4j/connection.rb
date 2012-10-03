module Bountybase::Neo4j
  # returns a connection to a Neo4j server. As neography connections
  # are not threadsafe, each thread manages its own connection object.
  def self.connection
    Thread.current[:neography_connection] ||= connect!
  end

  # connect to the Neo4j database, return Neography connection object.
  #
  # Note: The URL to connect to is read from the Bountybase.config.neo4j
  # setting.
  def self.connect! #:nodoc:
    url = Bountybase.config.neo4j
    expect! url => [ /[^\/]$/, nil ]

    return NoConnection unless url

    connection = Neography::Rest.new(url)

    Bountybase.logger.benchmark :warn, "Connected to neo4j at", url, :min => 0 do
      connection.ping
    end

    connection
  end
  
  module NoConnection
    def self.method_missing(*args)
      raise "No Neo4j connection was configured in the #{Bountybase.environment.inspect} environment."
    end
  end
end
