require "librato/metrics"

module Bountybase
  def metrics
    Thread.current["bountybase-metrics"] ||= Metrics.create_instance
  end

  class Metrics
    module Dummy
      def self.method_missing(*args); end
    end

    def self.config
      if config = Bountybase.config.librato
        config.values_at("username", "apikey")
      end
    end
    
    def self.create_instance
      if config = self.config
        Metrics.new(*config)
      else
        Metrics::Dummy
      end
    end

    AUTOSUBMIT_INTERVAL = 60
    
    attr :queue
    
    def initialize(username, apikey)
      Librato::Metrics.authenticate username, apikey
      @queue = Librato::Metrics::Queue.new(:autosubmit_interval => AUTOSUBMIT_INTERVAL)
      @metrics_types = {}
      @source = Bountybase.instance
      
      at_exit { submit }
    end

    # clears the queue
    def clear #:nodoc:
      queue.clear
    end

    # submits the queue
    def submit
      return if queue.empty?
      queue.submit
    end

    # setup a named counter
    def counter!(name)
      @metrics_types[name] = :counter
    end
    
    # setup a named gauge
    def gauge!(name)
      @metrics_types[name] = :gauge
    end

    def method_missing(sym, *args)
      return super if block_given? || args.length > 2
      queue! sym, *args
    end
    
    def queue!(name, value = nil, options = nil)
      type = @metrics_types[name] || raise(NameError, "Unknown metrics value #{name.inspect}")

      case value || type
      when :gauge   then raise(ArgumentError, "Missing value for #{name.inspect} gauge")
      when :counter then value = 1
      else          # value is already set
      end

      data = {
        :value => value,
        :source => @source,
        :type => type
      }

      data = options.merge(data) if options

      queue.add name => data
    end
  end
end
