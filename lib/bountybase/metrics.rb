Dir.glob( __FILE__.gsub(/\.rb$/, "/*_adapter.rb" )).each do |file|
  load file
end

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
    @metrics ||= begin
      adapter = if config = Bountybase.config.stathat
        Metrics::StatHatAdapter.new(config)
      elsif false && (config = Bountybase.config.rulesio) && !config["disabled"]
        Metrics::RulesIOAdapter.new(config)
      elsif (config = Bountybase.config.fnordmetric) && !config["disabled"]
        Metrics::FnordMetricAdapter.new(config) 
      end
      
      Bountybase.logger.info "Connected to metrics adapter", adapter.class
      Metrics.new adapter
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
    # A dummy adapter, just eats all events doing nothing. Used when there
    # is no configuration.
    module DummyService #:nodoc:
      def self.event(data); end
    end

    class BackgroundService #:nodoc:
      def initialize(service)
        require "girl_friday"
        
        @queue = GirlFriday::WorkQueue.new(:metrics, :size => 1) do |type, name, value, payload|
          service.event type, name, value, payload
        end
      end
      
      def event(*args)
        @queue << args
      end
    end
    
    # Creates a new Metrics instance. 
    def initialize(service) #:nodoc:
      @service = service || DummyService

      if @service.respond_to?(:background?) && @service.background?
        @service = BackgroundService.new(@service)
      end
    end
    
    def count(name, value=1, payload={})
      @service.event :count, name, value, payload
    end
    
    def value(name, value, payload={})
      @service.event :value, name, value, payload
    end
    
    private
    
    # method_missing builds an event from the name and the passed in parameters.
    def method_missing(name, *args) #:nodoc:
      if args.last.is_a?(Hash) 
        payload = args.pop
      end

      case args.length
      when 0 then value = 1
      when 1 then value = args.first
      else        raise ArgumentError, "Invalid number of arguments"
      end

      if name.to_s =~ /^(.*)!$/
        type = :count
        name = $1.to_sym
      else
        type = :value
      end

      @service.event type, name, value, payload
    end
  end
end
