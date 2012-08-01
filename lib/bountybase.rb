# The Bountybase namespace organizes data access patterns for the Bountyhill application.

module Bountybase
  extend self
  
  # -- configuration

  @@config = OpenStruct.new
  
  def config
    @@config
  end
end
