class Bountybase::Neo4j::Base
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

  # attribute shortcut for the +created_at+ attribute. Returns a Time object or +nil+.
  def created_at
    if created_at = attributes["created_at"]
      Time.at(created_at)
    end
  end

  # attribute shortcut for the +updated_at+ attribute. Returns a Time object or +nil+.
  def updated_at
    if updated_at = attributes["updated_at"]
      Time.at(updated_at)
    else
      created_at
    end
  end

  # returns the uuid, which consists of type and uid.
  def uuid
    "#{type}/#{uid}"
  end

  # returns the Neo4j internal object id.
  def neo_id
    url.split("/").last
  end

  # returns the attributes hash for this object, fetching it from the
  # connection when needed.
  def attributes
    neography["data"]
  end

  # shortcut to fetch a single attribute.
  #
  #    node = Node.find("twitter_identities", 12)
  #    node["screen_name"]
  def [](name)
    attributes[name.to_s]
  end

  # shortcut to update a single attribute, resaving the node.
  #
  #    node = Node.find("twitter_identities", 12)
  #    node["screen_name"] = "foobarbazie"
  def []=(name, value)
    update_attributes(name.to_s => value)
  end
  
  # Names of those attributes that may not be set by the code, because
  # it is managed by the Neo4j::Base object itself.
  READONLY_ATTRIBUTE_NAMES = %w(type uid created_at updated_at)

  # replaces the object's attributes with the passed in attributes, 
  # with the exception of the READONLY_ATTRIBUTE_NAMES,, and save 
  # the node.
  #
  # Note that this removes all attributes that are not passed in
  # in the +updates+ parameter.
  def update(updates)
    expect! updates => Hash
    
    readonly_attributes = {}
    READONLY_ATTRIBUTE_NAMES.each do |name|
      next unless attributes.key?(name)
      readonly_attributes[name] = attributes[name]
    end

    attributes = Bountybase::Neo4j::Base.normalize_attributes(updates).
      merge(readonly_attributes).
      merge("updated_at" => Time.now.to_i)

    save_attributes(attributes)

    if @neography
      @neography["data"] = attributes
    end
  end

  # Update all attributes that are passed in. Keep previously set 
  # attributes, that are not passed in.
  def update_attributes(updates)
    update attributes.update(updates)
  end

  # normalize the attribute hash
  def self.normalize_attributes(attributes)
    expect! attributes => Hash
    
    normalized = {}
    attributes.each do |k,v|
      case v
      when Time then normalized[k.to_s] = v.to_i
      when nil  then :nop
      else      normalized[k.to_s] = v
      end
    end
    normalized
  end
end
