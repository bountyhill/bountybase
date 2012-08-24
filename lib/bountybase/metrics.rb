require "fnordmetric"
require "fnordmetric/api"

module Bountybase
  #
  # Returns the global Metrics object. It is used to update counters - 
  # the name ends in a bang - and set gauges:
  #
  #     Bountybase.metrics.pageviews!                         # increment counter
  #     Bountybase.metrics.pageviews! :foo => :bar            # increment counter
  #     Bountybase.metrics.processing_time 20                 # set gauge
  #     Bountybase.metrics.processing_time 20, :foo => :bar   # set gauge, w attributes
  # 
  # The configuration is usually read from the <tt>Bountybase.config.fnordmetric</tt>
  # setting. If there is no fnordmetric setting, metrics are ignored.
  #
  # Which gauges and counters are actually useful for the stats module is
  # not configured here, but is part of the +bountystats+ application.
  def metrics
    @metrics ||= if config = Bountybase.config.fnordmetric
        Metrics.new(config)
      else
        Metrics::Dummy
      end
  end

  #
  # The API endpoint for the Bountybase metrics object. There is usually
  # a single Metrics instance, which can be accessed via Bountybase.metrics.
  # 
  #     Bountybase.metrics.pageviews!                         # increment counter
  #     Bountybase.metrics.pageviews! :foo => :bar            # increment counter
  #     Bountybase.metrics.processing_time 20                 # set gauge
  #     Bountybase.metrics.processing_time 20, :foo => :bar   # set gauge, w attributes
  #
  # Its configuration is usually read from the <tt>Bountybase.config.fnordmetric</tt>
  # setting, and uses these entries: 
  #
  # - +redis_url+: the URL of the redis instance used to connect 
  #   this application to the fnordmetric instances.
  # - +redis_prefix+: the redis_prefix used to connect this 
  #   application to the fnordmetric instances.
  # - +event_queue_ttl+: how long should events live? This defaults
  #   to Metrics::EVENT_QUEUE_DEFAULT_TTL
  class Metrics
    
    # A dummy module, just eats all method calls doing nothing. Used as a Metrics
    # standin when there is no configuration.
    module Dummy #:nodoc:
      def self.method_missing(*args); end
    end
    
    # Default event_queue_ttl setting.
    EVENT_QUEUE_DEFAULT_TTL = 20

    # The api attribute is needed for testing. 
    attr :api #:nodoc:
    
    # Creates a new Metrics instance. 
    def initialize(config) #:nodoc:
      @api = FnordMetric::API.new :redis_url       => config["redis_url"], 
                                  :redis_prefix    => config["redis_prefix"],  
                                  :event_queue_ttl => config["event_queue_ttl"] || EVENT_QUEUE_DEFAULT_TTL

      Bountybase.logger.info "Connected to stats queue", config
    end
    
    def method_missing(sym, *args) #:nodoc:
      api.event build_event(sym, *args)
    end
    
    private
    
    def build_event(sym, *args) #:nodoc:
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
