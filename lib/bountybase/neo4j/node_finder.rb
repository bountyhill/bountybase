class Bountybase::Neo4j::Node
  # returns the number of all matching nodes.
  #
  # Parameters: 
  # - +pattern+ the pattern to match
  def self.count(pattern = "*")
    Bountybase::Neo4j.ask("START n=node(#{pattern}) RETURN COUNT(*)") || 0
  end

  # returns all matching nodes.
  #
  # Parameters: 
  # - +pattern+ the pattern to match
  # - +options+ a Hash with these entries:
  #   - +:limit+ the limit 
  def self.all(pattern = "*", options = {})
    query = "START n=node(#{pattern}) RETURN n"
    if limit = options[:limit]
      query += " LIMIT #{limit}"
    end

    Bountybase::Neo4j.raw_query(query).
      map do |node| Neo4j.build node.first end
  end
  
  # finds a node of a given *type* with a given *uid*. 
  # Returns nil if not found.
  def self.find(type, uid)
    expect! type => String, uid => [String, Integer]

    found = Bountybase::Neo4j.connection.get_node_index(type, "uid", uid)
    return unless found
    
    Bountybase::Neo4j.build found.first
  end
end
