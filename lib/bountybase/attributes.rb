# The Bountybase::Attributes module defines a number of attributes that
# influence the behaviour of a running applications within a multi-process 
# application. These attributes include
#
# - environment: e.g. "development", "staging" etc.
# - role: e.g. "mailer", "web", "twirl" etc.
# - instance: e.g. "mailer1"
# - root: the root dir.
#
# Note that multiple processes might share the same role attribute but
# should have a different instance attribute.
#
# The configuration is read at runtime from these environment variables:
#
# - INSTANCE: is able to set environment, role, *and* instance settings 
#   in one go. Should be set to "<environment>-<role><instance>", where
#   both "environment" and "role" consists of letters only and the 
#   "instance" part consists of digits only.
# - RACK_ENV, RAILS_ENV: the environment setting
# - RACK_ROOT, RAILS_ROOT: the application's root directory.
#
# The Bountybase::Attributes module is extended into the Bountybase module: 
# the root, environment, role, and instance settings can be accessed as 
# Bountybase.root, Bountybase.environment, etc.
#
module Bountybase::Attributes
  
  Attributes = ::Bountybase::Attributes
  
  # Exception to raise on missing settings.
  class Missing < RuntimeError; end

  # Return the application's root directory, as read from RAILS_ROOT or RACK_ROOT.
  def root
    @root ||= I.from_environment! "RAILS_ROOT", "RACK_ROOT"
  end

  # Return the name of the current environment. Typical return values include
  # "development", "staging", etc. This setting is read from the RAILS_ENV, 
  # RACK_ENV, or INSTANCE environment variable, and defaults to "development".
  def environment
    @environment ||= I.from_environment("RAILS_ENV", "RACK_ENV") ||
      I.parse_instance.first ||
      "development"
  end

  # Returns the process' role within a multiprocess application. The role 
  # describes the workload an application instance will process; for example, 
  # "web" or "mailer". 
  def role
    @role ||= begin
      _, role, _ = *I.parse_instance
      role || raise(Missing, "Cannot determine role.")
    end
  end

  # returns the instance name of the running instance. This name usually 
  # contains both the role to desccribe the type of instance, and a number
  # to discriminate amongst components running the same role.
  #
  # The instance defaults to "test" in the test environment, as there is 
  # usually no instance setting.
  def instance
    @instance ||= begin
      _, _, instance = *I.parse_instance
      instance || if environment == "test"
        "test"
      else
        raise(Missing, "Cannot determine instance setting.")
      end
    end
  end

  # -- modify settings ---------------------------------------------------------------
  
  # Modify RACK_ENV and RAILS_ENV setting for the duration of a block; 
  # this is needed to test this module.
  def with_environment(environment, &block) # :nodoc:
    with_settings "RACK_ENV" => environment, "RAILS_ENV" => environment, &block
  end

  # Modify environment variables for the duration of a block; 
  # this is needed to test this module.
  def with_settings(settings, &block) #:nodoc:
    @root = @environment = @role = @instance = nil

    old_env = {}
    settings.each { |key, value| 
      old_env[key] = ENV[key]
      ENV[key] = value.is_a?(Symbol) ? value.to_s : value
    }

    yield
  ensure
    ENV.update old_env
    @root = @environment = @role = @instance = nil
  end

  # Private methods used by Bountybase::Attributes
  module I #:nodoc:all
    def self.from_environment(*environment_variables)
      ENV.values_at(*environment_variables).compact.first
    end

    def self.from_environment!(*environment_variables)
      from_environment(*environment_variables) || 
        raise(Bountybase::Attributes::Missing, "Missing #{environment_variables.join(", or ")} environment variable.")
    end

    # parses the INSTANCE environment variable. 
    def self.parse_instance
      return [] unless instance = from_environment("INSTANCE")

      unless instance.to_s =~ /^([a-zA-Z]+)-([a-zA-Z]+)(\d*)$/
        raise ArgumentError, "Invalid INSTANCE environment setting: #{instance.inspect} "
      end

      [ $1, $2, "#{$2}#{$3}" ]
    rescue Bountybase::Attributes::Missing
    end
  end
  
end

Bountybase.extend Bountybase::Attributes
