module Bountybase::Neo4j::Connections
  Neo4j = Bountybase::Neo4j
  
  # Connect two nodes with a relationship. Examples:
  # 
  # This builds two named, directed connections
  #   Bountybase::Neo4j.connect "name", node1 => node2, node3 => node4, :attr => :value
  # This builds two unnamed, directed connections
  #   Bountybase::Neo4j.connect node1 => node2, node3 => node4, :attr => :value
  # This builds two unnamed connection
  #   Bountybase::Neo4j.connect node1, node2, node1 => node3, :attr => :value
  def connect(*args)
    options = args.pop if args.last.is_a?(Hash)
    name = args.first.is_a?(String) ? args.shift : "connects"
    
    # There must be a odd number of remaining arguments.
    expect! args.length.even?

    # get connections and options
    connections, options = options.partition { |k,v| k.is_a?(Neo4j::Node) }
    options = Hash[options]

    # build connections from args
    args.each_slice(2).each do |from, to|
      Neo4j::Connections.build name, from, to, options
    end

    # build connections from options hash
    connections.each do |from, to|
      Neo4j::Connections.build name, from, to, options
    end
  end
  
  def self.build(name, from, to, options)
    expect! name => String, from => Neo4j::Node, to => Neo4j::Node, options => Hash
    Neo4j.connection.create_relationship(name, from.url, to.url, options)
  end
end

Bountybase::Neo4j.extend Bountybase::Neo4j::Connections
