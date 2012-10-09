require "twitter"                           # i.e. the Twitter gem, not Bountybase::Graph::Twitter
require_relative "./twitter_api"

#
# Everything Twitter API related used by Bountybase code.
module Bountybase::TwitterAPI
  extend self

  # returns an array of followee_ids for a given user, identified by either
  # its screen name or its twitter user id.
  def followee_ids(user)
    expect! user => [Integer, String]
    
    benchmark :warn, "Fetching followee_ids" do |bm|
      r = client.friend_ids(user).all
      bm.message = "Fetching #{r.length} followee_ids"
      r
    end
  rescue StandardError
    $!.log "TwitterAPI.followee_ids"
    []
  end
  
  # Lookup user information.
  def users(user_ids)
    expect! user_ids => [Array]

    benchmark :warn, "Fetching user information on #{user_ids.length} users" do
      users = client.users(user_ids)  # fetch users as an array.
      users.by(&:id)                  # and return these as a hash.
    end
  rescue Object
    $!.log "TwitterAPI.users"
    {}
  end
  
  private
  
  # returns a configured Twitter::Client object. As Twitter::Client is not
  # threadsafe there is one Twitter::Client per thread. 
  def client #:nodoc:
    Thread.current[:twitter_client] ||= Twitter::Client.new(
      consumer_key:       oauth["consumer_key"],
      consumer_secret:    oauth["consumer_secret"],
      oauth_token:        oauth["access_token"],
      oauth_token_secret: oauth["access_token_secret"]
    )
  end
  
  # returns the oauth configuration for Twitter::Client. 
  def oauth #:nodoc:
    @oauth ||= Bountybase.config.twitter[Bountybase.instance] ||
      begin
        E "Cannot find twitter configuration for", Bountybase.instance
        raise "Cannot find twitter configuration"
      end
  end
end
