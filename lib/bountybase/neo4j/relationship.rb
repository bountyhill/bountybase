module Bountybase::Neo4j
  class Relationship < Base
    def destroy
      implement!
    end

    def rid
      attributes["rid"]
    end
    
    def type
      neography["type"]
    end
    
    def start_node
      @start_node ||= Neo4j.build neography["start"]
    end
    
    def end_node
      @end_node ||= Neo4j.build neography["end"]
    end

    def fetch
      start_node.fetch
      end_node.fetch

      super
    end

    def insp #:nodoc:
      r = if attributes_loaded?
        type
      else
        "rel:#{neo_id}"
      end

      "-[:#{type}]->"
    end
    
    def inspect #:nodoc:
      return "<rel:#{neo_id}>" unless attributes_loaded?

      attrs = self.attributes.map do |key, value| 
        next if key == "rid" || key == "created_at" || key == "updated_at"
        "#{key}: #{value.inspect}" 
      end.compact

      r = "#{start_node.insp} -[:#{type}]-> #{end_node.insp}"
      r += " {#{attrs.sort.join(", ")}}" unless attrs.empty?
      "<#{r}>"
    end

    def load_neography #:nodoc:
      connection.get_relationship(url)
    end
    
    def self.all(type = nil)
      all = Neo4j.query <<-CYPHER
        START r=relationship(*)
        RETURN r
      CYPHER

      if type
        type = type.to_s
        all.reject! { |relationship| relationship.type != type }
      end
      
      all
    end
  end
end
