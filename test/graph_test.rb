require_relative 'test_helper'

class MetricsTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def test_parse_options
    connections, options = Bountybase::Graph.parse_options({})
    assert_equal([], connections)
    assert_equal({}, options)

    connections, options = Bountybase::Graph.parse_options(:a => :b, :c => :d)
    assert_equal([], connections)
    assert_equal({:a => :b, :c => :d}, options)

    connections, options = Bountybase::Graph.parse_options(1 => 2, "3" => 44, :a => :b, :c => :d)
    assert_equal([[1, 2], ["3", 44]], connections)
    assert_equal({:a => :b, :c => :d}, options)
  end

  def test_neo4j
    assert_not_nil Bountybase::Graph.connection
  end

  def test_neo4j_all
    Bountybase::Graph.clear!
    #assert_not_nil Bountybase::Graph.connection
  end
end
