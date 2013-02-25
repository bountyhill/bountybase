# This file makes sure that a locally installed and properly linked bountybased repository
# is used instead of the one installed via git submodule. This is
#
# a) to work around a heroku limitation which makes it hard to install private code outside of the app repo, and
# b) to allow local development without having to push every small change and to update all local repos.
#

bountybased = File.join(File.dirname(__FILE__), "..", "bountybased")

bountybase = if File.directory?(bountybased)
  bountybased
else
  bountybased = nil
  File.dirname(__FILE__)
end

STDERR.puts "*** Loading bountybase package from #{bountybase}"
STDERR.puts "*** Warning: Using local copy of bountybase development repository" if bountybased

$: << File.join(bountybase, "lib")

require "bountybase"

STDERR.puts "Using bountybase#{bountybased ? "d" : ""} version #{Bountybase::VERSION}"

if $0 =~ /rake$/
  # when run from rake only setup logging
  Bountybase::Setup.logging
else
  Bountybase.setup
end
