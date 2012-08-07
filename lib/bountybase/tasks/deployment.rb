module Deployment
  extend self
  
  attr :target, true

  def apps
    `cat .git/config  | grep heroku.*#{target} | sed s-.*heroku.com:-- | sed s-.git--`.split(/\n/)
  end
  
  def run
    # deploy in $deployment_target
    die "Usage: rake staging deploy" unless Deployment.target
    die "No configured applications to deploy in #{Deployment.target.inspect}" if apps.empty?

    STDERR.puts "Deploy applications #{apps.inspect}"
  end
  
  def die(*args)
    STDERR.puts args.join(" ")
    exit 1
  end
end

desc "deploy a set of applications"
task :deploy do
  Deployment.run
end

desc "set staging deploy mode"
task :staging do
  Deployment.target = :staging
end

desc "set live deploy mode"
task :live do
  Deployment.target = :live
end
