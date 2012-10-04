require_relative 'test_helper'

class HashTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def test_with_indifferent_keys
    hash = { :foo => "foos", "bar" => "bars" }
  
    hash = hash.with_indifferent_keys
  
    assert_equal "foos", hash["foo"]     #  "foos"
    assert_equal "foos", hash[:foo]     #  "foos"
    assert_equal "bars", hash["bar"]     #  "foos"
    assert_equal "bars", hash[:bar]     #  "foos"

    assert_equal "foos", hash.fetch("foo")     #  "foos"
    assert_equal "foos", hash.fetch(:foo)     #  "foos"
    assert_equal "bars", hash.fetch("bar")     #  "foos"
    assert_equal "bars", hash.fetch(:bar)     #  "foos"

    assert_equal nil, hash[:baz]     #  "foos"

    assert_raise(KeyError) {  
      hash.fetch(:baz)  
    }
    
    assert hash.key?(:foo)
    assert hash.key?("foo")
    assert hash.key?(:bar)
    assert hash.key?("bar")
  end

  def test_with_symbolized_keys
    hash = { :foo => "foos", "bar" => "bars" }
  
    hash = hash.with_symbolized_keys
    
    assert_equal({ :foo => "foos", :bar => "bars" }, hash)
  end

  def test_with_stringified_keys
    hash = { :foo => "foos", "bar" => "bars" }
  
    hash = hash.with_stringified_keys
    
    assert_equal({ "foo" => "foos", "bar" => "bars" }, hash)
  end

  # def test_ostruct_inspect
  #   ostruct = OpenStruct.new :foo => "foos", "bar" => "bars" 
  #   assert_equal("bar: \"bars\", foo: \"foos\"", ostruct.inspect)
  # end
end
