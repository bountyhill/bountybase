# Bountybase::Message::Heartbeat. This message is sent regularily from
# several bountyhill components to bountyclerk, where it will be counted
# and accumulated.
class Bountybase::Message::Heartbeat < Bountybase::Message
  # perform the heartbeat message.
  def perform
    Bountybase.logger.warn "heartbeat: #{environment} #{instance}"
  end
end
