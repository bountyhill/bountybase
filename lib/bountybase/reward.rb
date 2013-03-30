module Bountybase
  def reward(account, options={})
    expect! options => {
      :badge => [ nil, String ]
    }
    
    # Perform the Reward message locally if possible. That means a running
    # worker process is not required in that case.
    if Bountybase::Message::Reward.locally_performable?
      Bountybase::Message.perform "Reward", reward_payload(account, options), {}
    else
      # enqueue reward message when no local database exists. 
      Bountybase::Message::Reward.enqueue reward_payload(account, options)
    end
  end

  private
  
  def reward_payload(account, options={})
    # when run in the context of Bountyhill with a User account, 
    # encode the account as user:<no>
    if defined?(ActiveRecord::Base) && account.is_a?(ActiveRecord::Base)
      expect! account.class.name => [ "User", "Bountybase::Models::User" ]
      options.merge :account => "user:#{account.id}"
    else
      expect! account => /^@.*/
      options.merge :account => account
    end
  end
end
