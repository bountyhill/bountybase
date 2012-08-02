# The Bountybase namespace organizes data access patterns for the Bountyhill application.

module Bountybase
  extend self
  
  # -- configuration

  @@config = OpenStruct.new
  
  # The Bountybase configuration object.
  def config
    @@config
  end

  # find application root.
  def root
    @root ||= ENV["RAILS_ROOT"] || ENV["RACK_ROOT"] || raise("Cannot determine root dir. Please set RAILS_ROOT or RACK_ROOT")
  end
end

require_relative "bountybase/http"
