require "resque"

# The Bountybase::Message class and namespace implements message passing between 
# different bountybase components. We use +resque+ for passing messages between 
# instances. Bountybase::Message however adds a small layer of infrastructure to 
# resque, because we want to pass along a bit more information than what
# resque provides by default, and we don't want to use any not documented
# resque interfaces.
#
# == Enqueueing a message
#
# To create and enqueue a message into the message queue use the Message.enqueue
# method of the specific message class.
#
#   # enqueue a Heartbeat message. Heartbeat messages don't support 
#   # additional parameters.
#   Bountybase::Message::Heartbeat.enqueue({})
#
#   # enqueue a Tweet message. Tweet messages require some additional
#   # parameters.
#   Bountybase::Message::Tweet.enqueue :tweet_id => 123,
#     :sender_id => 456,
#     :sender_name => "name",
#     :quest_id => 23,
#     :receiver_ids => [ 1, 2, 3],
#     :receiver_names => [ "receiver1", "receiver2", "receiver3"],
#     :text => "Look what I have seen @receiver1 @receiver2 http://bountybase.local/quest/23",
#     :lang => "en"
#
# == Performing a message
#
# The message will be performed by the bountyclerk runner, which is 
# based upon Resque::Server. Source and installation instructions 
# for bountyclerk are here: https://github.com/bountyhill/bountyclerk.
#
# In short, the message will be enqueued into resque. Assuming it being
# configured correctly Resque will then run Message.perform with message
# name, parameters, and some attributes describing the message origin. 
# This will construct a <tt>Bountybase::Message::<MessageName></tt> 
# object and send the <tt>:perform</tt> message to it. 
#
# == Implementing custom messages
#
# - Derive from Bountybase::Message
# - implement the Bountybase::Message#perform method
# - potentially also implement the Bountybase::Message#valid? method
#
class Bountybase::Message
  # Error to raise when trying to perform a unknown message.
  class UnknownName < ArgumentError; end

  # the originating Bountybase.instance name
  attr_reader :instance      

  # The name of the originating environment. This should match the receiver's 
  # environment. If it doesn't, the sender is probably wired incorrectly 
  # to the receiver: they should not use the same redis instance in that 
  # case. 
  attr_reader :environment

  # the UTC timestamp of the origin (in seconds.) Note that timestamps can
  # and probably will skew for a few seconds on different machines. 
  attr_reader :timestamp

  # the payload as passed into the constructor.
  attr_reader :payload

  # Perform the message. This method is typically run from a
  # bountyclerk instance.
  #
  # Implement this method to have bountyclerk do something useful.
  def perform
    raise "Missing implementation for #{self.class.name}#perform"
  end

  private
  
  # Build the Message object. The default implementation just saves the 
  # passed in attributes. You rarely have to override this method.
  def initialize(payload, origin) #:nodoc:
    expect! payload => Hash, origin => Hash
    @payload = payload
    @instance, @environment, @timestamp = origin.values_at :instance, :environment, :timestamp
  end
  
  # return a hash holding all information to later being passed into the 
  # perform_with_origin method.
  def self.origin_hash #:nodoc:
    {
      :instance     => Bountybase.instance,
      :environment  => Bountybase.environment,
      :timestamp    => Time.now.to_i
    }
  end

  #
  # Validate the payload. If the payload is invalid this method raises
  # an +ArgumentError+ exception. 
  #
  # Reimplement validate! in subclasses for custom payload validation.
  # Note that one can use the expect! method to verify the message object.
  def self.validate!(payload)
  end

  public

  # -- enqueuing a message. 

  # Enqueues a message of this class into the resque queue.
  #
  # call-seq:
  #   Klass.enqueue
  #   Klass.enqueue(queue_name)
  #   Klass.enqueue(payload)
  #   Klass.enqueue(queue_name, payload)
  #
  #
  # If no queue name is passed in, we use the default queue for messages
  # of the that type, which is returned by the Message.queue method
  # for this class (and which defaults to the class' downcased name)
  #
  # Parameters:
  #
  # - +queue_name+: the name of the queue, defaults to default_queue.
  # - +payload+: the payload hash, defaults to {}
  #
  # Examples:
  #
  #   Message::Heartbeat.enqueue
  #   Message::Heartbeat.enqueue "heartbeat"
  #   Message::Tweet.enqueue :tweet_id => 123
  #   Message::Tweet.enqueue "tweet_queue", :tweet_id => 123
  def self.enqueue(*args)
    payload = args.last.is_a?(Hash) ? args.pop : {}
    queue, dummy = *args
    expect! dummy => nil, queue => [ String, nil ]
    validate! payload
    
    # While the Resque default implementation derives the queue name from 
    # the class. We, however, are using the same class (Bountybase::Message)
    # for all messages and therefore don't want that behaviour; instead
    # we use the somewhat longer job creation code here.
    Resque::Job.create(queue || self.default_queue, 
      Bountybase::Message, 
      self.name, 
      payload, 
      origin_hash)
  end

  # returns the default queue for messages of this class. The default 
  # implementation returns the downcased name of the class, 
  # e.g. "heartbeat" for Bountybase::Message::Heartbeat messages.
  #
  # Override this method to use a different queue name for messages
  # of a specific class.
  def self.default_queue
    name.sub("Bountybase::Message::", "").downcase 
  end

  # -- performing messages --------------------------------------------

  @@message_klasses ||= Hash.new do |hash, k| 
    hash[k] = resolve_message_name(k) || raise(UnknownName, k.inspect) 
  end

  # Implements the interface as expected from resque. This method builds 
  # a message object - as specified by klassname, passes in the options
  # hash, and calls <tt>:perform</tt> on that object.
  #
  # The order of its arguments reflects the order used by
  # <tt>Resque::Job.create</tt> in the <tt>Message.enqueue</tt>
  def self.perform(klassname, payload, origin)
    expect! payload => Hash, origin => Hash

    
    klass = @@message_klasses[klassname]

    W klass.name, payload
    I "from", origin

    payload = payload.with_symbolized_keys
    origin = origin.with_symbolized_keys

    klass.validate! payload
    klass.new(payload, origin).perform
  rescue StandardError
    $!.log "Cannot perform"
    raise
  end
  
  private

  def self.resolve_message_name(name) #:nodoc:
    return unless name =~ /^[A-Z][:A-Za-z0-9_]*$/

    name = name.split("::").last
    klass = Bountybase::Message.const_get(name)
    return klass if klass.instance_methods.include? :perform
  rescue NameError, TypeError
    nil
  end
end

require_relative "message/heartbeat"
require_relative "message/tweet"
