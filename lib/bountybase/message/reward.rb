# A Bountybase::Message::Reward message is sent whenever a specific reward 
# is to be assigned to a specific user.
#
# The message contains the receiving account or identity - either "twitter:<id>" 
# or "user:<id>", the badge, if any, and the number of points.
#
class Bountybase::Message::Reward < Bountybase::Message

  def perform
    return unless account
    
    if badge = payload[:badge]
      account.badges << badge unless account.badges.include?(badge)
    end
    
    if payload[:points]
      account.points += payload[:points] 
    end
    
    account.save!
  end

  private
  
  def account
    @account ||= self.class.account(payload[:account])
  end
  
  def self.account(account_uri)
    case account_uri
    when /^twitter:(.+)$/ then Bountybase::Identity.find_or_create_by_screen_name($1).user
    when /^user:(\d+)$/   then Bountybase::User.find_by_id($1)
    else                  raise "Invalid account name #{account_uri}"
    end
  end
  
  def self.validate!(payload)
    expect! payload => {  :account => /^(twitter|user):./,
                          :badge => [String, nil],
                          :points => [Integer,nil] }
  end
end
