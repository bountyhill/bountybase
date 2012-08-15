require_relative 'test_helper'

# ::Event::Listeners.add :console
# ::Event.route :all => :console

class Neo4jBaseTest < Test::Unit::TestCase
  include Bountybase::TestCase

  Neo4j = Bountybase::Neo4j
  
  def setup
    Neo4j.purge!
  end
  
  def teardown
  end

  def test_database_is_empty
    assert_equal(0, Neo4j.count)
  end
end
