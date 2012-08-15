require 'neography'
require_relative "neo4j_base"

module Bountybase::Graph::Neo4j
  def self.normalize_attributes(attributes)
    attributes.inject({}) do |hash, (k,v)|
      v = v.to_i if v.is_a?(Time)
      hash.update k.to_s => v
    end
  end

  def self.root_node
  end

  # runs a cypher query
  def self.cypher(query)
  end

  class Node
    # creates a node, indexed in the *type* index with the given *uid* and
    # connects it to the root node. It raises an exception if the node cannot
    # be created because it already exists.
    def self.create(type, uid, attributes = {})
      expect! type => String, uid => [String, Integer]

      attributes = Graph.normalize_attributes(attributes)
      attributes.merge("type" => type, "uid" => uid, "created_at" => Time.now.to_i)

      new type, uid, attributes
    end

    # finds a node of a given *type* with a given *uid*. Returns nil if not found.
    def self.find(type, uid)
      expect! type => String, uid => [String, Integer]

      new type, uid, attributes or nil  #, attributes
    end

    # destroys a node.
    def self.destroy(type, uid)
      expect! type => String, uid => [String, Integer]

      if node = find(type, uid)
        node.destroy
      end
    end

    attr :type, :uid

    private

    def initialize(type, uid, attributes)
      @type, @uid, @attributes = type, uid, attributes
    end

    public

    def attributes
      @attributes ||= fetch_attributes
    end

    # destroys a node.
    def destroy
      implement!
    end

    # replaces the node attributes with the passed in attributes, with the exception 
    # of its read-only attributes, and saves the node.
    def update(updates)
      attributes = Graph.normalize_attributes(updates).
        merge(readonly_attributes).
        merge("updated_at" => Time.now.to_i)

      implement!

      @attributes = attributes
    end

    private

    # read-only node attributes include *type*, *uid*, *created_at*. These are 
    # set during node creation and cannot be changed during a node's lifetime.
    READONLY_ATTRIBUTES = %w(type uid created_at)

    def readonly_attributes #:nodoc:
      READONLY_ATTRIBUTES.inject({}) do |hash, attr|
        hash.update key => attributes[ke]
      end
    end

    def fetch_attributes
      implement!
    end
  end

  class Relationship
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