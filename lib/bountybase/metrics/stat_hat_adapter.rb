class Bountybase::Metrics; end

class Bountybase::Metrics::StatHatAdapter
  def background?
    true
  end
  
  def initialize(account)
    require "stathat"
    @account = account
  end

  def event(type, name, value, payload)
    expect! type => [ :count, :value ]

    case type
    when :count then StatHat::API.ez_post_count(name, @account, value || 1)
    when :value then StatHat::API.ez_post_value(name, @account, value)
    end
  end
end
