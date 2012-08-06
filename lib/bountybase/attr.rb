module Bountybase
  # -- Bountybase configuration

  # find application root.
  def root
    @root ||= ENV["RAILS_ROOT"] || ENV["RACK_ROOT"] || 
                raise("Cannot determine root dir. Please set RAILS_ROOT or RACK_ROOT")
  end

  # returns or adjusts the name of the current environment. 
  #
  # You should only adjust the name of the environment for some tests.
  def environment(environment = nil, &block)
    return run_in_environment(environment, &block) if environment && block_given?
    
    @environment ||= ENV["RAILS_ENV"] || 
      ENV["RACK_ENV"] || 
      ENV["ENV"] || 
      "development"
  end
  
  # returns the name of the running instance. This name describes the function of the
  # running software component (i.e. bountytwirl). It defaults to the INSTANCE environment
  # variable, and, if that is not set, to the name of the environment.
  def instance
    ENV["INSTANCE"] || environment
  end
  
  private
  
  def run_in_environment(environment, &block) # :nodoc:
    old = @environment
    @environment = environment
    yield
  ensure
    @environment = old
  end
end
