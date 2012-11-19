require_relative 'test_helper'

class TwitterApiTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def setup
    Neo4j.purge!
  end

  def test_find_followees
    VCR.use_cassette('followees_radiospiel', :record => :new_episodes, :allow_playback_repeats => true) do
      followee_ids = Bountybase::TwitterAPI.followee_ids("radiospiel")
      assert_equal 225, followee_ids.length
      assert_equal [Fixnum], followee_ids.map(&:class).uniq
    end

    # 11754212 is radiospiel's user id.
    VCR.use_cassette('followees_11754212', :record => :new_episodes, :allow_playback_repeats => true) do
      followee_ids = Bountybase::TwitterAPI.followee_ids(11754212)
      assert_equal 225, followee_ids.length
      assert_equal [Fixnum], followee_ids.map(&:class).uniq
    end
  end

  def test_lookup_users
    users = VCR.use_cassette('lookup_users', :record => :new_episodes, :allow_playback_repeats => true) do
      followee_ids = Bountybase::TwitterAPI.followee_ids(11754212)
      assert_equal followee_ids[0..2].sort, [14151928, 561159199, 867661057]
      Bountybase::TwitterAPI.users(followee_ids[0..2])
    end
    
    assert_kind_of(Hash, users)
    assert_equal([14151928, 561159199, 867661057], users.keys.sort)

    # The returned values are Twitter::User objects, that support at least
    # the attributes as tested below.
    user = users[14151928]
    assert_kind_of(Twitter::User, user)
    
    assert! user.id                 => 14151928,
      user.friends_count            => Fixnum,
      user.favourites_count         => Fixnum,
      user.name                     => String,
      user.screen_name              => String,
      user.profile_image_url        => /^http:/,
      user.profile_image_url_https  => /^https:/,
      user.location                 => String,
      user.description              => String,
      user.lang                     => /^..$/
  end
end
