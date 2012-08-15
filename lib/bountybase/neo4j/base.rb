module Bountybase::Neo4j
  class DuplicateKeyError < RuntimeError; end

  # A base class for Neo4j objects. Derived classes must implement the
  # _save_attributes_ instance method and the _readonly_attribute_names_
  # class method.
  class Base

    module Private #:nodoc:
      private

      # Our attribute hashes should have String keys, no Symbol keys.
      def normalize_attributes(attributes) #:nodoc:
        attributes.inject({}) do |hash, (k,v)|
          v = v.to_i if v.is_a?(Time)
          hash.update k.to_s => v
        end
      end

      # returns the current connection
      def connection #:nodoc:
        Bountybase::Neo4j.connection
      end
    end

    extend Private
    include Private

    attr :url           # Each Neo4j object is identified by an URL, for example "http://localhost:7474/db/data/node/4124".
    attr :attributes    # The object's attributes.

    private


    # Create a Neo4j object.
    #
    # Parameters: 
    #
    # - url: the Neo4j URL.
    # - attributes: the object attributes.
    def initialize(url, attributes)
      @url, @attributes = url, attributes
    end

    public

    # attribute shortcut for the "created_at" attribute.
    def created_at
      attributes["created_at"]
    end

    # attribute shortcut for the "updated_at" attribute.
    def updated_at
      attributes["updated_at"]
    end


    # replaces the object's attributes with the passed in attributes, 
    # with the exception of the read-only attributes, and saves the node.
    def update(updates)
      attributes = normalize_attributes(updates).
        merge(readonly_attributes).
        merge("updated_at" => Time.now.to_i)

      save_attributes(attributes)

      @attributes = attributes
    end

    private

    # returns all values that are readonly. The name of the keys are
    # returned by the readonly_attribute_names class method.
    def readonly_attributes #:nodoc:
      self.class.readonly_attribute_names.inject({}) do |hash, key|
        hash.update key => attributes[key]
      end
    end

    # saves the attributes for this object (identified by its URL)
    # to the database.
    def save_attributes; end
  end

end
