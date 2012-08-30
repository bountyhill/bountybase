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
  #   hash = hash.with_indifferent_keys
  #
  #   hash["foo"]     #  "foos"
  #   hash[:foo]      #  "foos"
  #   hash["bar"]     #  "bars"
  #   hash[:bar]      #  "bars"
  #
  def with_indifferent_keys
    dup.extend(WithIndifferentKeys)
  end

  # returns a copy of this Hash where all String keys are symbolized.
  def with_symbolized_keys
    inject({}) do |hash, (key, value)|
      if key.is_a?(String)
        hash.update key.to_sym => value
      else
        hash.update key => value
      end
    end
  end

  # returns a copy of this Hash where all keys (including, e.g. Fixnums) are stringified.
  def with_stringified_keys
    inject({}) do |hash, (key, value)|
      hash.update key.to_s => value
    end
  end
  
  module WithIndifferentKeys #:nodoc:
    # If the key exists in any of its indifferent forms, it returns
    # the specific form, if not, it returns the key.
    def self.find_key(hash, key) #:nodoc:
      case key
      when Symbol
        s = key.to_s
        return s if hash.key?(s, false)
      when String
        sym = key.to_sym
        return sym if hash.key?(sym, false)
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

    def key?(key, try_indifferent_keys = true) #:nodoc:
      super(key) || 
        case try_indifferent_keys ? key : false
        when Symbol then super(key.to_s)
        when String then super(key.to_sym)
        else false
        end
    end
  end
end

