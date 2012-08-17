module Bountybase::Neo4j
  class Path
    Neo4j = Bountybase::Neo4j
    
    attr :start, :nodes, :length, :end, :relationships
    
    def initialize(hash)
      @start = Neo4j::Node.new(hash["start"])
      @nodes = hash["nodes"].map { |node| Neo4j::Node.new(node) }
      @relationships = hash["relationships"]
      @end = Neo4j::Node.new(hash["end"])
    end

    def length
      @relationships.length
    end
    
    def members
      @members ||= [].tap do |members|
        expect! nodes.length => relationships.length + 1

        relationships.each_with_index do |relationship, idx|
          members << nodes[idx]
          members << relationship
        end
        
        members << nodes.last
      end
    end
    
    def inspect
      parts = []
      expect! nodes.length => relationships.length + 1

      relationships.each_with_index do |relationship, idx|
        parts << nodes[idx].neo_id

        # relationship_neo_id = relationship.neo_id
        relationship_neo_id = relationship.split("/").last
        
        parts << "--[#{relationship_neo_id}]-->"
      end
        
      parts << nodes.last.neo_id

      "<#{parts.join(" ")}>"
    end
  end
end
