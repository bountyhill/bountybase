#
# Everything Twitter related for building the bounty graph.
module Bountybase::Graph::Twitter
  extend self

  # Shortcut for Bountybase::Neo4j
  Neo4j = Bountybase::Neo4j

  # Shortcut for Bountybase::Graph
  Graph = Bountybase::Graph
    
  # Look up identity node, creates and/or updates it if necessary.
  #
  # If the node does not exist, it will be created.
  # If the node exists, and screen_name is set, the screen_name attribute will
  # be updated if necessary.
  #
  #   Bountybase::Graph::Twitter.identity(12)
  #   Bountybase::Graph::Twitter.identity(12, "screenname")
  #
  # The screen_name should not include the leading "@".
  def identity(uid, screen_name = nil)
    expect! uid => [Integer, Neo4j::Node], screen_name => [/^[^@]/, nil]

    if uid.is_a?(Neo4j::Node)
      expect! uid.type => "twitter_identities"
      uid
    elsif node = Neo4j::Node.find("twitter_identities", uid)
      if screen_name && node["screen_name"] != screen_name
        node["screen_name"] = screen_name
      end
      node
    else
      Neo4j::Node.create("twitter_identities", uid, "screen_name" => screen_name)
    end
  end
  
  #
  # Look up a number of identity nodes, creating if necessary. The returned
  # array of nodes matches the order of uids as passed into the identities
  # method.
  #
  # In contrast to the Twitter#identity method this method does not accept
  # nodes, and is not able to update an identity's screen_name.
  def identities(*uids)
    # == keep all 'uids' that are nodes already.

    existing_nodes, missing_uids = uids.partition do |uid| 
      uid.is_a?(Neo4j::Node)
    end
    
    existing_nodes = existing_nodes.by(&:uid)
    
    # == find nodes for each uid

    expect! {
      missing_uids.each { |uid| expect! uid => Integer }
    }

    found_nodes = Neo4j::Node.find_all("twitter_identities", *missing_uids).by(&:uid)

    # == create nodes for each uid without any found node.

    missing_uids = missing_uids - found_nodes.keys
    missing_nodes = Neo4j::Node.create_many("twitter_identities", *missing_uids).by(&:uid)

    # == put the returned nodes into the right order.
    
    uids.map do |uid|
      uid = uid.uid if uid.is_a?(Neo4j::Node)
      existing_nodes[uid] || found_nodes[uid] || missing_nodes[uid] || raise("Missing node #{uid}")
    end
  end
  
  # Register a bountytweet. Takes a option hash with these parameters:
  #
  # - +:tweet_id+: the tweet id
  # - +:sender_id+: the identity of the sender (e.g. 1234). 
  # - +:sender_name+: The screen_name of the sender. (Optional)
  # - +:source_id+: the identity of the source (e.g. 1234). 
  #   This is the _in_reply_to_ account, in Twitter lingo. (Optional)
  # - +:source_name+: The screen_name of the source. (Optional)
  # - +:quest_id+: the ID of the bounty quest
  # - +:receiver_ids+: an optional array of twitter user ids, 
  #   that also receive this tweet. These are users that are
  #   mentioned in a tweet.
  # - +:receiver_names+: an optional array of screen_names of 
  #   the +receiver_ids+ users, in the order of the +receiver_ids+
  #   setting.
  # - +:text+: the text of the tweet
  # - +:lang+: the language of the tweet 
  #
  def register(options = {})
    expect! options => {
      :tweet_id     => Integer,         # The id of the tweet 
      :sender_id    => Integer,         # The twitter user id of the user sent this tweet 
      :sender_name  => [String, nil],   # The twitter screen name of the user sent this tweet 
      :source_id    => [Integer, nil],  # The twitter user id of the user from where the sender knows about this bounty.
      :source_name  => [String, nil],   # The twitter screen name of the user from where the sender knows about this bounty.
      :quest_id     => Integer,       # The url for the quest.
      :receiver_ids => [Array, nil],    # An array of user ids of twitter users, that also receive this tweet.
      :receiver_names => [Array, nil],  # An array of screen names of twitter users, that also receive this tweet.
      :text         => String,          # The tweet text
      :lang         => String           # The tweet language
    }

    # Apart from the receiver_ids and receiver_names entries all values 
    # must be Strings or Fixnums, or else Neo4j could not save those.
    receiver_ids = options.delete(:receiver_ids) || []
    receiver_names = options.delete(:receiver_names) || []
    
    expect {
      expectations = options.keys.inject({}) do |h, key| h.update key => [ String, Fixnum ] end
      expect! options => expectations
    }

    # Is this really a quest?
    quest = Graph.quest options[:quest_id]
    return if quest.nil?
    
    # We don't have to register this tweet twice...
    return if Neo4j::Node.find("tweets", options[:tweet_id])

    Neo4j::Node.create("tweets", options[:tweet_id], options)

    sender = identity(options[:sender_id], options[:sender_name])

    # If the sender is not yet connected then we must connect it, preferably via an
    # extra source node. If there is no source, then the sender probably knows the
    # quest directly from the website, and is therefore entitled to a direct
    # connection to the quest.
    unless connected?(quest, sender)
      Neo4j.connect "known_by", quest, sender, :created_at => Time.now.to_i

      source = tweet_source(sender, quest, options)
      Neo4j.connect "forwarded_#{quest.uid}", (source || quest) => sender
    end 

    # connect additional receivers
    receiver_ids = options[:receiver_ids] || []
    receiver_names = options[:receiver_names] || []

    receiver_ids.each_with_index do |receiver_id, idx|
      receiver_name = receiver_names[idx] 
      receiver = identity(receiver_id, receiver_name) 
      next if connected?(quest, receiver)
      
      Neo4j.connect "known_by", quest, receiver, :created_at => Time.now.to_i
      Neo4j.connect "forwarded_#{quest.uid}", quest, sender
    end
  end
  
  private

  def connected?(quest, receiver) #:nodoc:
    expect! quest => Neo4j::Node, receiver => Neo4j::Node
    
    Neo4j.ask <<-CYPHER
      START src=node:quests(uid='#{quest.uid}'), target=node:twitter_identities(uid='#{receiver.uid}')
      MATCH src-[relationship:known_by]->target 
      RETURN relationship
    CYPHER
  end
  
  # return the tweet source.
  #
  # This method also guarantees that the source is properly connected to
  # the quest by connecting if needed. This can only occur if the source
  # is set via the :source_id option.
  def tweet_source(sender, quest, options) #:nodoc:
    if options[:source_id]
      source = identity(options[:source_id], options[:source_name]) 
      unless connected?(quest, source)
        Neo4j.connect "known_by", quest, source, :created_at => Time.now.to_i
        Neo4j.connect "forwarded_#{quest.uid}", quest => source
      end
    else
      source = source_for_tweet sender, quest
      expect! source => [nil, Bountybase::Neo4j::Node]
    end
    source
  end

  public
  
  # How does the sender know the quest? If it is not passed in (because a
  # tweet is a retweet, after all), then the sender probably knows about
  # a quest from one of its followees. This methods find a potential source
  # for a tweet by sender. From all twitter identities that
  #
  # a) are connected to quest and
  # b) are being followed by the sender.
  #
  # it returns the one which knows the longest about the quest.
  #
  # This method is used
  #
  # a) to connect a tweet which is not a retweet, and
  # b) to connect a website user to a quest.
  #
  # This method relies on followership properly set (via :register_followees)
  def source_for_tweet(sender, quest)
    update_followees(sender)
    
    expect! quest => Bountybase::Neo4j::Node

    source = Neo4j.ask <<-CYPHER
      START quest=node:quests(uid='#{quest.uid}'), followee=node(*), sender=node:twitter_identities(uid='#{sender.uid}')
      MATCH quest-[rel:known_by]->followee<-[:follows]-sender
      RETURN followee
      ORDER BY rel.created_at
      LIMIT 1
    CYPHER
  end
  
  #
  # Register followership between twitter users. Note that you can and 
  # should register more than a single followership with each call of
  # Twitter.register_followees. 
  #
  #   register_followees(1 => 2)                  # user 1 follows of user 2
  #   register_followees(1 => [2,3], 4 => 5)      # user 1 follows users 2 and 3, user 4 follows user 2.
  #
  # Values are twitter ids (integers) or "twitter_identities" nodes.
  def register_followees(data) 
    connections = data.map do |follower_id, followee_ids|
      follower, *followees = identities(follower_id, *followee_ids)
      followees.map { |followee| [ follower, followee ] }
    end.flatten
    
    Neo4j.connect "follows", *connections
  end
  
  FOLLOWEES_CACHING_TIMEOUT = 7 * 24 * 3600 # 7 days timeout
  
  #
  # Update followees for a user, but only if the user's followees haven't been updated
  # recently. This is to make sure we don't hit Twitter's API limits.
  def update_followees(sender)
    followees_updated_at = sender["followees_updated_at"]
    return unless followees_updated_at.nil? || followees_updated_at < Time.now.to_i - FOLLOWEES_CACHING_TIMEOUT
    
    update_followees! sender
  end
  
  #
  # Update followees for a user.
  def update_followees!(sender)
    followee_ids = Bountybase::TwitterAPI.followee_ids(sender.uid)
    register_followees sender => followee_ids
    sender["followees_updated_at"] = Time.now.to_i
  end
end
