require_relative 'test_helper'

class ConfigTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def test_config
    assert_raise(Bountybase::Config::Missing) do
      Bountybase.config.foo!
    end

    assert_nil Bountybase.config.foo

    Bountybase.config.foo = "bar"
    assert_equal "bar", Bountybase.config.foo
  end
end
