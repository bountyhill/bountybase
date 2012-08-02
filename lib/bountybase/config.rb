require "ostruct"

class Bountybase::Config
  class Missing < RuntimeError; end
  
  def initialize
    @hash = {}
    @defaults = OpenStruct.new
  end

  attr :defaults
  
  # returns the URL for the resque redis queue
  def resque
    ENV["RESQUE_URL"] || 
    default(:resque) || 
    redis
  end

  # returns the URL for the redis database
  def redis
    ENV["REDIS_URL"] || 
    ENV["REDISTOGO_URL"] || 
    default!(:redis)
  end

  private

  def method_missing(sym, *args, &block)    # :nodoc:
    case !block_given? && args.length
    when 0 then 
      @hash[sym] || default!(sym)
    when 1 then 
      key = sym.to_s[0...-1].to_sym
      @hash[key] = args.first
    else        super
    end
  end
  
  def default(key) # :nodoc:
    case default_for_key = @defaults.send(key)
    when Hash then  default_for_key[Bountybase.environment]
    when nil  then  nil
    else            raise "Invalid Bountybase.config.#{key} default"
    end
  end

  def default!(key)    # :nodoc:
    default(key) || raise(Missing, "Missing config.#{key} value in #{Bountybase.environment.inspect} environment.")
  end
end

module Bountybase
  @@config = Config.new
  
  def self.config; @@config; end
end

require_relative "defaults"
