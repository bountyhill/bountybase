require_relative "../event"

module Bountybase
  # Bountybase::Event sets up event listeners and routes depending on the app environment.
  module Event
    extend self
    
    # Prepare and setup event listeners and routes according to Bountybase environment.
    def setup_listeners
      ::Event::Listeners.add :console

      environment = Bountybase.environment
      if self.respond_to? environment
        self.send environment
      end
    end
    
    def setup_routes
      ::Event.route :all => :console
      ::Event.route Bountybase => :syslog
    end

    def setup
      setup_listeners
      setup_routes
      
      Bountybase.logger.warn "Starting event logging in #{Bountybase.environment.inspect} environment"
    end

    def production
      ::Event::Listeners.add :syslog, "logs.papertrailapp.com", 11905, :program => Bountybase.instance 
    end

    def staging
      ::Event::Listeners.add :syslog, "logs.papertrailapp.com", 22076, :program => Bountybase.instance
    end
    
    def test
      ::Event::Listeners.add :syslog, "logs.papertrailapp.com", 39262, :program => Bountybase.instance
    end
    
    def development
      ::Event::Listeners.add :syslog, "logs.papertrailapp.com", 61566, :program => Bountybase.instance
    end
  end

  def self.event_source_name
    nil
  end
end
