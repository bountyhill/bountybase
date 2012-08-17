desc "Run a performance check"
task :performance do
  require_relative "../../bountybase"
  Bountybase.setup
  Performance.run
end

module Performance
  extend self
  
  def run
    build_graph :count => 70, :factors => [2,3,5]
    
    W "count_paths", count_paths(1, 2)
    W "count_paths", count_paths(1, 4)
    W "count_paths", count_paths(1, 6)
    W "count_paths", count_paths(1, 72)
    
    W "count_paths", count_paths(1, 2*3*5)
    W "count_paths", count_paths(1, 2*2*3*5)

    Bountybase::Neo4j.purge!
  end
  
  def build_graph(options)
    count, factors = *options.values_at(:count, :factors)
    expect! count => Integer, factors => Array
  
    nodes = Bountybase.logger.benchmark :warn, "Creating #{count} nodes" do
      (0...count).map do |i|
        Bountybase::Neo4j::Node.create "foo", i
      end
    end

    Bountybase.logger.benchmark :warn, "Connecting nodes" do |benchmark|
      connections = 0

      # connect each node to its 2x node

      factors.each do |factor|
        nodes.each_with_index do |node, idx|
          next if idx == 0
          target = nodes[idx * factor]
          next unless target

          Bountybase::Neo4j.connect node => target
          connections += 1
        end
      end

      benchmark.message += " (#{connections} connections)"
    end
  end
  
  def count_paths(from, to)
    find_paths(from, to).length
  end
  
  def find_paths(from, to)
    Bountybase.logger.benchmark :warn, "path #{from} => #{to}", :min => 0 do |benchmark|
      query = <<-CYPHER
        START src=node:foo(uid='#{from}'), target=node:foo(uid='#{to}')
        MATCH path = src-[*]->target 
        RETURN path
        CYPHER
      
      results = Bountybase::Neo4j.query(query)
      benchmark.message += " #{results.length} results"
      results
    end
  end
end