require "resque"

# The Bountybase::Message class and namespace implements message passing between 
# different bountybase components. We use "resque" for passing messages and running
# jobs; however, we do not use the "resque" protocol, because we want to pass
# in more information into our jobs than what resque provides by default.
#
# In addition to a messages payload we pass in Bountybase::Message::Origin
# information.
class Bountybase::Message
  attr :origin, true
  
  def initialize(options = {})
    @options = options
  end
  
  # perform the message. This method is typically run from a bountyclerk instance.
  def perform
    raise "Missing implementation for #{self.class.name}#perform"
  end
end

require_relative "message/heartbeat"

class Bountybase::Message
  class UnknownName < ArgumentError; end
  class UnsupportedParameters < ArgumentError; end

  # Information from the message's origin.
  class Origin
    attr :instance      # the name of the origin instance.
    attr :environment   # the name of the origin environment. This should match 
                        # the receiver's environment.
    attr :timestamp     # the UTC timestamp of the origin (in seconds.) 

    def initialize(options)
      @instance, @environment, @timestamp = options.values_at :instance, :environment, :timestamp
    end
    
    def self.create_hash
      {
        :instance     => Bountybase.instance,
        :environment  => Bountybase.environment,
        :timestamp    => Time.now.to_i
      }
    end
  end
  
  # Code responsible for queuing a message. Messages are queued by calling #enqeue
  # on the message's class with a hash parameter set, for example:
  #
  #     Bountybase::Message::Heartbeat.enqeue(:environment => "environment", :instance => "instance")
  module Queueing
    # Enqueues a message of this class into the resque queue.
    #
    # If no queue name is passed in, we use the default queue for messages
    # of the that type, which is returned by the self.queue method
    # for this class (and which defaults to the class' downcased name)
    def enqueue(options = {}, queue = nil)
      # Note: the Resque default implementation derives the queue name from the class.
      # As we are using the same class (Message) we don't want that here; instead
      # we use the somewhat longer job creation code here.
      Resque::Job.create(queue || self.queue, Bountybase::Message, name, options, Origin.create_hash)
    end

    # returns the default queue for messages of this class. The default 
    # implementation returns the downcased name of the class, e.g. "heartbeat" 
    # for Bountybase::Message::Heartbeat messages.
    def queue
      name.sub("Bountybase::Message::", "").downcase 
    end
  end
  
  extend Queueing

  # Code responsible for performing messages. 
  module Performing

    # Implements the interface as expected from resque. This method builds a message
    # object - as specified by klassname, passes in the options hash, and calls 
    # perform on that object.
    def perform(klassname, options, origin)
      raise UnsupportedParameters unless options.is_a?(Hash)

      klass = message_klasses[klassname]
      instance = begin
        klass.new(options)
      rescue ArgumentError
        raise UnsupportedParameters, $!
      end

      instance.origin = Origin.new(origin)
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

  extend Performing
end
