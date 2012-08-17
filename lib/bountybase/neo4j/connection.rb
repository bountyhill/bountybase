module Bountybase::Neo4j
  module Connection
    # returns a connection. Each thread has its own connection
    def connection
      Thread.current[:neography_connection] ||= Connection.connect!
    end

    private

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

Bountybase::Neo4j.extend Bountybase::Neo4j::Connection
