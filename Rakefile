# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
# require 'rake'
# 
require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

# 
require 'rdoc/task'
RDoc::Task.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "bhttp #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

namespace :bountybase do
  namespace :setup do
    task :logger do
      require_relative "lib/bountybase"
      Bountybase.setup
    end

    task :instance do
      ENV["RACK_ENV"] = "test"
    end

    task :test => %w(instance logger)
  end
end

task :test => "bountybase:setup:test" do
  Bountybase.logger.warn "Bountybase: running test"
end

task :default => [:test, :rdoc]
