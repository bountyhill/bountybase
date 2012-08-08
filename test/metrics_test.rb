require_relative 'test_helper'

class MetricsTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def setup
    # stub an ok config
    Bountybase::Metrics.stubs(:config).returns(["user", "key"])
  end
  
  def teardown
    Bountybase.metrics.clear
  end

  def test_metrics
    assert_not_nil(Bountybase.metrics)
  end
  
  def test_counters
    Bountybase.metrics.pageviews!
    assert_equal(1, queued(:counters).length)

    # use the counter
    Bountybase.metrics.pageviews! 3

    assert_equal(2, queued(:counters).length)

    assert_equal [1,3], queued_attrs(:counters, :value)
  end

  def test_gauges
    Bountybase.metrics.processing_time 20

    assert_equal(1, queued(:gauges).length)
  
    # no default value for gauges
    assert_raise(ArgumentError) {  
      Bountybase.metrics.processing_time 
    }
  end

  def test_submit
    Bountybase.metrics.queue.expects(:submit).never
    Bountybase.metrics.submit

    Bountybase.metrics.queue.expects(:submit).once

    Bountybase.metrics.pageviews 3
    Bountybase.metrics.submit
  end
  
  def queued(type)
    Bountybase.metrics.queue.queued[type] || []
  end

  def queued_attrs(type, attr)
    queued(type).map do |hash|
      hash[attr]
    end
  end
end
