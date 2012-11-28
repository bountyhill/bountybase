# A Bountybase::Message::Reward message is sent whenever a specific reward 
# is to be assigned to a specific user.
#
# The message contains the receiving account or identity - either "@<id>" 
# or "user:<id>", the badge, if any, and the number of points.
#
class Bountybase::Message::Reward < Bountybase::Message
  def perform
    require "bountybase/models"
    
    return unless account = Bountybase::Models::User[payload[:account]]
    
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

  # If there is a AR::B connection, the Reward action can be performed
  # in this process and need not be queued.
  def self.locally_performable?
    defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?
  end
end
