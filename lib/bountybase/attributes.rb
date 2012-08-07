module Bountybase::Attributes
  
  Attributes = ::Bountybase::Attributes
  
  # The Bountybase::Attributes module defines a number of attributes that shape the behaviour
  # of a running bountybase instance. These include:
  # - root: the application's root directory, as read from RAILS_ROOT or RACK_ROOT.
  # - environment: the application's environment settings; e.g. "development", "staging", etc.
  #   This is read from the RAILS_ENV, RACK_ENV, or INSTANCE environment settings.
  # - role: the process' role (within a multiprocess application.) This could be, for example,
  #   "web" or "mailer". It is read from the INSTANCE environment settings.  
  # - instance: the process instance within a multiprocess application. This usually consists
  #   of both role and number, e.g. "web1" or "mailer1".
  #
  # To define the different settings one sets the INSTANCE environment variable, in the form of
  # "<environment>-<role><instance>", where both "environment" and "role" consists only of letters
  # and the optional "instance" part consists of digits only.
  #
  # The Bountybase::Attributes module is extended into the Bountybase module: the root, environment, 
  # role, and instance settings can therefore be accessed via Bountybase.root etc.
  #

  class Missing < RuntimeError; end

  def self.read(*environment_variables)
    ENV.values_at(*environment_variables).compact.first
  end

  
  def self.read!(*environment_variables)
    read(*environment_variables) || 
      raise(Missing, "Missing #{environment_variables.join(", or ")} environment variable.")
  end
  
  # find application root.
  def root
    @root ||= Attributes.read! "RAILS_ROOT", "RACK_ROOT"
  end

  # returns the name of the current environment. 
  def environment
    @environment ||= Attributes.read("RAILS_ENV", "RACK_ENV") ||    # try to read from process environment
      Attributes.parse_instance.first ||                            # try to read from instance setting
      "development"                                           # default to development
  end

  # adjusts the name of the environment setting for the duration of a block. 
  # This method should not be used outside of tests.
  def in_environment(environment, &block) # :nodoc:
    old = @environment
    @environment = environment
    yield
  ensure
    @environment = old
  end

  # returns the role of the running instance. The role describes the general workload
  # of the current process. There can be multiple processes with the same role:
  #
  # If there are two running twirl instances, they would both share the "twirl" role.
  # They would not share the instance, which would probably be "twirl1" or  "twirl2".
  def role
    @role ||= begin
      _, role, _ = *parse_instance
      role || raise(Missing, "Cannot determine role.")
    end
  end

  # returns the instance name of the running instance. This name usually contains 
  # both the role to desccribe the type of instance, and a number to discriminate
  # amongst components running the same role.
  def instance
    _, _, instance = *parse_instance
    instance || raise(Missing, "Cannot determine instance.")
  end

  # parses the name of the INSTANCE environment variable. 
  def self.parse_instance
    instance = Attributes.read("INSTANCE")
    unless instance.to_s =~ /^([a-zA-Z]+)-([a-zA-Z]+)(\d*)$/
      raise ArgumentError, "Invalid INSTANCE environment setting: #{instance.inspect} "
    end
    
    [ $1, $2, "#{$2}#{$3}" ]
  rescue Missing
  end
end

module Bountybase
  extend Attributes
end
