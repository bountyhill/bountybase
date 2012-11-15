require_relative 'test_helper'

class MessageTest < Test::Unit::TestCase
  include Bountybase::TestCase

  HEARTBEAT_PAYLOAD = {}

  def test_resolve
    Bountybase::Message::Heartbeat.any_instance.expects :perform 
    Bountybase::Message.perform "Heartbeat",
      { :instance => "instance", :environment => "environment" }, 
      { :instance => 'test', :environment => 'test', :timestamp => 1344259800}
  end

  def test_enqueue
    Resque::Job.expects(:create).
      with "heartbeat",                          # name of queue
            Bountybase::Message,                 # resque target performer
            'Bountybase::Message::Heartbeat',    # message name
            HEARTBEAT_PAYLOAD,                   # message payload
            MESSAGE_ORIGIN                       # message origin
    
    Bountybase::Message::Heartbeat.expects(:origin_hash).returns(MESSAGE_ORIGIN)
    Bountybase::Message::Heartbeat.enqueue HEARTBEAT_PAYLOAD
  end

  def test_dummy_implementation
    assert_raise(RuntimeError) do
      Bountybase::Message.new({}, {}).perform
    end
  end

  def test_resolve_security
    options, origin = {}, {}
    
    assert_raise(Bountybase::Message::UnknownName) do
      Bountybase::Message.perform(1, options, origin) 
    end
    
    assert_raise(Bountybase::Message::UnknownName) do 
      Bountybase::Message.perform("../Heartbeat", options, origin) 
    end

    assert_raise(Bountybase::Message::UnknownName) do 
      Bountybase::Message.perform("::Bountybase", options, origin) 
    end

    assert_raise(Bountybase::Message::UnknownName) do 
      Bountybase::Message.perform("Unknown", options, origin) 
    end

    assert_raise(Bountybase::Message::UnknownName) do 
      Bountybase::Message.perform("UnknownName", options, origin) 
    end

    assert_raise(ArgumentError) do 
      Bountybase::Message.perform("Heartbeat", 1, origin) 
    end
  end
  
  def test_default_queue
    assert_equal("heartbeat", Bountybase::Message::Heartbeat.default_queue)
  end

  def test_origin_hash
    freeze_time Time.at(12345678)
    
    with_settings "INSTANCE" => "test-bountybase" do
      assert_equal Bountybase::Message.origin_hash, 
        :instance => "bountybase", :environment => "test", :timestamp => 12345678
    end
  end
  
  def test_heartbeat_routing
    Bountybase::Message::Heartbeat.any_instance.expects :perform 
    perform_message "Heartbeat", HEARTBEAT_PAYLOAD
  end

  def test_heartbeat
    Bountybase.logger.expects :warn
    perform_message "Heartbeat", HEARTBEAT_PAYLOAD
  end
end
