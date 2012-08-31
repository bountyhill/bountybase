require "expectation"
require_relative "kernel/enumerable_ext"
require_relative "kernel/hash_ext"
require_relative "kernel/standard_error_ext"

# The Bountybase namespace organizes code for the Bountyhill applications.
# A rough breakdown includes the following sub modules:
#
# = Configuration
#
# - Bountyhill::Attributes: attributes for a running Bountyhill application.
# - Bountyhill::Config: global configuration for Bountyhill applications.
# - Bountyhill::Setup: initialize a Bountyhill applications
#
# = Bountyhill infrastructure
#
# - Bountyhill::Graph: building and querying the Bountyhill graph
# - Bountyhill::Message: messaging and queueing tasks between different Bountyhill components.
# - Bountyhill::Metrics: end point for collecting Bountyhill statistics and metrics.
#
# = low level code
#
# You probably don't need this code.
#
# - Bountyhill::HTTP: HTTP and HTTPS requests
# - Bountyhill::Neo4j: Neo4j interface
# - Bountyhill::TwitterAPI: Twitter API request methods.
#
# = Loading the Bountybase code base.
#
# The Bountybase code is not distributed as a gem, because it contains 
# secret credentials in the config.yml file. We chose this way because
# there is a heroku limitation in referring private code from an application.

# Bountybase is expected to be installed in its target apps as a Git submodule
# under vendor/bountybase. To load and set up the bountybase code base you use
#
#   require_relative "vendor/bountybase/setup"
#
# For your local development environment you may link a local bountybase 
# repository into vendor/bountybased; this allows you to work in the
# bountybase codebase and the target app at the same time, without having
# to push changes to bountybase inbetween.
module Bountybase
  #
  # All instance methods in the Bountybase module will be added onto the
  # Bountybase object 
  extend self
end

require_relative "bountybase/version"
require_relative "bountybase/config"
require_relative "bountybase/attributes"
require_relative "bountybase/http"
require_relative "bountybase/event"
require_relative "bountybase/message"
require_relative "bountybase/setup"
require_relative "bountybase/metrics"
require_relative "bountybase/neo4j"
require_relative "bountybase/graph"
require_relative "bountybase/twitter_api"
