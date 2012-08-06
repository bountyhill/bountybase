# Bountybase::Message::Heartbeat: hey, I am still alive!
#
# Messages of this kind are sent regularily from several components to bountyclerk.
# bountyclerk sends them to the log and stat servers. 
class Bountybase::Message::Heartbeat < Bountybase::Message
  INTERVAL = 10 # send heartbeat every 10 seconds.

  def initialize(environment, instance)
    super
    @environment, @instance = environment, instance
  end
  
  # perform the heartbeat message.
  def perform
    Bountybase.logger.warn "heartbeat: #{@environment} #{@instance}"
  end
end
