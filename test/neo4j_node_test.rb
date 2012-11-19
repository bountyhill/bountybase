require_relative 'test_helper'

class Neo4jNodeTest < Test::Unit::TestCase
  include Bountybase::TestCase

  Neo4j = Bountybase::Neo4j

  def setup
    Neo4j.purge!
  end

  def test_create_wo_attributes
    freeze_time(123456)
    
    node = Neo4j::Node.create "foo", 1
    assert! node => Neo4j::Node,
      node.url => /http:\/\/.*\/data\/node/,
      node.type => "foo"

    assert_equal node.attributes, "type"=>"foo", "uid"=>1, "created_at"=>123456

    assert_equal(1, Neo4j::Node.count)

    # can create a different node
    Neo4j::Node.create "foo", 2
    assert_equal(2, Neo4j::Node.count)

    # creating an already existing identical node is ignored.
    Neo4j::Node.create "foo", 1
    assert_equal(2, Neo4j::Node.count)
  end

  def test_attribute_shortcuts
    freeze_time(123457)
    
    node = Neo4j::Node.create "foo", 1, :bar => "baz"
    assert_equal node.uid, 1
    assert_equal node.created_at, Time.at(123457)
    assert_equal node.updated_at, Time.at(123457)
  end
  
  def test_create_w_attributes
    assert_equal(0, Neo4j::Node.count)

    freeze_time(123457)
    
    node = Neo4j::Node.create "foo", 1, :bar => "baz"
    assert_kind_of(Neo4j::Node, node)
    
    assert! node => Neo4j::Node,
      node.url => /http:\/\/.*\/data\/node/,
      node.type => "foo"

    assert_equal node.attributes, "type"=>"foo", "uid"=>1, "created_at"=>123457, "bar" => "baz"

    assert_equal(1, Neo4j::Node.count)

    # can create a different node
    Neo4j::Node.create "foo", 2, :bar => "baz"
    assert_equal(2, Neo4j::Node.count)

    # creating an already existing identical node is ignored.
    node2 = Neo4j::Node.create "foo", 1, :bar => "baz"
    assert_equal(2, Neo4j::Node.count)
    assert_equal node2.attributes, "type"=>"foo", "uid"=>1, "created_at"=>123457, "bar" => "baz"

    # creating a node with identical key and different attributes fails.
    assert_raise(Neo4j::DuplicateKeyError) {  
      Neo4j::Node.create "foo", 1, :bar => "bazie"
    }
    assert_equal(2, Neo4j::Node.count)

    # creating an already existing semi-identical node is ignored, if the only differences
    # are "created_at" and/or "updated_at" keys.

    freeze_time(123458)

    node2 = Neo4j::Node.create "foo", 1, :bar => "baz"
    assert_equal(2, Neo4j::Node.count)
    assert_equal node2.attributes, "type"=>"foo", "uid"=>1, "created_at"=>123457, "bar" => "baz"
  end

  def test_crud
    assert_equal(0, Neo4j::Node.count)

    # --- create node -------------------------------------------------
    
    freeze_time(123457)
    
    node = Neo4j::Node.create "foo", 1, :bar => "baz"
    assert_equal(node.created_at, Time.at(123457))
    assert_equal(node.updated_at, Time.at(123457))

    # --- update node -------------------------------------------------

    freeze_time(123458)

    node.update :bar => "bazie"
    assert_equal node.attributes, "bar"=>"bazie",
                                  "type"=>"foo",
                                  "uid"=>1,
                                  "created_at"=>123457,
                                  "updated_at"=>123458
    assert_equal(node.created_at, Time.at(123457))
    assert_equal(node.updated_at, Time.at(123458))

    # --- find node ---------------------------------------------------

    freeze_time(123459)
    
    node2 = Neo4j::Node.find "foo", 1
    assert_equal(node2.attributes, "uid"=>1,
                                   "updated_at"=>123458,
                                   "created_at"=>123457,
                                   "type"=>"foo",
                                   "bar"=>"bazie")

    assert_equal(node.created_at, Time.at(123457))
    assert_equal(node.updated_at, Time.at(123458))
    
    # --- delete node -------------------------------------------------

    assert_equal(1, Neo4j::Node.count)

    assert_equal(true, node.destroy)
    assert_equal(0, Neo4j::Node.count)

    assert_equal(false, node2.destroy)
    assert_equal(0, Neo4j::Node.count)
  end

  def test_destroy_class_methods
    Neo4j::Node.create "foo", 1, :bar => "baz"
    assert_equal(1, Neo4j::Node.count)

    Neo4j::Node.destroy "foo", 2
    assert_equal(1, Neo4j::Node.count)

    Neo4j::Node.destroy "foo", 1
    assert_equal(0, Neo4j::Node.count)

    Neo4j::Node.destroy "foo", 1
    assert_equal(0, Neo4j::Node.count)
  end
  
  def test_cannot_find
    Neo4j::Node.create "foo", 1, :bar => "baz"
    assert_nil Neo4j::Node.find("foo", 2)
    
    assert_nil Neo4j::Node.find("foox", 1)
  end
  
  def test_equality
    foo = Neo4j::Node.create "foo", 1
    bar = Neo4j::Node.create "bar", 1

    assert_equal(foo, foo)
    assert_not_equal(foo, bar)

    foo1 = Neo4j::Node.create "foo", 1

    assert_equal(foo, foo1)
    assert_not_equal(foo1, bar)

    foo2 = Neo4j::Node.create "foo2", 1

    assert_not_equal(foo1, foo2)
  end
end
