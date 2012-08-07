require 'rubygems'
require 'bundler/setup'

ENV["RACK_ENV"] ||= "test"

require 'ruby-debug'
require 'simplecov'
require 'test/unit'
require 'mocha'

SimpleCov.start do
  add_filter "test/*.rb"
  # the current setup does not properly measure usage in lib/event. 
  add_filter "lib/event.rb"
  add_filter "lib/bountybase/setup.rb"
  add_filter "lib/bountybase/event.rb"
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'bountybase'

require "forwardable"

module Bountybase::TestCase
  extend Forwardable

  delegate :with_settings => Bountybase
  delegate :with_environment => Bountybase

  # Huh? The timecop gem no longer works with Ruby 1.9??
  def freeze_time(time)
    Time.stubs(:now).returns time
  end
end

Bountybase.logger.warn "Bountybase: running test"
