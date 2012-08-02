# The Bountybase namespace organizes data access patterns for the Bountyhill application.
module Bountybase; end

require_relative "bountybase/config"

module Bountybase
  extend self
  
  # -- register a tweet

  # return true if this is a bountytweet.
  def bountytweet?(tweet)
    true
  end
  
  # This method registers a tweet as received from the twitter streaming API.
  def register_tweet(tweet)
  end
  
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
  
  private
  
  def run_in_environment(environment, &block) # :nodoc:
    old = @environment
    @environment = environment
    yield
  ensure
    @environment = old
  end
end

require_relative "bountybase/http"
