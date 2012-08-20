require_relative "expectations"

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

  # resolves a bounty url. 
  # Returns the id of a quest if the url matches it.
  def resolve_quest_url(url, allow_resolve = true)
    expect! url => String
    
    case url
    when /^(?:http|https):\/\/[a-z.]*\bbountyhill\.(?:com|local)\/quest\/(\d+)\b/
      Integer($1)
    when /^(?:http|https):\/\/[a-z.]*\bbountyhill\.(?:com|local)\//
      nil
    else
      resolve_quest_url Bountybase::HTTP.resolve(url), false if allow_resolve
    end
  end
end

require_relative "bountybase/attributes"
require_relative "bountybase/http"
require_relative "bountybase/event"
require_relative "bountybase/message"
require_relative "bountybase/setup"
require_relative "bountybase/metrics"
require_relative "bountybase/neo4j"
require_relative "bountybase/graph"
