require "active_record"

# The Bountybase::Models namespoace contains a trimmed down version
# of Bountyhill's models - just enough to record rewards and such.
module Bountybase::Models

  # set up a connection to the ActiveRecord database
  def self.setup
    @setup_active_record ||= begin
      config_path = File.join(File.dirname(__FILE__), "../../config/database.yml")
      config = config_path && YAML.load_file(config_path)
      connection = config["test"] || raise("Please add database.yml at #{config}")
      ActiveRecord::Base.establish_connection(connection)
      true
    end
  end
  
  # Delete all Bountybase objects; this is needed during tests only. 
  def self.delete_all #:nodoc:
    db = ActiveRecord::Base.connection

    db.execute "DELETE FROM users_quests_sharings"
    db.execute "DELETE FROM users"
    db.execute "DELETE FROM identities"
    db.execute "DELETE FROM quests"
  end
end

Bountybase::Models.setup

require_relative "models/models"