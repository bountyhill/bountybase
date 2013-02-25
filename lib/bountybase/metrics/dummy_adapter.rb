class Bountybase::Metrics; end

class Bountybase::Metrics::DummyAdapter
  def background?
    false
  end
  
  def event(type, name, value, payload)
    D "event", type, name, value
  end
end
