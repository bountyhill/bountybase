module Bountybase::Neo4j
  module Node::Finder
    Neo4j = Bountybase::Neo4j
    
    # returns the number of matching nodes.
    #
    # Parameters: see nodes
    def count(pattern = "*", options = {})
      query = "START n=node(#{pattern}) RETURN n"
      if limit = options[:limit]
        query += " LIMIT #{limit}"
      end

      nodes, _ = Neo4j.raw_query(query)
      nodes.length
    end

    # returns all matching nodes.
    #
    # Parameters: 
    # - pattern the pattern to match
    def all(pattern = "*", options = {})
      query = "START n=node(#{pattern}) RETURN n"
      if limit = options[:limit]
        query += " LIMIT #{limit}"
      end

      nodes, _ = Neo4j.raw_query(query)
      nodes.map do |node|
        Neo4j::Base.build node.first
      end
    end
    
    # finds a node of a given *type* with a given *uid*. Returns nil if not found.
    def find(type, uid)
      expect! type => String, uid => [String, Integer]

      found = connection.get_node_index(type, "uid", uid)
      return unless found
      
      Base.build found.first
    end
  end
  
  Node.extend Node::Finder
end
