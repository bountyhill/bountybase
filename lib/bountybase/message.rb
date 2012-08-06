class Bountybase::Message
end

require_relative "message/heartbeat"

# A Bountybase message is an object which gets send to the resque server and can be
# performed by it. 
class Bountybase::Message
  class UnknownName < ArgumentError; end
  class UnsupportedParameters < ArgumentError; end
  
  def perform
    raise "Missing implementation for #{self.class.name}#perform"
  end

  module Performer
    extend self
    
    def perform(klassname, *args)
      klass = message_klasses[klassname]

      instance = begin
        klass.new(*args)
      rescue ArgumentError
        raise UnsupportedParameters, $!
      end

      instance.perform
    end

    private
    
    def message_klasses
      @message_klasses ||= Hash.new do |hash, k| 
        hash[k] = resolve_message_name(k) 
      end
    end

    def resolve_message_name(name)
      raise UnknownName, name unless name =~ /^[A-Z][A-Za-z0-9_]*$/

      Bountybase::Message.const_get(name).tap do |klass|
        next if klass.instance_methods.include? :perform
        raise UnknownName, name
      end
    rescue NameError, TypeError
      Bountybase.logger.error "Invalid Bountybase message name", name
      raise UnknownName, $!
    end
  end

  extend Performer
end
