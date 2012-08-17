require "curb"

class Neography::Rest
  class Curl::Easy
    def parsed_response
      @parsed_response ||= MultiJsonParser.new(body_str, :json).send(:json)
    end
    
    alias :body :body_str
    alias :code :response_code
  end
  
  def http(verb, path, post_body = nil, put_data = nil, &block)
    # STDERR.print verb.to_s[0,1]
    url = configuration + URI.encode(path)

    Curl.http(verb, url, post_body, put_data) do |curb|
      curb.headers["Accept"] = "application/json"
      curb.headers["Content-Type"] = "application/json"
      curb.headers["Connection"] = "Keep-Alive"
    end.tap do |easy|
      puts easy.header_str
    end
  end
    
  def get(path,options={})
    evaluate_response http(:GET, path)
  end

  def post(path,options={})
    evaluate_response http(:POST, path, options[:body])
  end

  def put(path,options={})
    evaluate_response http(:PUT, path, nil, options[:body])
  end

  def delete(path,options={})
    evaluate_response http(:DELETE, path)
  end
end
