module Bountybase::Neo4j
  class Node < Base
    def destroy
      connection.delete_node!(url)
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
