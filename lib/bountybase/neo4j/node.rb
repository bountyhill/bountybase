module Bountybase::Neo4j
  class Node < Base
    # Neo4j = Bountybase::Neo4j
    
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
    def uid; attributes["uid"]; end

    # attribute shortcut for the "type" attribute.
    def type; attributes["type"]; end

    def inspect; "<#{type}##{uid}>"; end
    
    def ==(other)
      other.is_a?(Node) && other.type == self.type && other.uid == self.uid 
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
    Neo4j = Bountybase::Neo4j
    
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

  module Node::ClassMethods
    # returns the number of matching nodes.
    #
    # Parameters: see nodes
    def count(pattern = "*")
      nodes, _ = Neo4j.raw_query("start n=node(#{pattern}) return n")
      nodes.length
    end

    # returns the URLs of all matching nodes.
    #
    # Parameters: 
    # - pattern the pattern to match
    def nodes(pattern = "*")
      nodes, _ = Neo4j.raw_query("start n=node(#{pattern}) return n")
      nodes.map do |node|
        hash = node.first
        hash["self"]
      end
    end

    # purges all nodes and their relationships.
    #
    # Parameters: see nodes
    def purge!(pattern = '*')
      logger.benchmark :error, "purge" do
        nodes(pattern).map do |node|
          connection.delete_node! node
        end
      end
    end
  end
  
  Node.extend Node::ClassMethods
end
