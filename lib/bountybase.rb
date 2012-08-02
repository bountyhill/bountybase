# The Bountybase namespace organizes data access patterns for the Bountyhill application.
module Bountybase; end

require_relative "bountybase/config"

module Bountybase
  extend self

  VERSION = "0.1"
  
  # -- register a tweet

  # return true if this is a bountytweet.
  def bountytweet?(tweet)
    true
  end
  
  # This method registers a tweet as received from the twitter streaming API.
  def register_tweet(tweet)
  end
end

require_relative "bountybase/attr"
require_relative "bountybase/http"
