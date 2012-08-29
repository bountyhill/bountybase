# A Bountybase::Message::Tweet message is sent whenever bountytwirl sees
# a (potentially) matching twitter status. bountytwirl then generates a
# Bountybase::Message::Tweet message, which is to be processed by  
# bountyclerk.
class Bountybase::Message::Tweet < Bountybase::Message
  # perform the heartbeat message.
  def perform
    return unless quest_id

    Bountybase::Graph::Twitter.register(payload.merge(:quest_id => quest_id))
  end

  def quest_id
    @quest_id ||= payload[:quest_urls].map do |url|
      expect! url => /http.*$/
      Bountybase::Graph.quest_id(url)
    end.compact.first
  end
  
  def self.validate!(payload)
    expect! payload => {
      :tweet_id     => Integer,         # The id of the tweet 
      :sender_id    => Integer,         # The twitter user id of the user sent this tweet 
      :sender_name  => [String, nil],   # The twitter screen name of the user sent this tweet 
      :source_id    => [Integer, nil],  # The twitter user id of the user from where the sender knows about this bounty.
      :source_name  => [String, nil],   # The twitter screen name of the user from where the sender knows about this bounty.
      :quest_urls   => Array,           # The url for the quest.
      :receiver_ids => [Array, nil],    # An array of user ids of twitter users, that also receive this tweet.
      :receiver_names => [Array, nil],  # An array of screen names of twitter users, that also receive this tweet.
      :text         => String,          # The tweet text
      :lang         => String           # The tweet language
    }
  end
end
