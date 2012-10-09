class StandardError
  def log(*args)
    severity = if args.first.is_a?(Symbol)
      args.shift
    else
      :error
    end

    msg = [ args.shift, to_s, "; from\n     #{backtrace.join("\n     ")}" ]

    Event.deliver severity, Bountybase.logger, msg
  end
end
