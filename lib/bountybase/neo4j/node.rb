module Bountybase::Neo4j
  class Node < Base
    # Delete this node.
    #
    # Note: To delete a large number of nodes, use the Neo4j.purge method instead.
    def destroy
      Bountybase::Neo4j.connection.delete_node!(url)
      true
    rescue Neography::NodeNotFoundException
      false
    end

    def to_s #:nodoc:
      if fetched?
        "#{type}/#{uid}"
      else
        "node:#{neo_id}"
      end
    end
    
    def inspect #:nodoc:
      return "<node:#{neo_id}>" unless fetched?
      
      attrs = self.attributes.map do |key, value| 
        next if %w(type uid created_at updated_at).include?(key)
        "#{key}: #{value.inspect}" 
      end.compact

      r = "#{type}/#{uid}"
      r += " {#{attrs.sort.join(", ")}}" unless attrs.empty?
      "<#{r}>"
    end
    
    private
    
    def load_neography #:nodoc:
      Bountybase::Neo4j.connection.get_node(url)
    end

    def save_attributes(attributes) #:nodoc:
      Bountybase::Neo4j.connection.reset_node_properties(url, attributes)
      
      expect! do
        r = Bountybase::Neo4j.connection.get_node(url)
        attributes == r["data"]
      end
    end
  end
end
