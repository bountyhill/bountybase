require_relative "../event"

module Bountybase
  module Setup; end

  def self.setup
    Bountybase::Setup.logging
    Bountybase::Setup.resque
  end
end

module Bountybase::Setup
  # setup logging
  SYSLOG = {
    :production =>  [ "logs.papertrailapp.com", 11905 ],
    :staging =>     [ "logs.papertrailapp.com", 22076 ]
  }

  RESQUE = {
    :production   =>  "redis://bountyhill:8e7e2d80025989f1e163c94597437764@koi.redistogo.com:9617/", # TODO: use separate redis instance
    :staging      =>  "redis://bountyhill:8e7e2d80025989f1e163c94597437764@koi.redistogo.com:9617/", 
    :test         =>  "redis://localhost:9617/1",
    :development  =>  "redis://localhost:9617/2"
  }

  def self.logging
    # setup listeners
    ::Event::Listeners.add :console

    if syslog_args = SYSLOG[Bountybase.environment.to_sym]
      syslog_args.push :program => Bountybase.instance
      ::Event::Listeners.add :syslog, *syslog_args
    end

    # setup routes
    ::Event.route :all => :console
    ::Event.route Bountybase => :syslog
    
    # hello world!
    Bountybase.logger.warn "Starting event logging in #{Bountybase.environment.inspect} environment"
  end
  
  def self.resque
    url = RESQUE.fetch(Bountybase.environment.to_sym)
    Resque.redis = url
    Bountybase.logger.warn "Resque using redis at #{url}"
  end
end

