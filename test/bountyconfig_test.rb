require_relative 'test_helper'

class Bountyconfig < Test::Unit::TestCase
  include Bountybase::TestCase

  def test_config
    assert_raise(Bountybase::Config::Missing) do
      Bountybase.config.abc
    end

    Bountybase.config.abc = "abc"
    assert_equal "abc", Bountybase.config.abc
  end

  def test_redis_config
    # the redis config is read from either 
    
    assert_raise(Bountybase::Config::Missing) do
      Bountybase.config.redis
    end

    Bountybase.environment "development" do
      assert_equal "localhost:6379", Bountybase.config.redis
    end
  end
end
