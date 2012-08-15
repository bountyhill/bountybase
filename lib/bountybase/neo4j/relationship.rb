module Bountybase::Neo4j
  class Relationship < Base
    # creates a relationship with a given type.
    def self.create(type, source, target, attributes = {})
      expect! type => String, source => [Node], target => [Node], attributes => Hash

      attributes = Graph.normalize_attributes(updates)
      attributes.update "type" => type, "created_at" => Time.now.to_i

      new type, uid, attributes
    end

    def destroy
      implement!
    end
  end
end
