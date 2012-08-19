module Bountybase::Neo4j
  class Path
    Neo4j = Bountybase::Neo4j
    
    attr :start, :nodes, :length, :end, :relationships
    
    def initialize(data)
      @data = data

      @start = Neo4j::Node.new(data["start"])
      @end = Neo4j::Node.new(data["end"])
    end
    
    def nodes
      @nodes ||= @data["nodes"].map { |node| Neo4j::Node.new(node) }
    end
    
    def relationships
      @relationships ||= @data["relationships"].map { |rel| Neo4j::Relationship.new(rel) }
    end
    
    def length
      @data["relationships"].length
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
    
    def fetch
      nodes.each(&:attributes)
      relationships.each(&:attributes)
    end
    
    def inspect
      parts = []
      expect! nodes.length => relationships.length + 1

      relationships.each_with_index do |relationship, idx|
        parts << nodes[idx].inspect
        parts << "--[#{relationship.inspect(:without_rid)}]-->"
      end
        
      parts << nodes.last.inspect
      "<#{parts.join(" ")}>"
    end
  end
end
