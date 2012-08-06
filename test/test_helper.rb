require 'rubygems'
require 'bundler/setup'

ENV["RACK_ENV"] ||= "test"

require 'ruby-debug'
require 'simplecov'
require 'timecop'
require 'test/unit'
SimpleCov.start do
  add_filter "test/*.rb"
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'bountybase'

module Bountybase::TestCase
  def test_trueish
    assert true
  end
end

Bountybase.logger.warn "Bountybase: running test"
