require "active_record"

# The Bountybase::Models namespoace contains a trimmed down version
# of Bountyhill's models - just enough to record rewards and such.
module Bountybase::Models
  extend self
  
  private
  
  def config_from_database_yml
    config_path = File.join(File.dirname(__FILE__), "../../config/database.yml")
    config = YAML.load_file(config_path)
    config["test"] or raise("Missing 'test' entry in database.yml file.")
  end

  def database_url
    ENV["DATABASE_URL"] || Bountybase.config.database || raise("Missing database config.yml entry")
  end
  
  def config
    if Bountybase.environment == "test"
      config_from_database_yml
    else
      uri = URI.parse(database_url)
      { 
        adapter: "postgresql", database: uri.path.gsub(/^\/+/, ""),
        username: uri.user, password: uri.password, host: uri.host, port: uri.port
      }
    end
  end
  
  # set up a connection to the ActiveRecord database
  def self.setup
    @setup_active_record ||= begin
      ActiveRecord::Base.establish_connection(config)
      user, host, port, database = config.values_at(:user, :host, :port, :database)

      Bountybase.logger.benchmark :warn, "Connecting to postgres at", "#{user}@#{host}:#{port}", :min => 0 do
        ActiveRecord::Base.connection.execute "SELECT 1"
      end

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