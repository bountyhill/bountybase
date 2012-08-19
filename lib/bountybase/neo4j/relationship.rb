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
    
    def inspect(without_rid = false) #:nodoc:
      return super() unless attributes_loaded?

      inspected_attributes = attributes.map do |key, value| 
        "#{key}: #{value.inspect}" unless key == "rid"
      end

      rid = " #{self.rid}" unless without_rid
      attrs = inspected_attributes.compact.sort.join(", ") unless inspected_attributes.empty?

      "<rel##{neo_id}:#{type}#{rid}#{attrs}>"
    end

    def load_neography #:nodoc:
      connection.get_relationship(url)
    end
  end
end
