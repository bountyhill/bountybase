require_relative 'test_helper'

# ::Event::Listeners.add :console
# ::Event.route :all => :console

class GraphTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def setup
    Bountybase::Graph.purge!
  end
  
  def teardown
  end

  def test_parse_options
    assert_equal(0, Bountybase::Graph::Neo4j.count)
  end
end
