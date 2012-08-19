namespace :test do
  desc "Run performance tests"
  task :performance => [:enable_performance_tests, :default]
  
  task :enable_performance_tests do
    ENV["PERFORMANCE"] = "1"
  end
end
