require 'rubygems'
require 'bundler/setup'

ENV["RACK_ENV"] ||= "test"

require 'ruby-debug'
require 'simplecov'
require 'test/unit'
require 'test/unit/ui/console/testrunner'   

class Test::Unit::UI::Console::TestRunner
  def guess_color_availability; true; end
end

require 'mocha'
require 'awesome_print'

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

# -- Basic VCR configuration

require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/http_test'
  c.hook_into :webmock # or :fakeweb
  c.ignore_localhost = true
  c.allow_http_connections_when_no_cassette = true
end

# Disable WebMock's curb adapter: that way all curb traffic - which should be
# Neo4j traffic *only* - is not handled via webmock nor vcr.
WebMock::HttpLibAdapters::CurbAdapter.disable!

# -- a Bountybase TestCase with some helpers

module Bountybase::TestCase
  extend Forwardable

  delegate :with_settings => Bountybase
  delegate :with_environment => Bountybase

  # Huh? The timecop gem no longer works with Ruby 1.9??
  def freeze_time(time)
    Time.stubs(:now).returns time
  end

  def assert!(*expectations, &block)
    expect!(*expectations, &block)
    assert true
  rescue ArgumentError
    assert false, $!.to_s
  end

  def performance_tests?
    !ENV["PERFORMANCE"].nil?
  end

  # -- helper to register tweets ----------------------------------------------

  Graph = Bountybase::Graph
  Neo4j = Bountybase::Neo4j
  
  TWEET_DEFAULTS = {
    :quest_id => 23,
    :text => "My first #bountytweet",                   # The tweet text
    :lang => "en"                                       # The tweet language
  }

  @@tweet_id = 123
  
  def register_tweet(options = {})
    @@tweet_id += 1
    
    Graph::Twitter.register TWEET_DEFAULTS.merge(:tweet_id => @@tweet_id).merge(options)
  end
end
