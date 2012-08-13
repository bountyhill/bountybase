class Neography::Rest
  # The ping method tries to contact the Neo4j server and verifies the expected result.
  def ping
    url = @protocol + @server + ':' + @port.to_s + @directory
    ping = evaluate_response HTTParty.get(url, @authentication.merge(@parser))
    
    unless ping.is_a?(Hash) && ping.keys.include?("data")
      Bountybase.logger.error "Cannot ping neo4j database at #{url}" 
      {}
    else
      ping
    end
  end

  def delete_node_index(name)
    delete("/index/node/#{name}")
  end
end

