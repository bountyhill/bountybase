# This file makes sure that a locally installed and properly linked bountybased repository
# is used instead of the one installed via git submodule. This is
#
# a) to work around a heroku limitation which makes it hard to install private code outside of the app repo, and
# b) to allow local development without having to push every small change and to update all local repos.
#
STDERR.puts "Loading bountybase package from #{File.dirname(__FILE__)}"

bountybased = File.join(File.dirname(__FILE__), "..", "bountybased")

bountybase = if File.directory?(bountybased)
  STDERR.puts "*** Warning: Using local copy of bountybase development repository"
  bountybased
else
  bountybased = nil
  File.dirname(__FILE__)
end

$: << File.join(bountybase, "lib")

require "bountybase"

STDERR.puts "Using bountybase#{bountybased ? "d" : ""} version #{Bountybase::VERSION}"
