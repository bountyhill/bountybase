class Bountybase::Metrics; end

__END__

class Bountybase::Metrics::RulesIOAdapter
  def background?
    false
  end
  
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
