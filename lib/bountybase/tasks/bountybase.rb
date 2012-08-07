namespace :bountybase do
  namespace :setup do
    task :instance do
      ENV["RACK_ENV"] = "test"
    end

    task :logger do
      require_relative "../../bountybase"
      Bountybase.setup
    end

    task :test => %w(instance logger)
  end
end

