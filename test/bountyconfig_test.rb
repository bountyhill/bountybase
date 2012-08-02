require_relative 'test_helper'

class Bountyconfig < Test::Unit::TestCase
  include Bountybase::TestCase

  def test_config
    assert_raise(Bountybase::Config::Missing) do
      Bountybase.config.foo
    end

    Bountybase.config.foo = "bar"
    assert_equal "bar", Bountybase.config.foo
  end

  def with_env(name, value)
    old = ENV[name]
    ENV[name] = value
    yield
  ensure
    ENV[name] = old
  end
    
  def test_redis_config
    with_env "REDIS_URL", nil do
      assert_raise(Bountybase::Config::Missing) do
        Bountybase.config.redis
      end
    
      Bountybase.environment "development" do
        assert_equal "localhost:6379", Bountybase.config.redis
      end
    end

    with_env "REDIS_URL", "foo" do
      assert_equal "foo", Bountybase.config.redis
    end
  end

  def test_resque_config
    with_env "REDIS_URL", nil do
      assert_raise(Bountybase::Config::Missing) do
        Bountybase.config.resque
      end
    end

    Bountybase.environment "development" do
      assert_equal "localhost:6379", Bountybase.config.resque
    end
  end
end
