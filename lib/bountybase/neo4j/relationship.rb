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

    def to_s #:nodoc:
      if fetched?
        "-[:#{type}]->"
      else
        "rel:#{neo_id}"
      end
    end
    
    def inspect #:nodoc:
      return "<rel:#{neo_id}>" unless fetched?

      attrs = self.attributes.map do |key, value| 
        next if key == "rid" || key == "created_at" || key == "updated_at"
        "#{key}: #{value.inspect}" 
      end.compact

      r = "#{start_node} -[:#{type}]-> #{end_node}"
      r += " {#{attrs.sort.join(", ")}}" unless attrs.empty?
      "<#{r}>"
    end

    def load_neography #:nodoc:
      Neo4j.connection.get_relationship(url)
    end
    
    def self.all(pattern = '*')
      pattern = pattern.to_s
      
      all = Neo4j.query <<-CYPHER
        START r=relationship(*)
        RETURN r
      CYPHER

      if pattern != '*'
        all.reject! { |relationship| relationship.type != pattern }
      end
      
      all
    end

    # count relationships matching a pattern
    def self.count(pattern = '*')
      all(pattern).length
    end
  end
end
