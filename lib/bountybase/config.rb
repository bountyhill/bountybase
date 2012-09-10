require "ostruct"
require "yaml"

module Bountybase
  # returns the global Bountybase::Config object, which contains configuration
  # settings from the <b>config.yml</b> configuration file. 
  #
  #     Bountybase.config.neo4j     # => nil
  #     Bountybase.config.neo4j!    # => raises exception.
  # 
  def config
    @config ||= Config.new Config.read
  end
  
  # A Bountybase configuration returns runtime configuration settings.
  # To access a configuration setting you use the global Bountybase 
  # configuration object as returned by <tt>Bountybase.config</tt>; 
  # e.g.
  #
  #    Bountybase.config.neo4j
  #
  # Configuration settings for all environment values are stored in
  # the <b>config.yml</b> file. This file is part of the bountybase
  # repository; this makes sure that all instances of a multi-instance
  # application share the same settings. This is an example excerpt
  # of a <b>config.yml</b> file, which defines the
  # <tt>Bountybase.config.syslog</tt> setting.
  #
  #   syslog:
  #     default:    logs.papertrailapp.com:1234
  #     deployment: logs.papertrailapp.com:61566
  #     production: logs.papertrailapp.com:11905
  #     staging:    logs.papertrailapp.com:22076
  #
  # This sets <tt>Bountybase.config.syslog</tt> to <em>"logs.papertrailapp.com:11905"</em> 
  # in the production environment, and to <em>"logs.papertrailapp.com:1234"</em>
  # in the development (or any other unspecified) environment setting.
  #
  # If a configuration value is the same for all environments you 
  # need to specify this value only once, e.g.
  #
  #   syslog: logs.papertrailapp.com:1234
  #
  # The configuration object supports a special bang! syntax, which raises
  # a Config::Missing exception if a configuration setting is missing:
  #
  #     # assuming there is no neo4j configuration setting
  #     Bountybase.config.neo4j     # => nil
  #     Bountybase.config.neo4j!    # => raises exception.
  #
  class Config < OpenStruct

    # RuntimeError to raise on missing settings.
    class Missing < RuntimeError; end

    # Fetches the configuration setting for the _sym_ value. 
    # Raises a Missing exception if there is no setting and sym
    # ends in a +"!"+ character.  
    def method_missing(sym, *args, &block)
      return super unless args.empty? && !block_given?
      
      if sym.to_s =~ /^(.*)!$/
        super($1.to_sym) || raise(Missing, "Missing attribute #{sym}")
      else
        super
      end
    end

    # returns a redis url for a specific redis based component. These URLs
    # are built from a base redis configuration, under the \a "redis" key,
    # and a second configuration value under the passed in \a component.
    def redis_for(component)
      redis_url = Bountybase.config.redis.gsub(/\/*$/, "")
      expect! redis_url => /^redis:/

      url_part = if component == :bountybase
        # default namespace for global redis connection.
        "bountybase"
      else
        Bountybase.config.send(component) || raise("Missing #{component} redis configuration")
      end

      case url_part
      when "none"   then nil
      when /:/      then url_part
      when /^\d+$/  then "#{redis_url}:#{url_part}"
      else               "#{redis_url}/#{url_part}"
      end
    end

    # returns the configuration hash including settings for *all* environments 
    def self.read #:nodoc:
      config_file = File.join File.dirname(__FILE__), "..", "..", "config.yml"
      yaml = File.read(config_file)

      config = {}
      YAML.load(yaml).each do |key, value|
        next unless value = resolve_by_environment(value)
        config[key] = value
      end
      config
    end

    # return the value for the current environment from the passed in
    # setting. If the setting from the 
    def self.resolve_by_environment(setting) #:nodoc:
      return setting unless setting.is_a?(Hash)

      if setting.key?(Bountybase.environment)
        setting[Bountybase.environment]
      elsif setting.key?("default")
        setting["default"]
      end
    end
  end
end
