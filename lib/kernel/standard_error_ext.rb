class StandardError
  def log(*args)
    severity = if args.first.is_a?(Symbol)
      args.shift
    else
      :error
    end

    msg = to_s
    if args.first
      msg = "#{args.shift}: #{msg}" 
    end
    
    if Bountybase.environment == "development"
      def backtrace.inspect
        "\nfrom  #{$!.backtrace.join("\n      ")}"
      end
      args << backtrace
    end

    Event.deliver severity, Bountybase.logger, msg, *args
  end
end
