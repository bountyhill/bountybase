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

module Bountybase::Attributes
  # resets the name of the environment setting for the duration of a block. 
  # This method should not be used outside of tests.
  def reset_attributes!
    @root = @environment = @role = @instance = nil
  end
end

module Bountybase::TestCase
  def with_environment(environment, &block) # :nodoc:
    Bountybase.reset_attributes!
    with_settings "RACK_ENV" => environment, "RAILS_ENV" => environment, &block
  ensure
    Bountybase.reset_attributes!
  end

  def with_settings(settings, &block)
    old_env = {}
    settings.each { |key, value| 
      old_env[key] = ENV[key]
      ENV[key] = value 
    }

    yield
  ensure
    ENV.update old_env
  end

  # Huh? The timecop gem no longer works with Ruby 1.9??
  def freeze_time(time)
    Time.stubs(:now).returns time
  end
end

Bountybase.logger.warn "Bountybase: running test"
