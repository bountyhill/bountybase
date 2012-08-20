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
      return "<rel##{neo_id}>" unless attributes_loaded?
      
      attrs = self.attributes.map do |key, value| 
        next if key == "rid" || key == "created_at" || key == "updated_at"
        "#{key}: #{value.inspect}" 
      end.compact

      r = "#{type}"
      r += " #{self.rid}" unless without_rid
      r += " {#{attrs.sort.join(", ")}}" unless attrs.empty?
      "<#{r}>"
    end

    def load_neography #:nodoc:
      connection.get_relationship(url)
    end
  end
end
