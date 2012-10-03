require "simple_cache"

# A simple redis based cache; gets configured using The HTTP module implements a simple wrapper around Net::HTTP, intended to 
# ease the pain of dealing with HTTP requests. It uses the `addressable` gem
# to support IDN (internationized) domain names. If the "idn" gem is installed
# it will use that for faster, native IDN support.
module Bountybase
  def cache
    @cache ||= begin
      url = config.redis_for(:cache)
      SimpleCache.new Redis::Namespace.connect(url)
    end
  end 
  
  def cached(*args, &block)
    cache.cached(*args, &block)
  end
end
