require_relative 'test_helper'

require "bountybase/models"

class MessageRewardTest < Test::Unit::TestCase
  include Bountybase::TestCase

  Reward    = Bountybase::Message::Reward
  User      = Bountybase::Models::User
  Identity  = Bountybase::Models::Identity

  # -- test reward message routing ------------------------------------
  
  def test_reward_routing
    Reward.any_instance.expects :perform 
    perform_message "Reward", :account => "@radiospiel", :badge => "badge"
  
    Resque::Job.expects(:create).
      with "reward",                                      # name of queue
        Bountybase::Message,                              # resque target performer
        'Bountybase::Message::Reward',                    # message name
        { :account => "@radiospiel", :badge => "badge" }, # message payload
        MESSAGE_ORIGIN                                    # message origin

    Reward.expects(:origin_hash).returns(MESSAGE_ORIGIN)
    Reward.enqueue :account => "@radiospiel"
  end

  # -- test reward message performing ---------------------------------

  def test_reward_badge
    perform_message "Reward", :account => "@radiospiel", :badge => "badge"
    assert_equal(User["@radiospiel"].badges, %w(badge))

    perform_message "Reward", :account => "@radiospiel", :badge => "other"
    assert_equal(User["@radiospiel"].badges, %w(badge other))
  end

  def test_reward_shortcut
    Bountybase.reward User["@radiospiel"], :badge => "badge"
    assert_equal(User["@radiospiel"].badges, %w(badge))
  end
end
