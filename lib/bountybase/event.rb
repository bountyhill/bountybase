require_relative "../event"

module Bountybase
  def self.event_source_name #:nodoc:
    nil
  end

  # Shortcuts to be included in Object. These can be used like
  #
  #   I "Starting application"
  #   E "Something is broken, at this URL", url
  #
  module EventShortcuts
    # Generates a log event at *error* severity.
    def E(*args, &block); Event.deliver :error, Bountybase.logger, *args, &block; end

    # Generates a log event at *warn* severity.
    def W(*args, &block); Event.deliver :warn,  Bountybase.logger, *args, &block; end

    # Generates a log event at *info* severity.
    def I(*args, &block); Event.deliver :info,  Bountybase.logger, *args, &block; end

    # Generates a log event at *debug* severity.
    def D(*args, &block); Event.deliver :debug, Bountybase.logger, *args, &block; end
  end
end

class Object
  include Bountybase::EventShortcuts
end
