module Bountybase::Neo4j
  # returns a connection to a Neo4j server. As neography connections
  # are not threadsafe, each thread manages its own connection object.
  def self.connection
    Thread.current[:neography_connection] ||= Connection.connect!
  end
  
  module Connection #:nodoc:
    # connect to a database, return connection object
    def self.connect! #:nodoc:
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
end
