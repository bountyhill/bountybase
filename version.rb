# This file makes sure that a locally installed and properly linked bountybased repository
# is used instead of the one installed via git submodule. This is
#
# a) to work around a heroku limitation which makes it hard to install private code outside of the app repo, and
# b) to allow local development without having to push every small change and to update all local repos.
#
# Usage:
#
#   require_relative "vendor/bountybase/version"
#
if File.directory?("#{File.dirname(__FILE__)}/../bountybased")
  require_relative "../bountybased/lib/bountybase/version"
else
  require_relative "../bountybase/lib/bountybase/version"
end
