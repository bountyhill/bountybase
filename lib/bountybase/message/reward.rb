# A Bountybase::Message::Reward message is sent whenever a specific reward 
# is to be assigned to a specific user.
#
# The message contains the receiving account or identity - either "@<id>" 
# or "user:<id>", the badge, if any, and the number of points.
#
class Bountybase::Message::Reward < Bountybase::Message
  def perform
    return unless account = Bountybase::User[payload[:account]]
    
    if badge = payload[:badge]
      account.badges << badge unless account.badges.include?(badge)
    end
    
    if payload[:points]
      account.points += payload[:points] 
    end
    
    account.save!
  end

  private
  
  def self.validate!(payload)
    expect! payload => {  :account => /^(@|user:)./,
                          :badge => [String, nil],
                          :points => [Integer,nil] }
  end
end
