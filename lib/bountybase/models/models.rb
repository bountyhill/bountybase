# A twitter identity.
class Bountybase::Models::Identity < ActiveRecord::Base
  belongs_to :user, :class_name => "Bountybase::Models::User"

  # Diable STI even though we have a type column.
  def self.inheritance_column
    nil
  end
  
  # Find or creates a twitter identity by its screen name.
  def self.find_or_create_by_screen_name(screen_name)
    expect! screen_name => /^[^@]/
    
    where(:email => screen_name).includes(:user).first || create_by_screen_name(screen_name)
  end

  # Creates a twitter identity by its screen name. This method creates
  # only Twitter identities, AND sets the type of newly created record
  # to "Identity::Twitter".
  #
  # The STI lookup works in Bountyhill, but currently not in Bountybase
  # (and is not needed here.)
  def self.create_by_screen_name(screen_name)
    create! :type => "Identity::Twitter", :email => screen_name, :user => Bountybase::Models::User.new
  end
end

# A Bountyhill user account.
class Bountybase::Models::User < ActiveRecord::Base
  serialize :badges, Array
  
  # List of shared quests
  has_and_belongs_to_many :shared_quests, :class_name => "Bountybase::Models::Quest", 
    :join_table => :users_quests_sharings,
    :uniq => true
    
  def self.[](account_uri)
    case account_uri
    when /^@(.+)$/      then Bountybase::Models::Identity.find_or_create_by_screen_name($1).user
    when /^user:(\d+)$/ then find_by_id($1)
    else                raise "Invalid account name #{account_uri.inspect}"
    end
  end
  
  def register_quest_id(quest_id)
    # Why SQL? Why not just self.shared_quests << Quest.find(quest_id)? 
    # It turns out that with an unique index on [quest_id, user_id] Rails
    # raises a uniqeness violation exception - which is correct, btw. -
    # which then aborts Postgresql's current transaction, which results
    # in a number of nasty things. So: SQL to the rescue.
    ActiveRecord::Base.connection.execute <<-SQL
      INSERT INTO users_quests_sharings(quest_id, user_id)
      SELECT #{quest_id}, #{self.id} 
      WHERE EXISTS (SELECT 1 FROM quests WHERE quests.id = #{quest_id}) AND 
        NOT EXISTS (SELECT 1 FROM users_quests_sharings WHERE (quest_id, user_id)=(#{quest_id}, #{self.id}))
    SQL
  end
  
  def register_quest_ids(quest_ids)
    quest_ids.each { |quest_id| register_quest_id(quest_id) }
  end
end

class Bountybase::Models::Quest < ActiveRecord::Base
end
