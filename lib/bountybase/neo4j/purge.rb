module Bountybase::Neo4j
  module Purge
    # purges all matching nodes and their relationships.
    def purge!(pattern = '*')
      # Possible improvement: There is a call which purges the entire database.
      # It requires the installation of the neo4j-clean-remote-db-addon 
      # (https://github.com/jexp/neo4j-clean-remote-db-addon)
      logger.benchmark :error, "purging nodes" do |b|
        count = 0
        while true do
          nodes = Bountybase::Neo4j::Node.all(pattern, :limit => 1000)
          break if nodes.empty?

          purge_nodes nodes
          count += nodes.length
        end

        b.message = "purging #{count} node(s)"
        count
      end
    end

    private

    def purge_nodes(nodes)
      # This works in batches. We must first get all of the nodes' relationships,
      # because a node with relationships cannot be deleted. 
      batch = nodes.map { |node| [ :get_node_relationships, node.url ] }

      relationship_ids = connection.batch(*batch).compact.
        map do |response|
          response["body"].map do |relationship|
            relationship["self"].split('/').last
          end
        end.flatten.uniq

      # The next batch deletes all the relationships and all the nodes.
      batch = []

      relationship_ids.each { |rel_id| batch << [ :delete_relationship, rel_id ] }
      nodes.each { |node| batch << [ :delete_node, node.url ] }

      connection.batch *batch
    end
  end

  extend Purge
end
