require_relative 'test_helper'

require "bountybase/models"

class RewardTest < Test::Unit::TestCase
  include Bountybase::TestCase

  Reward = Bountybase::Message::Reward
  User = Bountybase::User
  Identity = Bountybase::Identity

  def setup
    Identity.delete_all
    User.delete_all
  end
  
  # -- test connection to test database -------------------------------
  
  def test_connection
    assert_nothing_raised() { User.count }
  end

  # -- test account creation ------------------------------------------

  def test_create_accounts
    twitter_count, user_count = [ Identity.count, User.count ]

    radiospiel = Reward.account("twitter:radiospiel")
    assert_kind_of(User, radiospiel)
    assert_equal(radiospiel.points, 0)
    assert_equal(radiospiel.badges, [])

    tw_account_2 = Reward.account("twitter:radiospiel")
    assert_equal(tw_account_2, radiospiel)

    tw_account_3 = Reward.account("user:#{radiospiel.id}")
    assert_equal(tw_account_3, radiospiel)

    assert_equal(twitter_count+1, Identity.count)
    assert_equal(user_count+1, User.count)

    # create other account
    other = Reward.account("twitter:other")
    assert_kind_of(User, other)
    assert_not_equal(radiospiel, other)

    assert_equal(twitter_count+2, Identity.count)
    assert_equal(user_count+2, User.count)
  end

  # -- test reward message routing ------------------------------------
  
  ORIGIN = { :instance => 'test', :environment => 'test', :timestamp => 1344259800 }
  
  def test_reward_routing
    Bountybase::Message::Reward.any_instance.expects :perform 
    Bountybase::Message.perform "Reward", 
      { :account => "twitter:radiospiel", :points => 12 }, 
      ORIGIN
  
    Resque::Job.expects(:create).
      with "reward",                                            # name of queue
        Bountybase::Message,                                    # resque target performer
        'Bountybase::Message::Reward',                          # message name
        { :account => "twitter:radiospiel", :points => 12 },    # message payload
        ORIGIN                                                  # message origin

    Bountybase::Message::Reward.expects(:origin_hash).returns(ORIGIN)
    Bountybase::Message::Reward.enqueue :account => "twitter:radiospiel", :points => 12
  end

  # -- test reward message performing ---------------------------------

  def perform(options)
    Bountybase::Message.perform "Reward", options, ORIGIN
  end

  def radiospiel
    Reward.account("twitter:radiospiel")
  end
  
  def test_reward_points
    perform :account => "twitter:radiospiel", :points => 12
    assert_equal(radiospiel.points, 12)

    perform :account => "twitter:radiospiel", :points => 12, :badge => "badge"
    assert_equal(radiospiel.points, 24)
    assert_equal(radiospiel.badges, %w(badge))

    perform :account => "twitter:radiospiel", :points => 12, :badge => "badge"
    assert_equal(radiospiel.points, 36)
    assert_equal(radiospiel.badges, %w(badge))

    perform :account => "twitter:radiospiel", :badge => "other"
    assert_equal(radiospiel.points, 36)
    assert_equal(radiospiel.badges, %w(badge other))
  end
end
