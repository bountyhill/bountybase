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
# Messages can be \<b>routed</b> to different destinations, depending on some conditions, 
# like this: 
# 
#     # route all messages to the console
#     Event.route :all      => :console
#
#     # send all events containing "scheme" to :analytics
#     Event.route "scheme"  => :analytics
#
#     # this works also with regexps
#     Event.route /http(s):/  => :analytics
#
#     # send all events generated from SomeKlass and SomeKlass instances to :analytics
#     Event.route SomeKlass => :analytics 
# 
#     Event.info "start"         # ends up on console, but not on :analytics. 
#
class Event

  # Event severities
  module Severity
    # Supported severity values. 
    #
    #     SEVERITIES = {
    #       :error => 2,
    #       :warn =>  1,
    #       :info =>  0
    #     }
    
    SEVERITIES = {
      :error => 2,
      :warn =>  1,
      :info =>  0
    }

    def self.to_number(severity)                              #:nodoc:
      return severity if severity.is_a?(Fixnum)
      SEVERITIES[severity] || raise(ArgumentError, "Invalid severity #{severity.inspect}")
    end

    STRINGS = [ "*  ", "** ", "***" ]                         #:nodoc:
    
    def self.to_string(severity)                              #:nodoc:
      STRINGS[to_number(severity)] || severity.to_s
    end
  end

  # the event severity, usually :error, :warn, or :info
  attr :severity
  
  # the event's source object.
  attr :source

  # event message
  attr :msg
  
  # event options
  attr :options
  
  def initialize(severity, source, msg, *values)              #:nodoc:
    @severity = Severity.to_number(severity)
    @source = source
    
    # turn msg, values into @msg and @options
    @options = values.pop if values.last.is_a?(Hash)
    msg += " #{values.map(&:inspect).join(", ")}" if values.length > 0
    @msg = msg
  end
  
  # returns a stringified version of this object. Depending on the _mode_ parameter
  # it returns a string including:
  #
  # [+:full+]             a severity marker, source_name, message, options
  # [+:wo_severity+]      source_name, message, options 
  # [everything else]     source_name and message
  #
  def to_s(mode = :short)
    if source_name = source.event_source_name
      source_name = "[#{source_name}] "
    end
    
    case mode
    when :full        then "#{Severity.to_string(severity)} #{source_name}#{msg}#{formatted_options}"
    when :wo_severity then "#{source_name}#{msg}#{formatted_options}"
    else                   "#{source_name}#{msg}"
    end
  end

  def inspect
    "<#{self.class} source: #{source.inspect} #{severity.inspect} #{msg.inspect}>"
  end

  private

  # returns a string of formatted options (or nil)
  def formatted_options                                       #:nodoc:
    case options && options.length
    when nil, 0 then nil
    when 1      then ": " + options.values.first.inspect
    else             options.map { |k,v| "#{k}: #{v.inspect}" }.sort.join(", ")
    end
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
  
  # The base class for Event listeners.
  class Listener
    attr :options, :severity

    def initialize(options = {})
      @options = options
      @severity = Event::Severity.to_number(options[:severity] || :warn)
    end
  end
  
  # A listener writing to a program's console.
  class ConsoleListener < Listener
    def deliver_stderr(event)
      STDERR.puts event.to_s(:full)
    end

    # delivery on the device
    def deliver_ios_device(event)
      NSLog "%@", event.to_s(:full)
    end

    if defined?(Device) && Device.respond_to?(:simulator?) && !Device.simulator?
      # This is on a iOS device, where stderr does not really work.
      alias :deliver :deliver_ios_device
    else
      alias :deliver :deliver_stderr
    end
  end
  
  # A listener writing to FlurryAnalytics. This works only in iOS, and only with
  # the FlurryAnalytics SDK set up and linked in.
  class FlurryAnalyticsListener < Listener
    def initialize(key, options = {})
      super options
      FlurryAnalytics.startSession key
    end
    
    def deliver(event)                                        #:nodoc:
      if event.options.nil?
        FlurryAnalytics.logEvent event.msg
      else
        FlurryAnalytics.logEvent event.msg, withParameters: event.options
      end
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
      msg = event.to_s(:wo_severity)

      method = severities_by_number[event.severity] || :info
      @logger.send method, msg
    end

    private
    
    def severities_by_number
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
    # expect! routes => Hash
    
    routes.each do |pattern, target|
      if listener = Listeners.by_symbol(target)
        @@routes.update pattern => listener
      else
        logger.info "No #{target.inspect} listener definition: ignoring route #{pattern.inspect} => #{target.inspect}"
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

  def self.deliver(severity, logger, msg, *values)            #:nodoc:
    new(severity, logger.event_source, msg, *values).deliver
  end
end

# -- logging methods

class Event::Logger
  attr :event_source
  
  def initialize(event_source)
    @event_source = event_source
  end
  
  module LoggerMethods
    def error(msg, *args)
      Event.deliver :error, self, msg, *args
    end

    def warn(msg, *args)
      Event.deliver :warn, self, msg, *args
    end

    def info(msg, *args)
      Event.deliver :warn, self, msg, *args
    end

    def benchmark(msg = "benchmark", min_runtime = 50, &block)
      start = Time.now
      yield 
    ensure
      runtime = ((Time.now - start) * 1000).to_i
      Event.logger.info "#{msg}: #{runtime} msecs." if runtime >= min_runtime
    end
  end

  include LoggerMethods
end

class Object
  def logger
    @logger ||= Event::Logger.new(self.class)
  end

  def benchmark(msg = "benchmark", &block)
    logger.benchmark(msg, &block)
  end

  def event_source_name
    name
  end
end

class Event
  def self.event_source_name
    nil
  end
end

class Module
  def logger
    @logger ||= Event::Logger.new(self)
  end
end
