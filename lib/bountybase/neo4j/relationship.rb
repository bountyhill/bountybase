module Bountybase::Neo4j
  class Relationship < Base
    # creates a relationship with a given type.
    def self.create(type, source, target, attributes = {})
      expect! type => String, source => [Node], target => [Node], attributes => Hash

      attributes = Graph.Base::Attributes.normalize(updates)
      attributes.update "type" => type, "created_at" => Time.now.to_i

      new type, uid, attributes
    end

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
        # next if key == "type" || key == "uid" || key == "rid"
        next if key == "rid"
        "#{key}: #{value.inspect}" 
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
