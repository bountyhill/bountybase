require_relative 'test_helper'

require "bountybase/models"

class MessageTweetTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def test_default_queue
    assert_equal("tweet", Bountybase::Message::Tweet.default_queue)
  end

  def test_origin_hash
    freeze_time Time.at(12345678)
    
    with_settings "INSTANCE" => "test-bountybase" do
      assert_equal Bountybase::Message.origin_hash, 
        :instance => "bountybase", :environment => "test", :timestamp => 12345678
    end
  end
  
  TWEET_PAYLOAD = {
    :tweet_id => 123,
    :sender_id => 456,
    :sender_name => "radiospiel",
    :quest_urls => [ "http://bountyhill.local/quests/23" ],
    :receiver_ids => [ 1, 2, 3],
    :receiver_names => [ "receiver1", "receiver2", "receiver3"],
    :text => "Look what I have seen @receiver1 @receiver2 http://bountybase.local/quest/23",
    :lang => "en"
  }
  
  def test_tweet_routing
    Bountybase::Message::Tweet.any_instance.expects :perform 
    perform_message "Tweet", TWEET_PAYLOAD
  end

  def test_tweet_with_invalid_quest
    quest_url = TWEET_PAYLOAD[:quest_urls].first

    # As the quest does not exist this tweet will not be registerd.
    Bountybase::Graph::Twitter.expects(:register).never
    perform_message "Tweet", TWEET_PAYLOAD
  end
  
  def test_tweet_with_existing_quest
    quest23 = Bountybase::Quest.new :title => "t", :description => "d", :bounty_in_cents => 0
    quest23.id = 23
    quest23.save!
    assert_not_nil(Bountybase::Quest.find(23))

    quest24 = Bountybase::Quest.new :title => "t", :description => "d", :bounty_in_cents => 0
    quest24.id = 24
    quest24.save!
    assert_not_nil(Bountybase::Quest.find(24))

    # As the quest does not exist this tweet will not be registerd.
    perform_message "Tweet", TWEET_PAYLOAD
    
    # make sure we have a sender twitter account now
    assert_equal(sender.shared_quests, [quest23])

    # now perform a different quest
    payload = TWEET_PAYLOAD.dup.update(:quest_urls => [ "http://bountyhill.local/quests/23", "http://bountyhill.local/quests/24", "http://bountyhill.local/quests/25"])
    perform_message "Tweet", payload

    # now perform the same quest again
    assert_equal([quest23, quest24], sender.shared_quests.sort_by(&:id))
  end
  
  def sender
    Bountybase::User["@radiospiel"]
  end
  
  def test_tweet_validation
    assert_raise(ArgumentError) {  
      Bountybase::Message::Tweet.enqueue "Tweet", {}
    }
  end
end
