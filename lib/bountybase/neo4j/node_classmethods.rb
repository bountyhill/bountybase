module Bountybase::Neo4j
  module Node::ClassMethods
    Neo4j = Bountybase::Neo4j
    
    # creates a node, indexed in the *type* index with the given *uid* and
    # connects it to the root node. It raises an exception if the node cannot
    # be created because it already exists.
    def create(type, uid, attributes = {})
      expect! type => String, uid => [/^\d+$/, Integer]

      create_index_if_needed(type)

      attributes = Base::Attributes.normalize(attributes).
        merge("type" => type, "uid" => uid, "created_at" => Time.now.to_i)
      
      # Add node to index with the given key/value pair
      created_attributes = connection.create_unique_node(type, "uid", uid, attributes)

      # Note: If the node cannot be created because it might violate the unique index, 
      # or Neo4j doesn't like out attributes.
      unless created_attributes
        W "Cannot create object #{type}/#{uid}", attributes
        raise("Cannot create object: #{type}/#{uid}")
      end

      if different_attributes?(created_attributes["data"], attributes)
        raise(DuplicateKeyError, "Object already exists #{type}/#{uid}") 
      end

      Neo4j.build created_attributes
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
        next false if %w(created_at updated_at).include?(k)
        v != expected[k]
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
