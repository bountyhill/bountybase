class Bountybase::Neo4j::Node
  # create a node, indexed in the *type* index with the given *uid*. 
  # If the node exists with identical attributes it returns just this
  # node.
  #
  # Returns the a Neo4j::Node object, or raises a DuplicateKeyError 
  # exception otherwise.
  def self.create(type, uid, attributes = {})
    expect! type => String, uid => [/^\d+$/, Integer]

    create_index_if_needed(type)

    attributes = Bountybase::Neo4j::Base.normalize_attributes(attributes).
      merge("type" => type, "uid" => uid, "created_at" => Time.now.to_i)
    
    # Add node to index with the given key/value pair
    created_attributes = Bountybase::Neo4j.connection.create_unique_node(type, "uid", uid, attributes)

    # Note: If the node cannot be created because it might violate the unique index, 
    # or Neo4j doesn't like out attributes.
    unless created_attributes
      W "Cannot create object #{type}/#{uid}", attributes
      raise("Cannot create object: #{type}/#{uid}")
    end

    if attributes_differ?(created_attributes["data"], attributes)
      raise(Neo4j::DuplicateKeyError, "Object already exists #{type}/#{uid}") 
    end

    Neo4j.build created_attributes
  end

  # destroy a node.
  def self.destroy(type, uid)
    expect! type => String, uid => [String, Integer]

    if node = find(type, uid)
      node.destroy
    end
  end
  
  def self.create_index_if_needed(name) #:nodoc:
    return if @indices && @indices.include?(name)
    
    @indices = (Bountybase::Neo4j.connection.list_node_indexes || {}).keys
    return if @indices.include?(name)

    Bountybase::Neo4j.connection.create_node_index(name)
    @indices << name
  end
  
  # returns true if actual and expected only differ in "created_at" or
  # "updated_at".
  def self.attributes_differ?(actual, expected) #:nodoc:
    actual.any? do |k,v|
      next false if %w(created_at updated_at).include?(k)
      v != expected[k]
    end
  end
end
