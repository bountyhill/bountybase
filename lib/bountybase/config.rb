require "ostruct"

module Bountybase
  # returns the configuration object. This object is an OpenStruct object (i.e. you
  # read it via, e.g. `Bountybase.config.resque`)
  def config
    @config ||= Config.new Config.read
  end
  
  class Config < OpenStruct
    class Missing < RuntimeError; end

    def method_missing(sym, *args, &block)
      return super unless args.empty? && !block_given?
      
      if sym.to_s =~ /^(.*)!$/
        super($1.to_sym) || raise(Missing, "Missing attribute #{sym}")
      else
        super
      end
    end

    # read the yaml configuration
    def self.yaml
      # Or read from *this* file. 
      # File.read(__FILE__).split(/__END__\s*/).last

      config_file = File.join File.dirname(__FILE__), "..", "..", "config.yml"
      File.read(config_file)
    end

    # returns the configuration hash including settings for *all* environments 
    def self.read
      config = {}

      YAML.load(yaml).each do |key, value|
        next unless value = resolve_by_environment(value)
        config[key] = value
      end
      config
    end

    def self.resolve_by_environment(setting)
      return setting unless setting.is_a?(Hash)

      if setting.key?(Bountybase.environment)
        setting[Bountybase.environment]
      elsif setting.key?("default")
        setting["default"]
      end
    end
  end
end
