module Bountybase::Neo4j
  class Path < OpenStruct
    def self.new(hash)
      start, nodes, length, relationships, end_ = *hash.values_at(*%w(start nodes length relationships end))

      return unless start && end_
      super hash
    end

    def urls
      urls = []
      nodes.each_with_index do |node_url, index|
        urls << relationships[index - 1] if index > 0
        urls << node_url
      end
      urls
    end

    def inspect
      index = -1
      "<" + urls.map do |url|
        index += 1
        url = url.gsub "http://localhost:7474/db/data/", ""
        if index.even?
          url
        else
          "--[#{url.gsub("relationship", "rel")}]-->"
        end
      end.join(" ") + ">"
    end
  end
end
