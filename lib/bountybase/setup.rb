require_relative "../event"

module Bountybase
  module Setup; end

  def self.setup
    Bountybase::Setup.logging
    Bountybase::Setup.resque
  end
end

# The Bountybase setup module initializes all services needed by several Bountybase components.
# The configuration for those is read from Bountybase.config, which in turns reads it from
# lib/bountybase/config.rb.
module Bountybase::Setup
  def self.logging
    # setup listeners
    ::Event::Listeners.add :console

    if syslog_args = Bountybase.config.syslog
      ::Event::Listeners.add :syslog, *syslog_args
    end

    # setup routes
    ::Event.route :all => :console
    ::Event.route Bountybase => :syslog
    
    # hello world!
    Bountybase.logger.warn "Starting event logging in #{Bountybase.environment.inspect} environment"
  end
  
  def self.resque
    url = Bountybase.config.resque || raise("Missing resque configuration")
    Bountybase.logger.info "Connecting to resque at", url

    Resque.redis = url
    Resque.redis.ping

    Bountybase.logger.benchmark("Resque using redis at: #{url.inspect}", 0) do
      Resque.redis.ping
    end
  end
end
