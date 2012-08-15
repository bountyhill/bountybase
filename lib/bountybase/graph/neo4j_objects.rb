require 'neography'
require_relative "neo4j_base"
require "forwardable"

module Bountybase::Graph::Neo4j
  class DuplicateKeyError < RuntimeError; end
  
  # def self.root_node
  # end

  # # runs a cypher query
  # def self.cypher(query)
  # end

  # Our attribute hashes should have String keys, no Symbol keys.
  def self.normalize_attributes(attributes)
    attributes.inject({}) do |hash, (k,v)|
      v = v.to_i if v.is_a?(Time)
      hash.update k.to_s => v
    end
  end
  
  # A base class for Neo4j objects. Derived classes must implement the
  # _save_attributes_ instance method and the _readonly_attribute_names_
  # class method.
  class Base
    
    attr :url           # Each Neo4j object is identified by an URL, for example "http://localhost:7474/db/data/node/4124".
    attr :attributes    # The object's attributes.

    private
    
    extend Forwardable
    delegate :normalize_attributes => Bountybase::Graph::Neo4j
    delegate :connection => Bountybase::Graph::Neo4j
    
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
  
  class Node < Base
    attr :type, :uid

    private

    def initialize(type, uid, neography_attributes)
      expect! type => String, uid => [Integer, String], neography_attributes => Hash
      
      @type, @uid = type, uid
      super *neography_attributes.values_at("self", "data")
    end

    public

    # destroy the node and all its relationships.
    def destroy
      connection.delete_node!(url)
    end

    # attribute shortcut for the "uid" attribute.
    def uid
      attributes["uid"]
    end
    
    private

    # read-only node attributes include *type*, *uid*, *created_at*. These are 
    # set during node creation and cannot be changed during a node's lifetime.
    def self.readonly_attribute_names
      %w(type uid created_at)
    end

    def save_attributes(attributes) #:nodoc:
      connection.reset_node_properties(url, attributes)
      
      expect! do
        r = connection.get_node(url)
        attributes == r["data"]
      end
    end
  end

  module Node::ClassMethods
    # creates a node, indexed in the *type* index with the given *uid* and
    # connects it to the root node. It raises an exception if the node cannot
    # be created because it already exists.
    def create(type, uid, attributes = {})
      expect! type => String, uid => [String, Integer]

      create_index_if_needed(type)

      attributes = normalize_attributes(attributes).
        merge("type" => type, "uid" => uid, "created_at" => Time.now.to_i)
      
      # Add node to index with the given key/value pair
      created_attributes = connection.create_unique_node(type, "uid", uid, attributes)

      # Note: If the node cannot be created because it violates the unique index, the
      # 'create_unique_node' function returns the currently existing node.
      if !created_attributes
        raise("Object cannot be created: #{uid}")
      end
      
      if different_attributes?(created_attributes["data"], attributes)
        raise(DuplicateKeyError, "Object already exists #{uid}") 
      end

      new type, uid, created_attributes
    end
    
    private
    
    extend Forwardable
    delegate :connection => Bountybase::Graph::Neo4j
    delegate :normalize_attributes => Bountybase::Graph::Neo4j
    
    def create_index_if_needed(name)
      return if @indices && @indices.include?(name)
      
      @indices = connection.list_node_indexes.keys
      return if @indices.include?(name)

      connection.create_node_index(name)
      @indices << name
    end
    
    # returns true if actual and expected only differ in "created_at" or
    # "updated_at".
    def different_attributes?(actual, expected) #:nodoc:
      actual.any? do |k,v|
        (v != expected[k]) &&
        (k != "created_at") &&
        (k != "updated_at")
      end
      
    end

    public
    
    # finds a node of a given *type* with a given *uid*. Returns nil if not found.
    def find(type, uid)
      expect! type => String, uid => [String, Integer]

      found = connection.get_node_index(type, "uid", uid)
      return unless found
      
      new type, uid, found.first
    end

    # destroys a node.
    def destroy(type, uid)
      expect! type => String, uid => [String, Integer]

      if node = find(type, uid)
        node.destroy
      end
    end
  end
  Node.extend Node::ClassMethods


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