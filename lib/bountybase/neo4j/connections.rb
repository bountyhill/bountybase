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
    Connections.create_index_if_needed name
    
    # There must be an even number of remaining arguments.
    expect! args.length.even?

    W "Neo4j.connect", *args, options unless Bountybase.environment == "test"
    
    # The options hash contains options and connections. Connections
    # are Node => Node; options is everything else.
    connections_from_options, options = options.partition { |k,v| k.is_a?(Node) }
    options = Hash[options]

    # == collect all connections to build.

    connections_to_build = args.each_slice(2).to_a        # from arguments...
    connections_to_build.concat connections_from_options  # from options...
    connections_to_build.reject! { |from, to| from == to }
    
    # == build connections, in a batch

    batch = connections_to_build.map do |from, to|
      key, value = "rid", "-#{from.uuid}->#{to.uuid}"
      [:create_unique_relationship, name, key, value, name, from.url, to.url ]
    end
    
    rel_urls = connection.batch(*batch).map do |result| 
      result["body"]["self"] 
    end
              
    unless options.empty?
      batch = rel_urls.map do |rel|
        [:reset_relationship_properties, rel, options]
      end

      connection.batch(*batch)
    end
  end
  
  module Connections #:nodoc:
    # Create a relationship index with a given name if needed.
    def self.create_index_if_needed(name) #:nodoc:
      return if @indices && @indices.include?(name)

      @indices = (Bountybase::Neo4j.connection.list_relationship_indexes || {}).keys
      return if @indices.include?(name)

      Bountybase::Neo4j.connection.create_relationship_index(name)
      @indices << name
    end
  end
end

Bountybase::Neo4j.extend Bountybase::Neo4j::Connections
