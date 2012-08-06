require_relative 'test_helper'

class MessageTest < Test::Unit::TestCase
  include Bountybase::TestCase

  ORIGIN =            { :instance => 'test', :environment => 'test', :timestamp => 1344259800 }
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
            Bountybase::Message,                 # resuqe target performer
            'Bountybase::Message::Heartbeat',    # message name
            HEARTBEAT_PAYLOAD,                   # message payload
            ORIGIN                               # message origin
    
    Bountybase::Message::Origin.expects(:create_hash).returns(ORIGIN)
    Bountybase::Message::Heartbeat.enqueue HEARTBEAT_PAYLOAD
  end

  def test_dummy_implementation
    assert_raise(RuntimeError) do
      Bountybase::Message.new.perform
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

    assert_raise(Bountybase::Message::UnsupportedParameters) do 
      Bountybase::Message.perform("Heartbeat", 1, origin) 
    end
  end
  
  def test_message_queue
    assert_equal("heartbeat", Bountybase::Message::Heartbeat.queue)
  end
end
