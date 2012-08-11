require "fnordmetric"
require "fnordmetric/api"

module Bountybase
  def metrics
    @metrics ||= if config = Bountybase.config.fnordmetric
        Metrics.new(config)
      else
        Metrics::Dummy
      end
  end

  class Metrics
    module Dummy
      def self.method_missing(*args); end
    end

    # The api attribute is needed for testing. 
    attr :api #:nodoc:
    
    # Creates a new Metrics instance. The config parameter is a Hash with these keys:
    #
    # - "redis_url": the URL of the redis instance to talk to the fnordmetric instance
    # - "redis_prefix": the redis_prefix to use when talking to the fnordmetric instance
    # - "event_queue_ttl": how long should events live?
    #
    # These values are usually read from Bountybase.config.fnordmetric
    def initialize(config)
      # @source = Bountybase.instance
      @api = FnordMetric::API.new :redis_url       => config["redis_url"], 
                                  :redis_prefix    => config["redis_prefix"],  
                                  :event_queue_ttl => config["event_queue_ttl"] || 20

      Bountybase.logger.info "Connected to stats queue", config
    end

    def method_missing(sym, *args)
      api.event build_event(sym, *args)
    end
    
    def build_event(sym, *args)
      # parse arguments. These are valid combinations: [value, Hash], [value], [Hash], [none]
      options = args.last.is_a?(Hash) ? args.pop : {} 

      options[:_type] = sym.to_s =~ /^(.*)!$/ ? $1.to_sym : sym
      
      case args.length
      when 0 then :nop 
      when 1 then options[:value] = args.first
      else        raise ArgumentError, "Invalid number of arguments"
      end

      options
    end
  end
end
