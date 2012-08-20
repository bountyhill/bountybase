module Bountybase::Neo4j
  class DuplicateKeyError < RuntimeError; end

  # A base class for Neo4j objects. Derived classes must implement the
  # _save_attributes_ instance method and the _readonly_attribute_names_
  # class method.
  class Base
    Neo4j = Bountybase::Neo4j

    extend Neo4j::Connection
    include Neo4j::Connection

    # equality
    def ==(other)
      other.is_a?(self.class) && (other.url == self.url)
    end

    attr :url
    
    private
    
    # initialize this object with either a Hash or an URL. 
    #
    # Note that one can verify the type of the object from the URL, and one can
    # get the URL from the Hash. Therefore one should always create the right
    # kind of object (i.e. a Neo4j::Node or Neo4j::Relationship instead of of
    # a Neo4j::Base object.) That is the reason that Base#initialize is
    # private - just use Neo4j::Base.create(url_or_hash) instead.
    def initialize(neography)
      case neography
      when String
        expect! neography => /^http/
        @url = neography
      when Hash     
        @neography, @url = neography, neography["self"]
      end
    end
    
    # returns the neography Hash
    def neography  #:nodoc:
      @neography ||= load_neography
    end
  end
end
