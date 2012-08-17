module Bountybase::Neo4j
  module Node::ClassMethods
    Neo4j = Bountybase::Neo4j
    
    # creates a node, indexed in the *type* index with the given *uid* and
    # connects it to the root node. It raises an exception if the node cannot
    # be created because it already exists.
    def create(type, uid, attributes = {})
      expect! type => String, uid => [String, Integer]

      create_index_if_needed(type)

      attributes = Base::Attributes.normalize(attributes).
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

      Base.build created_attributes
    end
    
    private
    
    def create_index_if_needed(name)
      return if @indices && @indices.include?(name)
      
      @indices = (connection.list_node_indexes || {}).keys
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
    
    # destroys a node.
    def destroy(type, uid)
      expect! type => String, uid => [String, Integer]

      if node = find(type, uid)
        node.destroy
      end
    end
  end

  Node.extend Node::ClassMethods
end
