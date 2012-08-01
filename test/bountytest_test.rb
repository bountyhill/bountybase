require_relative 'test_helper'

require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/http_test'
  c.hook_into :webmock # or :fakeweb
end

class BountyTest < Test::Unit::TestCase
  include Bountybase::TestCase
end
