require_relative 'test_helper'

class MetricsTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def test_metrics
    assert_not_nil(Bountybase.metrics)
  end
  
  def metrics_service
    @metrics_service ||= Bountybase.metrics.instance_variable_get("@service")
  end
  
  def test_counters
    metrics_service.expects(:event).with(:_type => :pageviews)
    Bountybase.metrics.pageviews!
  end

  def test_counters_w_parameters
    metrics_service.expects(:event).with(:_type => :pageviews, :a => :b)
    Bountybase.metrics.pageviews! :a => :b
  end

  def test_gauges
    metrics_service.expects(:event).with(:_type => :processing_time, :value => 20)
    Bountybase.metrics.processing_time 20
  end

  def test_gauges_w_parameters
    metrics_service.expects(:event).with(:_type => :processing_time, :value => 20, :a => :b)
    Bountybase.metrics.processing_time 20, :a => :b
  end

  def test_invalid_number_of_arguments
    assert_raise(ArgumentError) do
      Bountybase.metrics.processing_time 20, 30
    end
  end
end
