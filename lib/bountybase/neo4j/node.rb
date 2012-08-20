module Bountybase::Neo4j
  class Node < Base
    def destroy
      connection.delete_node!(url)
    end

    def inspect #:nodoc:
      return "<node##{neo_id}>" unless attributes_loaded?
      
      attrs = self.attributes.map do |key, value| 
        next if %w(type uid created_at updated_at).include?(key)
        "#{key}: #{value.inspect}" 
      end.compact

      r = "#{type}##{uid}"
      r += " {#{attrs.sort.join(", ")}}" unless attrs.empty?
      "<#{r}>"
    end
    
    private
    
    def load_neography #:nodoc:
      connection.get_node(url)
    end

    def save_attributes(attributes) #:nodoc:
      connection.reset_node_properties(url, attributes)
      
      expect! do
        r = connection.get_node(url)
        attributes == r["data"]
      end
    end
  end
end
