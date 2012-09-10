require "redis"

class Redis::Namespace
  def url
    "#{@redis.client.url}/#{@namespace}"
  end
  
  def self.connect(server)
    return nil if !server

    if server =~ /redis\:\/\//
      redis = Redis.connect(:url => server, :thread_safe => true)
    else
      url, namespace = server.split('/', 2)
      host, port, db = server.split(':')
      redis = Redis.new(:host => host, :port => port,
        :thread_safe => true, :db => db)
    end

    if namespace
      redis = Redis::Namespace.new(namespace, :redis => redis)
    end
    
    redis
  end
end

class Redis::Client
  def url
    scheme, host, port, db = *@options.values_at(:scheme, :host, :port, :db)

    url = "#{scheme}://#{host}:#{port}"
    url += ":#{db}" if db != 0
    url
  end
end

class Redis
  def url
    client.url
  end    
  
  def roundtrip
    ping
    logger.benchmark(:warn, "Roundtrip to redis at", url, :min => 0) do
      ping
    end
  end
end
