require "net/http"
require "addressable/uri"
require "ostruct"

# The HTTP module implements a simple wrapper around Net::HTTP, intended to ease the
# pain of dealing with HTTP requests.
#
# It uses the `addressable` gem for better support for IDN (internationized) domain names.
# For native IDN support install the "idn" gem.
module Bountybase::HTTP
  extend self

  # Error to be raised when maximum number of redirections is reached.
  class RedirectionLimit < RuntimeError; end

  # Base class for HTTP related errors.
  class Error < RuntimeError
    
    # The response object (of class HTTP::Response).
    attr :response 

    def initialize(response) #:nodoc:
      @response = response
    end
    
    def message #:nodoc:
      "#{@response.response.class}: #{@response[0..100]}"
    end
  end
  
  # Raised when a server responded with an error 5xx.
  class ServerError < Error; end

  # Raised when a server responded with an error 4xx.
  class ResourceNotFound < Error; end
  
  # -- configuration

  @@config = OpenStruct.new
  
  # The configuration object. It supports the following entries:
  # - config.headers: default headers to use when doing HTTP requests. Default: "Ruby HTTP client/1.0"
  # - config.max_redirections: the number of maximum redirections to follow. Default: 10
  def config
    @@config
  end
  
  config.headers = {
    "User-Agent" => "Ruby HTTP client/1.0"
  }
  
  config.max_redirections = 10

  # -- return types
  
  # The HTTP::Response class works like a string, but contains extra "attributes"
  # status and headers, which return the response status and response headers.
  class Response < String
    attr :url, :original_url, :response
    
    def initialize(response, url, original_url) #:nodoc:
      @response, @url, @original_url = response, url, original_url
      super(response.body || "")
    end

    # returns true if the status is in the 2xx range.
    def valid?
      (200..299).include? status
    end
    
    # returns the response object itself, if it is valid (i.e. has a ), or raise
    def validate!
      return self if valid?
      
      case status
      when 400..499 then raise ResourceNotFound, self
      when 500..599 then raise ServerError, self
      else raise Error, self
      end
    end
    
    # returns the HTTP status code, as an Integer.
    def status
      @response.code.to_i
    end
    
    # returns all headers.
    def headers
      @headers ||= {}.tap do |h|
        @response.each_header do |key, value|
          h[key] = value
        end
      end
    end
  end
  
  # -- do requests
  
  public
  
  # resolve an URL. This tries to follow all URL redirections, until either
  # an error occurs or a final URL is found.
  def resolve(url, headers = {})
    r = do_request HEAD, url, headers, config.max_redirections, url, HEAD
    r.url
  end

  # runs a get request and return a HTTP::Response object.
  def get(url, headers = {})
    do_request GET, url, headers, config.max_redirections, url
  end
  
  # runs a get request and return a validated HTTP::Response object. This 
  # raises an exception if the HTTP request did not result in a 2xx status.
  def get!(url, headers = {})
    get(url, headers).validate!
  end
  
  private
  
  GET = Net::HTTP::Get      # :nodoc:
  HEAD = Net::HTTP::Head    # :nodoc:
  
  def do_request(verb, uri, headers, max_redirections, original_url, redirection_verb = GET) #:nodoc:
    # merge default headers
    headers = config.headers.merge(headers)

    # create connection
    
    uri = Addressable::URI.parse(uri) if uri.is_a?(String)

    default_port = uri.scheme == "https" ? 443 : 80
    http = Net::HTTP.new(uri.host, uri.port || default_port)
    if uri.scheme == "https"
      http.use_ssl = true 
    end
    
    # create request and get response

    request = verb.new(uri.request_uri)
    request.basic_auth(r.user, r.password) if uri.user && uri.password
    response = http.request(request)
    
    # follow redirection, if needed

    case response
    when Net::HTTPRedirection
      # Note: we always follow the redirect using a GET. This seems to violate parts of
      # RFC 2616, but sadly seems the best default behaviour, as is implemented that way
      # in many clients..
      raise RedirectionLimit.new(original_url) if max_redirections <= 0
      return do_request redirection_verb, response["Location"], headers, max_redirections-1, original_url, redirection_verb
    else
      Response.new(response, uri.to_s, original_url) 
    end
  end
end
