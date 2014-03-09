require_relative "../event"

module Bountybase
  module Setup; end

  def self.setup
    Bountybase::Setup.logging
    Bountybase::Setup.resque
    # Bountybase::Setup.neo4j

    W "Prepared Bountybase Version #{Bountybase::VERSION}/#{Bountybase.environment}"
  end
end

# The Bountybase setup module initializes all services needed by several Bountybase components.
# The configuration for those is read from Bountybase.config, which in turns reads it from
# lib/bountybase/config.rb.
module Bountybase::Setup
  # Setup logging.
  #
  # logging is routed so, that all Events are sent to the console,
  # and those Events logged at Bountybase are sent to the syslog. The
  # syslog configuration is read from *Bountybase.config.syslog*.
  #
  #   # The syslog configuration, per environment an array of [ hostname, port ] 
  #   syslog:
  #     deployment:
  #       - logs.papertrailapp.com
  #       - 61566
  #     production:
  #       - logs.papertrailapp.com
  #       - 11905
  #     staging:
  #       - logs.papertrailapp.com
  #       - 22076
  #
  # The syslog is disabled in the "test" environment.
  def self.logging
    # setup console
    ::Event::Listeners.add :console
    ::Event.route :all => :console

    # setup syslog
    if Bountybase.environment != "test"
    
      if syslog_args = Bountybase.config.syslog
        ::Event::Listeners.add :syslog, *syslog_args
        ::Event.route Bountybase => :syslog
      end
    end
    
    # hello world!
    Bountybase.logger.warn "Starting event logging in #{Bountybase.environment.inspect} environment"
  end
  
  # Setup resque.
  #
  # Set up the Resque configuration. This uses the resque configuration key; which should
  # contain the URL of the redis database to use; e.g.
  #
  #   resque:
  #     deployment:   none
  #     production:   redis://bountyhill:XXXXXX@koi.redistogo.com:9617/
  #     staging:      redis://bountyhill:XXXXXX@koi.redistogo.com:9617/
  #     test:         redis://localhost:6379/1
  #     development:  redis://localhost:6379/2
  #
  # An entry "none" specifies that Resque is not to be used. In that case 
  # trying to use it results in an exception.
  def self.resque
    if redis = redis_for(:resque)
      Resque.redis = redis
    else
      def Resque.redis
        raise "Cannot use resque in #{Bountybase.environment} mode"
      end
    end
  end

  # connect to a Redis instance for a given mode, returning a
  # Redis::Namespace object. 
  def self.redis_for(what)
    return unless url = Bountybase.config.redis_for(what)

    Bountybase.logger.warn "Connecting to #{what} redis at", url
    Redis::Namespace.connect(url).tap(&:roundtrip)
  end
  
  # returns a normalized version of the redis config setting.
  def self.redis
    @redis ||= redis_for(:bountybase)
  end

  # Setup connection to the neo4j database.
  #
  # This uses the Bountybase.config.neo4j value under the hood. (See Neo4j.connect!)
  def self.neo4j
    Bountybase::Graph.setup
  end
end
