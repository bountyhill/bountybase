require "girl_friday"

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
        StatHatAdapter.new(config)
      elsif false && (config = Bountybase.config.rulesio) && !config["disabled"]
        RulesIOAdapter.new(config)
      elsif (config = Bountybase.config.fnordmetric) && !config["disabled"]
        FnordMetricAdapter.new(config) 
      else
        DummyAdapter.new
      end
      
      Bountybase.logger.info "Connected to metrics adapter", adapter.class
      Metrics.new adapter
    end
  end

  # A dummy adapter, just eats all events doing nothing. Used when there
  # is no configuration.
  class DummyAdapter
    def event(data); end
  end

  class FnordMetricAdapter
    # Default event_queue_ttl setting.
    EVENT_QUEUE_DEFAULT_TTL = 20

    extend Forwardable
    delegate :event => :"@api"
    
    def initialize(config)
      require "fnordmetric"
      require "fnordmetric/api"
      
      @api = FnordMetric::API.new :redis_url   => config["redis_url"], 
                              :redis_prefix    => config["redis_prefix"],  
                              :event_queue_ttl => config["event_queue_ttl"] ||    EVENT_QUEUE_DEFAULT_TTL
    end
    
    def event(type, name, value, payload)
      payload ||= {}
      
      payload[:_name] = payload.delete(:_type).to_s
      payload[:_timestamp] = Time.now.to_f
      payload[:_actor] ||= Bountybase.instance
      payload[:_domain] ||= "bountybase"

      @api.event payload
    end
  end

  class StatHatAdapter
    attr :queue
    
    def initialize(account)
      require "stathat"
      @account = account
    end

    def event(type, name, value, payload)
      expect! type => [ :count, :value ]

      case type
      when :count then StatHat::API.ez_post_count(name, @account, value || 1)
      when :value then StatHat::API.ez_post_value(name, @account, value)
      end
    end
  end
  
  class RulesIOAdapter
    def event(type, name, value, payload)
      payload ||= {}
      
      payload[:_name] = payload.delete(:_type).to_s
      payload[:_timestamp] = Time.now.to_f
      payload[:_actor] ||= Bountybase.instance
      payload[:_domain] ||= "bountybase"

      RulesIO.send_event(payload)
      RulesIO.flush
    end
    
    def initialize(options)
      require "rulesio"
      
      expect! "Working" => false # Dont use me, I need some work!
      
      expect! options => { "token" => String }

      defaults = {
        "webhook_url"   => 'https://www.rules.io/events/',
        "queue"         => RulesIO::GirlFridayQueue,
        "queue_options" => {}
      }
      
      options = defaults.update(options)
      
      RulesIO.logger = RulesIO
      RulesIO.webhook_url = options["webhook_url"]
      RulesIO.buffer = []
      RulesIO.filter_parameters = []
      RulesIO.token = options["token"]
      RulesIO.queue = options["queue"]
      RulesIO.queue_options = options["queue_options"]
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

    # Creates a new Metrics instance. 
    def initialize(service) #:nodoc:
      @service = service

      run_in_background!
    end

    private
    
    def run_in_background!
      require "girl_friday"
      
      service = @service
      
      @service = GirlFriday::WorkQueue.new(:metrics, :size => 1) do |type, name, value, payload|
        service.event type, name, value, payload
      end

      def @service.event(*args); self << args; end
    end

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
