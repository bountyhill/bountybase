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
    return if quest_ids.empty?
    
    # register in AR DB
    Bountybase::User.transaction do
      sender_name = payload[:sender_name]
      account = Bountybase::User["@#{sender_name}"] if sender_name
      
      account.register_quest_ids(quest_ids) if account
    end
    
    # register in graph DB
    quest_ids.each do |quest_id|
      Bountybase::Graph::Twitter.register(payload.update(:quest_id => quest_id))
    end
  end

  private
  
  def quest_id #:nodoc:
    quest_ids.first
  end
  
  def quest_ids #:nodoc:
    return @quest_ids if @quest_ids

    # resolve quest URLs.
    @quest_ids = Bountybase::HTTP.resolved_urls(quest_urls).
      map { |_, resolved_url| Bountybase::Graph.quest_id(resolved_url) }.
      compact
    return @quest_ids if @quest_ids.empty? 

    # filter quest URLs via database
    @quest_ids = Bountybase::Quest.where(:id => quest_ids).all(:select => "id").map(&:id)
    return @quest_ids if @quest_ids.empty? 

    @quest_ids
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
