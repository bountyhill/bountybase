namespace :bountybase do
  namespace :setup do
    task :test do
      ENV["RACK_ENV"] = "test"
    end
  end
end

