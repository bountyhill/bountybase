require_relative 'test_helper'

require "bountybase/models"

class MessageRewardTest < Test::Unit::TestCase
  include Bountybase::TestCase

  Message   = Bountybase::Message
  Reward    = Message::Reward
  User      = Bountybase::User
  Identity  = Bountybase::Identity

  # -- test reward message routing ------------------------------------
  
  def test_reward_routing
    Message::Reward.any_instance.expects :perform 
    perform_message "Reward", :account => "@radiospiel", :points => 12
  
    Resque::Job.expects(:create).
      with "reward",                                    # name of queue
        Message,                                        # resque target performer
        'Bountybase::Message::Reward',                  # message name
        { :account => "@radiospiel", :points => 12 },   # message payload
        MESSAGE_ORIGIN                                  # message origin

    Message::Reward.expects(:origin_hash).returns(MESSAGE_ORIGIN)
    Message::Reward.enqueue :account => "@radiospiel", :points => 12
  end

  # -- test reward message performing ---------------------------------

  def test_reward_points
    perform_message "Reward", :account => "@radiospiel", :points => 12
    assert_equal(User["@radiospiel"].points, 12)

    perform_message "Reward", :account => "@radiospiel", :points => 12, :badge => "badge"
    assert_equal(User["@radiospiel"].points, 24)
    assert_equal(User["@radiospiel"].badges, %w(badge))

    perform_message "Reward", :account => "@radiospiel", :points => 12, :badge => "badge"
    assert_equal(User["@radiospiel"].points, 36)
    assert_equal(User["@radiospiel"].badges, %w(badge))

    perform_message "Reward", :account => "@radiospiel", :badge => "other"
    assert_equal(User["@radiospiel"].points, 36)
    assert_equal(User["@radiospiel"].badges, %w(badge other))
  end
end
