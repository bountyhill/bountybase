require_relative "../event"

module Bountybase
  module Event
    # Prepare and setup event listeners and routes according to Bountybase environment.
    def self.setup
      ::Event::Listeners.add :console
      ::Event::Listeners.add :syslog, "logs.papertrailapp.com", 63689

      ::Event.route :all => :console
      ::Event.route Bountybase => :syslog
    end
  end

  def self.event_source_name
    nil
  end
end
