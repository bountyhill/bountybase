# A Bountybase::Message::Tweet message is sent whenever bountytwirl sees
# a (potentially) matching twitter status. bountytwirl then generates a
# Bountybase::Message::Tweet message, which is to be processed by  
# bountyclerk.
class Bountybase::Message::Tweet < Bountybase::Message
  # perform the heartbeat message.
  def perform
    Bountybase::Graph::Twitter.register payload
  end
  
  def self.validate!(payload)
    expect! payload => {
      :tweet_id     => Integer,         # The id of the tweet 
      :sender_id    => Integer,         # The twitter user id of the user sent this tweet 
      :sender_name  => [String, nil],   # The twitter screen name of the user sent this tweet 
      :source_id    => [Integer, nil],  # The twitter user id of the user from where the sender knows about this bounty.
      :source_name  => [String, nil],   # The twitter screen name of the user from where the sender knows about this bounty.
      :quest_url    => /http.*$/,       # The url for the quest.
      :receiver_ids => [Array, nil],    # An array of user ids of twitter users, that also receive this tweet.
      :receiver_names => [Array, nil],  # An array of screen names of twitter users, that also receive this tweet.
      :text         => String,          # The tweet text
      :lang         => String           # The tweet language
    }
  end
end
