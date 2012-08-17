module Bountybase::Neo4j
  module Base::Attributes
    # Returns the uid attribute. The uid attribute is assigned by the user
    # during object creation. It cannot be derived from the url; consequently
    # it might have to be read from the Neo4j database.
    def uid
      attributes["uid"]
    end

    # Returns the type attribute. The type attribute is assigned by the user
    # during object creation. It cannot be derived from the url; consequently
    # it might have to be read from the Neo4j database.
    def type
      attributes["type"]
    end

    # attribute shortcut for the "created_at" attribute.
    def created_at
      if created_at = attributes["created_at"]
        Time.at(created_at)
      end
    end

    # attribute shortcut for the "updated_at" attribute.
    def updated_at
      if updated_at = attributes["updated_at"]
        Time.at(updated_at)
      end
    end

    # returns the uuid, which consists of type and uid.
    def uuid
      "#{type}/#{uid}"
    end

    # returns true if attributes are loaded.
    def attributes_loaded?
      !@neography.nil?
    end

    # returns the attributes hash for this object, fetching it from the
    # connection when needed.
    def attributes
      neography["data"]
    end

    READONLY_ATTRIBUTE_NAMES = %w(type uid created_at)

    # replaces the object's attributes with the passed in attributes, with the
    # exception of the readonly attributes, and saves the node.
    def update(updates)
      readonly_attributes = {}
      READONLY_ATTRIBUTE_NAMES.each do |name|
        next unless attributes.key?(name)
        readonly_attributes[name] = attributes[name]
      end

      attributes = Base::Attributes.normalize(updates).
        merge(readonly_attributes).
        merge("updated_at" => Time.now.to_i)

      save_attributes(attributes)

      if @neography
        @neography["data"] = attributes
      end
    end

    def inspect #:nodoc:
      kind, neo_id = *url.split("/")[-2..-1]

      if attributes_loaded?
        attributes = self.attributes.dup
        type, uid = attributes.delete("type"), attributes.delete("uid")
        inspected_attributes = attributes.map { |key, value| "#{key}: #{value.inspect}" }

        "<#{kind}##{neo_id}: #{type}##{uid} #{inspected_attributes.sort.join(", ")}>"
      else
        "<#{kind}##{neo_id}>"
      end
    end

    def self.normalize(attributes)
      expect! attributes => Hash
      normalized = {}
      attributes.each do |k,v|
        case v
        when Time then normalized[k.to_s] = v.to_i
        else      normalized[k.to_s] = v
        end
      end
      normalized
    end
  end

  class Base
    include Attributes
  end
end
