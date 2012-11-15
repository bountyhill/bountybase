require_relative 'test_helper'

class BountybaseTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def test_application_root
    with_settings "RACK_ROOT" => nil do
      assert_raise(Bountybase::Attributes::Missing) { 
        Bountybase.root 
      }
    end

    with_settings "RACK_ROOT" => "expected" do
      assert_equal "expected", Bountybase.root
    end
  end

  def test_environment
    assert_equal "test", Bountybase.environment

    with_environment "yadda" do
      assert_equal "yadda", Bountybase.environment
    end

    assert_equal "test", Bountybase.environment
  end

  def test_instance
    with_settings "INSTANCE" => "a-b1" do
      assert_equal "b1", Bountybase.instance
      assert_equal "b", Bountybase.role
      assert_equal "a", Bountybase.environment

      # read environment from "RAILS_ENV" or "RACK_ENV", when ste
      with_settings "RACK_ENV" => "KJH", "RAILS_ENV" => "KJH", "INSTANCE" => nil do
        assert_equal "KJH", Bountybase.environment
      end

      # read environment from "INSTANCE" when RAILS_ENV" and "RACK_ENV" are not set
      with_settings "RACK_ENV" => nil, "RAILS_ENV" => nil do
        assert_equal "a", Bountybase.environment
      end
    end
  end
  
  def test_nil_instance
    with_settings "INSTANCE" => nil do
      # Bountybase.instance defaults to test, if INSTANCE is not set.
      assert_equal "test", Bountybase.instance

      assert_raise(Bountybase::Attributes::Missing) { Bountybase.role }

      # read environment from "RAILS_ENV" or "RACK_ENV", when set
      with_settings "RACK_ENV" => "KJH", "RAILS_ENV" => "KJH" do
        assert_equal "KJH", Bountybase.environment
      end

      # default to development when RAILS_ENV" and "RACK_ENV" are not set
      with_settings "RACK_ENV" => nil, "RAILS_ENV" => nil do
        assert_equal "development", Bountybase.environment
      end
    end
  end
  
  #
  # Test bountyhill URLs. They must all not run through the resolver.
  def test_bountyhill_quest_urls
    Bountybase::HTTP.stubs(:resolve).raises("Dont call me")
    
    assert_nothing_raised {  
      assert_equal 23, Bountybase::Graph.quest_id("http://bountyhill.local/quests/23")
      assert_equal 42, Bountybase::Graph.quest_id("https://www.bountyhill.local/quests/42")
      assert_equal nil, Bountybase::Graph.quest_id("https://www.bountyhill.local/account/12")

      # These are real bountyhill URLs
      assert_equal 123, Bountybase::Graph.quest_id("http://bountyhill-staging-web1.herokuapp.com/quests/123")
      assert_equal 123, Bountybase::Graph.quest_id("http://bountyhill-staging-web1.herokuapp.com/q/123")
      assert_equal 123, Bountybase::Graph.quest_id("http://bountyhill.herokuapp.com/quests/123")
      assert_equal 123, Bountybase::Graph.quest_id("http://bountyhill.herokuapp.com/q/123")
      assert_equal 123, Bountybase::Graph.quest_id("https://bountyhill.com/quests/123")
      assert_equal 123, Bountybase::Graph.quest_id("https://bountyhill.com/q/123")
      assert_equal 123, Bountybase::Graph.quest_id("https://www.bountyhill.com/quests/123")
      assert_equal 123, Bountybase::Graph.quest_id("https://www.bountyhill.com/q/123")

      assert_equal nil, Bountybase::Graph.quest_id("https://bountyhill.com/xyz/123")
      assert_equal nil, Bountybase::Graph.quest_id("https://www.bountyhill.com")
    }
  end
  
  def test_quest_id
    assert_equal 12, Bountybase::Graph.quest_id(12)

    # Test real ids via resolving. Requests and answers are prerecorded
    # for these tests.
    Bountybase::HTTP.expects(:resolve).with("http://t.co/ZczESpRE").
      returns("http://audiohackday.org/")
    assert_equal nil, Bountybase::Graph.quest_id("http://t.co/ZczESpRE")

    Bountybase::HTTP.expects(:resolve).with("http://t.co/jkgha786jhg").
      returns("https://www.bountyhill.local/account/12")
    assert_equal nil, Bountybase::Graph.quest_id("http://t.co/jkgha786jhg")
  end
  
  def test_simple_cache
    s = "foo"
    assert_equal "foo", Bountybase.cached("key") { s }
    
    s = "baz"
    assert_equal "foo", Bountybase.cached("key") { s }
  end
  
  def test_array_ext
    h = []
    h.push a: 1
    h.push a: 3
    h.push a: 2
    
    assert_equal([1, 3, 2], h.pluck(:a))
  end
end
