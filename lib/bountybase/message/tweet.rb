# A Bountybase::Message::Tweet message is sent whenever bountytwirl sees
# a (potentially) matching twitter status. bountytwirl then generates a
# Bountybase::Message::Tweet message, which is to be processed by  
# bountyclerk.
class Bountybase::Message::Tweet < Bountybase::Message
  
  # The quest_urls as passed in from the payload.
  attr_reader :quest_urls
  
  def initialize(payload, origin)
    expect! payload => { :quest_urls => Array }

    @quest_urls = payload.delete(:quest_urls)
    super payload, origin
  end
  
  # perform the message
  def perform
    W "perform", quest_urls
    return unless quest_id
    I "Quest ##{quest_id}: register tweet", payload[:text]

    Bountybase::Graph::Twitter.register(payload.update(:quest_id => quest_id))
  end

  private

  # resolve quest URLs.
  def resolved_urls #:nodoc:
    @resolved_urls ||= quest_urls.map do |url|
      Bountybase::HTTP.resolve(url)
    end.compact.
      tap do |urls| 
        W "urls resolve to", [ urls ] 
      end
  end
  
  def quest_id #:nodoc:
    @quest_id ||= resolved_urls.
      map { |url| Bountybase::Graph.quest_id(url) }.
      compact.first.tap { |quest_id| W "Found quest_id", quest_id }
  end

  def quest_id_for_tests #:nodoc:
    quest_url = quest_urls.first
    quest_url.hash % 33 if quest_url
  end

  # alias_method :quest_id :quest_id_for_tests

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
