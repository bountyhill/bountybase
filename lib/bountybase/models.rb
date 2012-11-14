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
