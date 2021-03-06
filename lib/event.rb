# Author::    radiospiel  (mailto:eno@radiospiel.org)
# Copyright:: Copyright (c) 2011, 2012 radiospiel
# License::   Distributes under the terms  of the Modified BSD License, see LICENSE.BSD for details.

# The \<b>Event</b> namespace defines a number of functions to log messages from different sources to
# different destinations, depending on matching certain user defined pattern. An event usually
# consists of a severity (error, warn, info), an event message, and additional event options. 
# In addition an event refers its "event source".
#
# Each object may act as an \<b>event source</b>, by using its logger attribute:
#
#    some_object.logger.warn "something" 
#
# create a log event with the message text of "something", a severity of :warn, and its message
# source set to some_object. When generating the text appearing in, say, the console log, the
# message source gets translated using it's `event_source_name` method, which defaults to the object's
# class' name. 
#
# \<b>Multiple event listeners</b> can be set up, like this:
#
#     Event::Listeners.add :console, :severity => (Device.simulator? ? :info : :error)
#     Event::Listeners.add :analytics, FLURRY_KEY
#
# The following event listeners are already implemented here:
#
# - ConsoleListener
# - FlurryAnalyticsListener
# - RemoteSyslogListener
#
# Custom event listeners can be implemented by deriving from Event::Listener
# and reimplementing the Event::Listener#deliver method.
#
# Messages can be \<b>routed</b> to different destinations, depending on some conditions.
# Examples:
# 
#     Event.route :all      => :console         # send all messages to the console
#     Event.route "scheme"  => :analytics       # send events containing "scheme" to :analytics
#     Event.route /http(s):/  => :analytics     # routing works with regexps, too
#
#     # send all events generated from SomeKlass and SomeKlass instances to :analytics
#     Event.route SomeKlass => :analytics 
#
# With routing set up as above these are some event examples (assuming the event message
# severity is set to :info or below.
#
#     Event.info "start"                        # ends up on :console, but not on :analytics. 
#     Event.info "Connect to http://ix.de"      # ends up on :console and on :analytics. 
#     SomeKlass.info "some_object"              # ends up on :console and on :analytics. 
#
class Event

  # Returns the name to use when Event is used as an event source. This
  # method returns nil, which means that <tt>Event.logger</tt> uses no
  # name. See also Object.event_source_name.
  def self.event_source_name
  end

  # Event severities
  module Severity
    # Supported severity values. 
    #
    #     SEVERITIES = {
    #       :error  => 3,
    #       :warn   => 2,
    #       :info   => 1,
    #       :debug  => 0
    #     }
    
    SEVERITIES = {
      :error  => 3,
      :warn   => 2,
      :info   => 1,
      :debug  => 0
    }

    def self.to_number(severity)                              #:nodoc:
      return severity if severity.is_a?(Fixnum)
      SEVERITIES[severity] || raise(ArgumentError, "Invalid severity #{severity.inspect}")
    end

    STRINGS = [ "   *", "  **", " ***", "****" ]              #:nodoc:
    
    def self.to_string(severity)                              #:nodoc:
      STRINGS[to_number(severity)] || severity.to_s
    end

    def severity
      @severity ||= Event::Severity.to_number(:warn)
    end

    def severity=(severity)
      @severity = Event::Severity.to_number(severity)
    end
  end
  
  extend Severity

  # the event severity, usually :error, :warn, :info, :debug
  attr :severity
  
  # the event's source object.
  attr :source

  # event message
  attr :msg
  
  def initialize(severity, source, *values, &block)              #:nodoc:
    @severity = Severity.to_number(severity)
    @source = source
    
    if block_given?
      values.push yield
    end

    if values.empty?
      raise ArgumentError, "Missing arguments"
    end

    @msg = values.shift.to_s

    if values.length > 0
      @msg += " " + values.map { |value| format_value(value) }.join(", ")
    end
  end
  
  # returns a stringified version of this object. Depending on the _mode_ parameter
  # it returns a string including:
  #
  # [+:full+]             a severity marker, source_name, message
  # [everything else]     source_name and message
  #
  def to_s(mode = :short)
    if source && source_name = source.event_source_name
      source_name = "[#{source_name}] "
    end
    
    case mode
    when :full        then "#{Severity.to_string(severity)} #{source_name}#{msg}"
    else                   "#{source_name}#{msg}"
    end
  end

  def inspect #:nodoc:
    "<#{self.class} source: #{source.inspect} #{severity.inspect} #{msg.inspect}>"
  end

  private

  def format_value(value) #:nodoc:
    case value
    when Array      then "[ " + value.map { |v| format_value(v) }.join(", ") + " ]"
    when Hash       then "{ " + format_hash_inner(value) + " }"
    when OpenStruct then format_hash_inner(value.instance_variable_get("@table"))
    else            value.inspect
    end
  end

  def format_hash_inner(hash) #:nodoc:
    hash.map do |k,v| 
      if k.to_s =~ /(secret|password)/ 
        "#{k}: xxxxxxxx" 
      else
        "#{k}: #{v.inspect}" 
      end
    end.sort.join(", ")
  end
  
  public
  
  # The Event::Listeners module organizes all event listeners during an application
  # session.
  module Listeners                                            #:nodoc:
    extend self
    
    @@listeners = {}

    # Add a listenr. 
    def add(listener, *args)
      # expect! listener => Symbol

      return unless klass = listener_klass(listener)
      @@listeners[listener] = klass.new(*args)
    end
    
    def by_symbol(listener)
      @@listeners[listener]
    end

    private
     
    def listener_klass(listener)                              #:nodoc:
      case listener
      when :analytics then FlurryAnalyticsListener
      when :console   then ConsoleListener
      when :syslog    then RemoteSyslogListener
      end
    end
  end
  
  # The base class for Event listeners. To implement a custom Event Listener
  # subclass this class and implement the +deliver+ method.
  class Listener

    # Options for this event listener, as passed into the constructor.
    attr :options
    
    # The minimum severity for this event listener.
    attr :severity

    # Create a new Listener.
    def initialize(options = {})
      expect! options => Hash
      
      @options = options
      @severity = Event::Severity.to_number(options[:severity] || :debug)
    end
    
    # deliver an event to this event listener.
    #
    # Parameter:
    # - +event+: an Event object.
    def deliver_stderr(event)
      raise ArgumentError, "Missing implementation"
    end
  end
  
  # A listener writing to a program's console. ConsoleListeners are 
  # prepared to work both in RubyMotion and in a CRuby environment. 
  class ConsoleListener < Listener
    def deliver_stderr(event) #:nodoc:
      STDERR.puts event.to_s(:full)
    end

    def deliver_ios_device(event) #:nodoc:
      NSLog "%@", event.to_s(:full)
    end

    if defined?(Device) && Device.respond_to?(:simulator?) && !Device.simulator?
      # This is on a iOS device, where stderr does not really work.
      alias :deliver :deliver_ios_device
    else
      alias :deliver :deliver_stderr
    end
  end
  
  # A listener writing to FlurryAnalytics. This works only in RubyMotion, and
  # only with the FlurryAnalytics SDK set up and linked in.
  class FlurryAnalyticsListener < Listener
    def initialize(key, options = {})                         #:nodoc:
      super options
      FlurryAnalytics.startSession key
    end
    
    def deliver(event)                                        #:nodoc:
      FlurryAnalytics.logEvent event.msg
    end
  end
  
  # A listener writing to a remote syslog. Perfect to write to a papertrail.com listener.
  class RemoteSyslogListener < Listener
    # Build a RemoteSyslogListener.
    def initialize(host, port, options = {})
      super options

      begin
        require "remote_syslog_logger"
      rescue LoadError
        STDERR.puts <<-MSG
***
*** Cannot load 'remote_syslog_logger' gem.
*** Make sure to add the gem to the Gemfile, or don't use the :syslog Event listener.
***
MSG
        exit 1
      end
      
      # The :program option is logged, at least in papertrailapp.com, next to the 
      # name of the logging destination, which, according to Bountybase.setup, matches 
      # the environment name. Therefore the :program option will be set to the Bountybase
      # instance (e.g. "mailer", "web1", etc.)
      @logger = RemoteSyslogLogger.new(host, port, :program => Bountybase.instance)
      RemoteSyslogListener.install_at_exit_handler self
    end

    def deliver(event)                                        #:nodoc:
      method = severities_by_number[event.severity] || :info
      @logger.send method, event.to_s
    end

    private
    
    def severities_by_number #:nodoc:
      @severities_by_number ||= [].tap do |ary|
        Event::Severity::SEVERITIES.each { |sym, num| ary[num] = sym }
      end
    end
    
    # This method installs an at_exit handler, which writes a shutdown message
    # to the passed in instance and waits for a small amount of time to get
    # the last log message(s) a chance to be delivered.
    def self.install_at_exit_handler(instance)
      @installed_at_exit_handler ||= begin
        Kernel.at_exit do
          instance.logger.warn "Shutting down RemoteSyslogListener."
          sleep 0.05
        end
        true
      end
    end
  end
end

class Event
  @@routes = {}

  # set up an event route
  def self.route(routes)
    expect! routes => Hash
    
    routes.each do |pattern, target|
      if listener = Listeners.by_symbol(target)
        @@routes.update pattern => listener
      else
        STDERR.puts "No #{target.inspect} listener definition: ignoring route #{pattern.inspect} => #{target.inspect}"
      end
    end
  end
  
  # Does an event match a routing pattern?
  def matches?(pattern)                                       #:nodoc:
    return true if pattern == :all                # match all
    return true if pattern === self.source        # e.g. Classes
    return true if pattern === self.to_s          # e.g. the full string
    false
  end

  # Routes an event: sends the event to all matching event listeners, that accept
  # events of a given severity.
  def deliver                                                 #:nodoc:
    @@routes.each do |pattern, listener|
      next unless listener.severity <= severity
      next unless self.matches?(pattern)
      
      listener.deliver self
    end
  end

  def self.deliver(severity, logger, *values, &block)            #:nodoc:
    return unless Event.severity <= Severity.to_number(severity)
    new(severity, logger.event_source, *values, &block).deliver
  end
end

# -- logging methods

# The Event::Logger class is the logger adapter. Each ruby object will
# return an Event::Logger object from its <tt>:logger</tt> method.
class Event::Logger
  # The +event_source+ for this event. This attribute is used to 
  # determine the event_source name, via its +event_source_name+
  # method.
  attr_reader :event_source
  
  def initialize(event_source) #:nodoc:
    @event_source = event_source
  end
  
  # Generates a log event at *error* severity.
  def error(*args, &block)
    Event.deliver :error, self, *args, &block
  end

  # Generates a log event at *warn* severity.
  def warn(*args, &block)
    Event.deliver :warn, self, *args, &block
  end

  # Generates a log event at *info* severity.
  def info(*args, &block)
    Event.deliver :info, self, *args, &block
  end

  # Generates a log event at *debug* severity.
  def debug(*args, &block)
    Event.deliver :debug, self, *args, &block
  end

  # The Benchmarker object can be used to adjust a benchmark's
  # message after the fact:
  #
  #   benchmark do |bm|
  #     doc = HTTP.get "http://google.com"
  #     bm.message = "Received #{doc.bytesize} byte"
  #     doc
  #   end
  class Benchmarker
    
    # The benchmark message
    attr :message, true
    
    def initialize(message) #:nodoc:
      @message = message
    end
  end
  
  #
  # Runs a benchmark and logs it using. 
  # 
  #   benchmark "This is a benchmark" do
  #     # do something which takes some time.
  #   end
  #
  # The default severity is :info, but can be adjusted:
  #
  #   benchmark :warn, "This benchmark will be logged at :warn severity" do
  #     # do something which takes some time.
  #   end
  #
  # This method yields a Benchmarker object, which can be used to
  # modify the benchmark message "after the fact."
  #
  #   benchmark do |bm|
  #     doc = HTTP.get "http://google.com"
  #     bm.message = "Received #{doc.bytesize} byte"
  #     doc
  #   end
  #
  def benchmark(*args, &block)
    severity = args.shift if Event::Severity::SEVERITIES.key?(args.first)
    severity ||= :info
    
    min_runtime = args.pop[:min] if args.last.is_a?(Hash) && args.last.keys == [:min]
    min_runtime ||= 50

    msg = args.shift || "benchmark"
    msg += " #{args.map(&:inspect).join(", ")}" if args.length > 0

    benchmarker = Benchmarker.new(msg)
    lambda = Proc.new

    start = Time.now
    
    r = if lambda.arity == 0 
      yield
    else
      yield benchmarker
    end

    runtime = ((Time.now - start) * 1000).to_i
    Event.deliver severity, self, "#{benchmarker.message}: #{runtime} msecs." if runtime >= min_runtime
  
    r
  rescue
    runtime = ((Time.now - start) * 1000).to_i
    Event.deliver severity, self, "#{benchmarker.message}: failed after #{runtime} msecs." if runtime >= min_runtime
    raise
  end
end

class Object
  # Returns the logger object for this object.
  def logger
    @logger ||= Event::Logger.new(self.class)
  end

  # Runs a benchmark on the logger.
  def benchmark(*args, &block)
    logger.benchmark(*args, &block)
  end

  # Returns the name to use when this object is used as an event source
  def event_source_name
    name
  end
end

module Bountybase
  # Bountybase event_source_name returns nil. Bountybase.warn etc. do not 
  # include an event_source_name.
  def self.event_source_name
    nil
  end
end
  
class Module
  # The logger for a modules and classes uses the module/class itself 
  # as event source, and *not* its class (which would be Class, btw.)
  #
  # This lets you use, e.g.
  # 
  #   Net::HTTP.warn "Test"
  #
  # which logs a message with event_source_name "Net::HTTP".  
  def logger
    @logger ||= Event::Logger.new(self)
  end
end
