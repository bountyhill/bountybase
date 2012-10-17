require "simple_cache"

# A simple redis based cache; gets configured using The HTTP module implements a simple wrapper around Net::HTTP, intended to 
# ease the pain of dealing with HTTP requests. It uses the `addressable` gem
# to support IDN (internationized) domain names. If the "idn" gem is installed
# it will use that for faster, native IDN support.
module Bountybase
  def cached(key, options = {}, &block)
    expect! options => { :ttl => [ Fixnum, nil ]}
    
    initialize_cache
    
    ttl = options[:ttl]
    SimpleCache.cached(key, ttl, &block)
  end

  private
  
  def initialize_cache
    return if @initialized_cache
    @initialized_cache = true
    
    SimpleCache.url = config.redis_for(:cache)
  end
end
