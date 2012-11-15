require_relative 'test_helper'

require "bountybase/models"

class ModelTest < Test::Unit::TestCase
  include Bountybase::TestCase

  User = Bountybase::Models::User
  Identity = Bountybase::Models::Identity

  # -- test connection to test database -------------------------------
  
  def test_connection
    assert_nothing_raised() { User.count }
  end

  # -- test account creation ------------------------------------------

  def test_create_accounts
    assert_equal(0, Identity.count)
    assert_equal(0, User.count)

    radiospiel = User["@radiospiel"]
    assert_kind_of(User, radiospiel)
    assert_equal(radiospiel.points, 0)
    assert_equal(radiospiel.badges, [])

    # make sure the type column is set right. This is important to
    # play together with bountyhill.
    identity = Identity.first
    assert_equal("Identity::Twitter", identity.type)
    
    tw_account_2 = User["@radiospiel"]
    assert_equal(tw_account_2, radiospiel)

    tw_account_3 = User["user:#{radiospiel.id}"]
    assert_equal(tw_account_3, radiospiel)

    assert_equal(1, Identity.count)
    assert_equal(1, User.count)

    # create other account
    other = User["@other"]
    assert_kind_of(User, other)
    assert_not_equal(radiospiel, other)

    assert_equal(2, Identity.count)
    assert_equal(2, User.count)
  end
end
