require_relative 'test_helper'

class Bountyconfig < Test::Unit::TestCase
  include Bountybase::TestCase

  def test_config
    Bountybase.reset_attributes!

    assert_raise(Bountybase::Config::Missing) do
      Bountybase.config.foo
    end

    Bountybase.config.foo = "bar"
    assert_equal "bar", Bountybase.config.foo
  end

  def test_redis_config
    Bountybase.reset_attributes!

    with_settings "REDIS_URL" => nil do
      assert_raise(Bountybase::Config::Missing) do
        Bountybase.config.redis
      end
    
      with_environment "development" do
        assert_equal "localhost:6379", Bountybase.config.redis
      end
    end

    with_settings "REDIS_URL" => "foo" do
      assert_equal "foo", Bountybase.config.redis
    end
  end

  def test_resque_config
    Bountybase.reset_attributes!

    with_settings "REDIS_URL" => nil do
      assert_raise(Bountybase::Config::Missing) do
        Bountybase.config.resque
      end
    end

    with_environment "development" do
      assert_equal "localhost:6379", Bountybase.config.resque
    end
  end
end
