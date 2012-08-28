require_relative 'test_helper'
require 'http'

class HTTPTest < Test::Unit::TestCase
  include Bountybase::TestCase
  
  def test_get
    VCR.use_cassette('test_get', :record => :once, :allow_playback_repeats => true) do
      response = HTTP.get "http://16b.org"
      assert_equal <<-HTML, response
<html>
<head>
<title>Welcome to nginx!</title>
</head>
<body bgcolor="white" text="black">
<center><h1>Welcome to nginx!</h1></center>
</body>
</html>
HTML

      assert_equal "http://16b.org", response.original_url
      assert_equal "http://16b.org", response.url

      assert_equal response.headers, 
        "server"        =>"nginx/1.1.19",
        "date"          =>"Wed, 01 Aug 2012 12:02:35 GMT",
        "content-type"  =>"text/html",
        "content-length"=>"151",
        "last-modified" =>"Mon, 04 Oct 2004 15:04:06 GMT",
        "connection"    =>"keep-alive",
        "accept-ranges" =>"bytes"

      assert_equal 200, response.status
      
      # does get! returns the proper content?
      assert_equal response, HTTP.get!("http://16b.org")
    end
  end

  def test_redirections
    VCR.use_cassette('test_redirections', :record => :once) do
      response = HTTP.get "http://google.de"
      
      assert_equal "http://google.de", response.original_url
      assert_equal "http://www.google.de/", response.url

      assert_equal 13101, response.length
      assert_equal 10, response.headers.length
    
      assert_equal 200, response.status
    end
  end

  def test_error500
    VCR.use_cassette('test_error500', :record => :once, :allow_playback_repeats => true) do
      response = HTTP.get "http://sosfunds.org/500"
      
      assert_equal "http://sosfunds.org/500", response.original_url
      assert_equal "http://sosfunds.org/500", response.url

      assert_equal 500, response.status
      assert_equal 30, response.length

      assert_raise(HTTP::ServerError) {  
        HTTP.get! "http://sosfunds.org/500"
      }
    end
  end

  def test_https
    VCR.use_cassette('test_https', :record => :once, :allow_playback_repeats => true) do
      response = HTTP.get "https://google.com"
      
      assert_equal "https://google.com", response.original_url
      assert_equal "https://www.google.de/", response.url

      assert_equal 200, response.status
      assert_equal 13164, response.length
    end
  end

  def test_resolve_url
    VCR.use_cassette('test_resolve_url', :record => :once, :allow_playback_repeats => true) do
      assert_equal "https://www.google.de/", HTTP.resolve("https://google.com")
      assert_equal "http://sosfunds.org/500", HTTP.resolve("http://sosfunds.org/500")
      assert_equal "http://www.google.de/", HTTP.resolve("http://google.de")

      # This is a t.co link, which redirects into a bit.ly link, which redirects to www.audiohack.org, 
      # which then redirects to audiohack.org
      assert_equal "http://audiohackday.org/", HTTP.resolve("http://t.co/ZczESpRE")
    end
  end
end

