require "ostruct"

class Bountybase::Config < OpenStruct
  class Missing < RuntimeError; end
  
  def initialize
    super
    @defaults = OpenStruct.new
  end

  attr :defaults
  
  # returns the URL for the resque redis queue
  def resque
    super ||
      ENV["RESQUE_URL"] || 
      default(:resque) ||
      redis
  end

  # returns the URL for the redis database
  def redis
    super ||
      ENV["REDIS_URL"] || 
      ENV["REDISTOGO_URL"] || 
      default!(:redis)
  end

  private

  def method_missing(sym, *args, &block)    # :nodoc:
    return super if !args.empty? || block_given?
    default!(sym)
  end
  
  def default(key)
    case defaults = @defaults.send(key)    # :nodoc:
    when Hash then  defaults[Bountybase.environment]
    when nil  then  nil
    else            raise "Invalid Bountybase.config.#{key} default"
    end
  end

  def default!(key)    # :nodoc:
    default(key) || raise(Missing, "Missing config.#{key} value.")
  end
end

module Bountybase
  @@config = Config.new
  
  def self.config; @@config; end
end

require_relative "defaults"
