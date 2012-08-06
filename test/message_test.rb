require_relative 'test_helper'

class MessageTest < Test::Unit::TestCase
  include Bountybase::TestCase

  def test_resolve
    Bountybase::Message::Heartbeat.any_instance.expects :perform 
    Bountybase::Message.perform "Heartbeat", 1, 2
  end

  def test_resolve_security
    assert_raise(Bountybase::Message::UnknownName) do
      Bountybase::Message.perform(1) 
    end
    
    assert_raise(Bountybase::Message::UnknownName) do 
      Bountybase::Message.perform("../Heartbeat") 
    end

    assert_raise(Bountybase::Message::UnknownName) do 
      Bountybase::Message.perform("::Bountybase") 
    end

    assert_raise(Bountybase::Message::UnsupportedParameters) do 
      Bountybase::Message.perform("Heartbeat", 1) 
    end

    assert_raise(Bountybase::Message::UnsupportedParameters) do 
      Bountybase::Message.perform("Heartbeat", 1, 2, 3) 
    end
  end
end
