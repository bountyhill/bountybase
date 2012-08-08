module Deployment
  extend self
  
  attr :target, true

  def applications
    @applications ||= sys("cat .git/config  | grep heroku.*#{target} | sed s-.*heroku.com:-- | sed s-.git--").split("\n")
  end

  # The target role, for example "twirl"
  def target_role
    return unless target = applications.first
    target.split("-").last.gsub(/\d+$/, "")
  end
  
  # The target environment, for example "staging"
  def target_environment
    return unless application = applications.first
    application.split("-").first
  end
  
  # returns "deployment-staging", for example.
  def instance
    "deployment-#{target}"
  end
  
  def run
    # deploy in $deployment_target
    die "Usage: rake staging deploy" unless Deployment.target
    die "No configured applications to deploy in #{Deployment.target.inspect}" if applications.empty?

    Bountybase.with_settings "INSTANCE" => instance do
      Bountybase.setup
      
      Event.severity = :debug

      prepare_deployment

      applications.each do |application|
        prepare_application(application)
        deploy_application(application)
      end
    end
  end
  
  def head(subdir)
    Dir.chdir(subdir) do
      sys "git rev-parse --verify --short HEAD"
    end
  rescue Errno::ENOENT
  end
  
  def verify_bountybase_versions
    return unless bountybased = head("vendor/bountybased")
    return unless bountybased != head("vendor/bountybase")

    die <<-MSG
bountybased and bountybase versions differ. Please push the bountybase project and update the bountybase submodule:

    pushd vendor/bountybased
    # commit outstanding changes
    git push
    popd
    pushd vendor/bountybase
    git pull
    popd
    git commit -m "Updated bountybase submodule" vendor/bountybase .gitmodules
MSG
  end
  
  def prepare_deployment
    verify_bountybase_versions
  end
    
  def prepare_application(application)
    remote_instance = sys! "heroku config:get INSTANCE --app #{application}"
    unless remote_instance == application
      logger.warn "Setting INSTANCE config at remote to #{application}"
      sys! "heroku config:set INSTANCE=#{application} --app #{application}"
    end
  end

  def deploy_application(application)
    sys! "git push #{application} master"
    logger.warn "Deployed", application
  end

  def sys(cmd)
    logger.debug cmd
    stdout = Kernel.send "`", "bash -c '#{cmd}'"
    
    stdout.chomp if $?.exitstatus == 0
  end

  def sys!(cmd)
    sys(cmd) || die("Command failed", cmd)
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
