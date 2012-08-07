require_relative 'test_helper'

require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/http_test'
  c.hook_into :webmock # or :fakeweb
end

class BountybaseTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def test_application_root
    assert_equal nil, ENV["RACK_ROOT"]
    
    assert_raise(Bountybase::Attributes::Missing) { 
      Bountybase.root 
    }

    ENV["RACK_ROOT"] = "expected"
    assert_equal "expected", Bountybase.root
  end

  def test_environment
    assert_equal "test", Bountybase.environment

    Bountybase.in_environment "yadda" do
      assert_equal "yadda", Bountybase.environment
    end

    assert_equal "test", Bountybase.environment
  end
end
