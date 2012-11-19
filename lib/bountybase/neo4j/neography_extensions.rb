class Neography::Rest
  # The ping method tries to contact the Neo4j server and verifies the expected result.
  def ping
    connection.ping
  end
end

class Neography::Connection
  alias :url :configuration

  def ping
    ping = evaluate_response HTTParty.get(url,  merge_options({}))
    return ping if ping.is_a?(Hash)

    Bountybase.logger.error "Cannot ping neo4j database at #{url}" 
    {}
  end
end

