class Hash
  # This method mixes in the WithIndifferentKeys module, which implements
  # hash lookup independently of a key being a Symbol or a String.
  #
  #   hash = { :foo => "foos", "bar" => "bars" }
  #   hash["foo"]     #  nil
  #   hash[:foo]      #  "foos"
  #   hash["bar"]     #  "bars"
  #   hash[:bar]      #  nil
  #
  #   hash.withIndifferentKeys!
  #
  #   hash["foo"]     #  "foos"
  #   hash[:foo]      #  "foos"
  #   hash["bar"]     #  "bars"
  #   hash[:bar]      #  "bars"
  #
  def withIndifferentKeys!
    extend WithIndifferentKeys
  end

  module WithIndifferentKeys #:nodoc:
    # If the key exists in any of its indifferent forms, it returns
    # the specific form, if not, it returns the key.
    def self.find_key(hash, key) #:nodoc:
      case key
      when Symbol
        s = key.to_s
        return s if hash.key?(s)
      when String
        sym = key.to_sym
        return sym if hash.key?(sym)
      end
      
      key
    end

    def fetch(key) #:nodoc:
      super(WithIndifferentKeys.find_key(self, key))
    end

    def [](key) #:nodoc:
      super(WithIndifferentKeys.find_key(self, key))
    end

    def []=(key, value) #:nodoc:
      super(WithIndifferentKeys.find_key(self, key), value)
    end
  end
end

