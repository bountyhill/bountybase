# A Bountybase::Message::Tweet message is sent whenever bountytwirl sees
# a (potentially) matching twitter status. bountytwirl then generates a
# Bountybase::Message::Tweet message, which is to be processed by  
# bountyclerk.
class Bountybase::Message::Tweet < Bountybase::Message
  # perform the heartbeat message.
  def perform
    Bountybase::Graph.register_tweet(payload)
  end
end
