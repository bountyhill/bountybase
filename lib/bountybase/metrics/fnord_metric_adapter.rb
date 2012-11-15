class Bountybase::Metrics; end

__END__

class Bountybase::Metrics::FnordMetricAdapter
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
