# A module to manage connections between nodes.
module Bountybase::Neo4j
  
  # Connect two or more nodes with relationship(s). 
  # 
  #   # build two named connections, passing in some attributes
  #   Bountybase::Neo4j.connect "name", node1 => node2, node3 => node4, "foo" => "bar"
  #
  #   # build two unnamed connections, w/some attributes
  #   Bountybase::Neo4j.connect node1 => node2, node3 => node4, :foo => "bar"
  #
  #   # build two unnamed connection
  #   Bountybase::Neo4j.connect node1, node2, node1 => node3
  #
  def self.connect(*args)
    options = {}
    while args.last.is_a?(Hash)
      options.update args.pop
    end

    name = args.first.is_a?(String) ? args.shift : "connects"
    
    # There must be a odd number of remaining arguments.
    expect! args.length.even?

    # get connections and options
    connections, options = options.partition { |k,v| k.is_a?(Node) }
    options = Hash[options]

    # build connections from args
    args.each_slice(2).each do |from, to|
      Connections.build name, from, to, options
    end

    # build connections from options hash
    connections.each do |from, to|
      Connections.build name, from, to, options
    end
  end
  
  module Connections #:nodoc:
    
    # Build a connection
    def self.build(name, from, to, options) #:nodoc:
      expect! name => String, from => Node, to => Node, options => Hash

      return if from == to

      index, key, value = "#{name}", "rid", "-#{from.uuid}->#{to.uuid}"
      create_index_if_needed index

      rel = Bountybase::Neo4j.connection.create_unique_relationship(index, key, value, name, from.url, to.url)
      Bountybase::Neo4j.connection.reset_relationship_properties(rel, options) unless options.empty?
      rel
    end

    # Create a relationship index with a given name if needed.
    def self.create_index_if_needed(name) #:nodoc:
      return if @indices && @indices.include?(name)

      @indices = (Bountybase::Neo4j.connection.list_relationship_indexes || {}).keys
      return if @indices.include?(name)

      Neo4j.connection.create_relationship_index(name)
      @indices << name
    end
  end
end

Bountybase::Neo4j.extend Bountybase::Neo4j::Connections
