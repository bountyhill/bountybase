# This is a trimmed down version of Bountyhill's models.
# It should be enough to record rewards.

require "active_record"

class Bountybase::Identity < ActiveRecord::Base
  belongs_to :user, :class_name => "Bountybase::User"

  def self.inheritance_column
    nil
  end
  
  def self.find_or_create_by_screen_name(screen_name)
    expect! screen_name => /^[^@]/
    
    where(:email => screen_name).includes(:user).first || create_by_screen_name(screen_name)
  end

  def self.create_by_screen_name(screen_name)
    create! :type => "Identity::Twitter", :email => screen_name, :user => Bountybase::User.new
  end
end

class Bountybase::User < ActiveRecord::Base
  serialize :badges, Array
  
  has_and_belongs_to_many :shared_quests, :class_name => "Bountybase::Quest", 
    :join_table => :users_quests_sharings,
    :uniq => true
    
  def self.[](account_uri)
    case account_uri
    when /^@(.+)$/      then Bountybase::Identity.find_or_create_by_screen_name($1).user
    when /^user:(\d+)$/ then find_by_id($1)
    else                raise "Invalid account name #{account_uri.inspect}"
    end
  end
  
  def self.delete_all
    super
    connection.execute "DELETE FROM users_quests_sharings"
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

class Bountybase::Quest < ActiveRecord::Base
  def self.delete_all
    super
    connection.execute "DELETE FROM users_quests_sharings"
  end
end

# -- set up connection to ActiveRecord database -----------------------

module Bountybase
  def setup_active_record
    @setup_active_record ||= begin
      config_path = File.join(File.dirname(__FILE__), "../../config/database.yml")
      config = config_path && YAML.load_file(config_path)
      connection = config["test"] || raise("Please add database.yml at #{config}")
      ActiveRecord::Base.establish_connection(connection)
    end
  end
end

Bountybase.setup_active_record
