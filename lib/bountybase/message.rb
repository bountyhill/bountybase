class Bountybase::Message
end

require_relative "message/heartbeat"

# A Bountybase message is an object which gets send to the resque server and can be
# performed by it. 
class Bountybase::Message
  class UnknownName < ArgumentError; end
  class UnsupportedParameters < ArgumentError; end
  
  def perform
    logger.warn "Missing implementation for #{self.class}##{perform}"
  end

  def self.perform(klassname, *args)
    klass = message_klasses[klassname]
    
    instance = begin
      klass.new(*args)
    rescue ArgumentError
      raise UnsupportedParameters, $!
    end
    
    instance.perform
  end

  def self.message_klasses
    @message_klasses ||= Hash.new do |hash, k| 
      hash[k] = resolve_message_name(k) 
    end
  end

  def self.resolve_message_name(name)
    raise UnknownName, name unless name =~ /^[A-Z][A-Za-z0-9_]*$/

    Bountybase::Message.const_get(name)
  rescue NameError, TypeError
    Bountybase.logger.error "Invalid Bountybase message name", name
    raise UnknownName, $!
  end
end
