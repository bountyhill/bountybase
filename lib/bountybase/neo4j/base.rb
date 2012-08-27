module Bountybase::Neo4j
  # Raised when trying to recreate an already existing node
  # with a different set of attributes.
  class DuplicateKeyError < RuntimeError; end

  # A base class for Neo4j objects. 
  #
  # A Neo4j object can be built off a Hash containing all its attributes,
  # or off an URL string which just declares *where* the object can be
  # found. Therefore, a Neo4j object is either fully fetched or not. 
  # It will be fetched automatically whenever needed - for example
  # when accessing its attributes.
  #
  # To explicitely fetch an object use the fetch method. This might
  # make sense when printing information for the object, as the 
  # inspect methods provide more detail for fully fetched objects. 
  class Base
    # A shortcut for Bountybase::Neo4j
    Neo4j = Bountybase::Neo4j

    extend Neo4j::Connection
    include Neo4j::Connection

    # equality
    #
    # Two objects are equal if they are of the same class and share the same
    # Neo4j URL.
    def ==(other)
      other.is_a?(self.class) && (other.url == self.url)
    end

    # returns the Neo4j URL of this object
    attr_reader :url
    
    private
    
    # Initialize this object with either a Hash or an URL. 
    #
    # Note that this method is private: always use Neo4j.build(url_or_hash) 
    # instead.
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
    
    public
    
    # returns true if attributes are loaded.
    def fetched?
      !@neography.nil?
    end

    # Make sure the object is fully fetched,
    def fetch
      neography
      self
    end
  end
end
