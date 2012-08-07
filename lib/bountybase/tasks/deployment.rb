module Deployment
  extend self
  
  attr :target, true

  def applications
    @applications ||= sys("cat .git/config  | grep heroku.*#{target} | sed s-.*heroku.com:-- | sed s-.git--").split("\n")
  end

  # returns "staging-deployment", for example.
  def instance
    applications.first.gsub(/-.*/, "-deployment")
  end
  
  def run
    # deploy in $deployment_target
    die "Usage: rake staging deploy" unless Deployment.target
    die "No configured applications to deploy in #{Deployment.target.inspect}" if applications.empty?

    Bountybase.with_settings "INSTANCE" => instance do
      Bountybase.with_environment self.target do
        Bountybase.setup
        prepare_deployment

        applications.each do |application|
          prepare_application(application)
          deploy_application(application)
        end
      end
    end
  end
  
  def prepare_deployment
    logger.warn "Preparing deployment"
  end
    
  def prepare_application(application)
    remote_instance = sys "heroku config:get INSTANCE --app #{application}"
    unless remote_instance == application
      logger.warn "Setting INSTANCE config at remote to #{application}"
      sys "heroku config:set INSTANCE=#{application} --app #{application}"
    end
  end

  def deploy_application(application)
    sys "git push #{application} master"
    logger.warn "Deployed", application
  end

  def sys(cmd)
    logger.info "Running: #{cmd}"
    stdout = Kernel.send "`", "bash -c '#{cmd}'"
    if $?.exitstatus != 0
      die "Command failed", cmd
    end
    
    stdout.chomp
  end
  
  def die(*args)
    logger.error *args unless args.empty?
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
