require 'uri'

class Bountybase::Metrics; end

class Bountybase::Metrics::StatHatAdapter
  def background?
    true
  end
  
  def initialize(account)
    @ezkey = account
  end

  def event(type, name, value, payload)
    expect! type => [ :count, :value ]

    send_to_stathat EZ_URL, :ezkey => @ezkey,
      :stat => name, type => value
  end

  private

  EZ_URL = "http://api.stathat.com/ez"
  
  def send_to_stathat(url, args)
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(args)
    Response.new Net::HTTP.get(uri)
  end
  
  class Response
    def initialize(body)
      @body = body
      @parsed = nil
    end

    def valid?
      status == 200
    end

    def status
      parsed['status']
    end

    def msg
      parsed['msg']
    end

    private

    def parsed
      @parsed ||= JSON.parse(@body)
    end
  end
end
