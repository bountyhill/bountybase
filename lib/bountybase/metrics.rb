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

    def method_missing(sym, *args)
      return super if block_given? || args.length > 2
      
      if sym.to_s =~ /^(.*)!$/
        count! sym, *args
      else
        gauge! sym, *args
      end
    end
    
    def count!(name, value = 1, options = nil)
      data = { :value => value, :source => @source, :type => :counter }
      data = options.merge(data) if options

      queue.add name => data
    end
    
    def gauge!(name, value, options = nil)
      data = { :value => value, :source => @source, :type => :gauge }
      data = options.merge(data) if options

      queue.add name => data
    end
  end
end
