module Deployment
  def self.event_source_name #:nodoc:
    Dir.getwd.sub(ENV["HOME"], "~")
  end

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
  
  attr :application
  
  def run
    # deploy in $deployment_target
    die "Usage: rake staging deploy" unless Deployment.target
    die "No configured applications to deploy in #{Deployment.target.inspect}" if applications.empty?

    Bountybase.with_settings "INSTANCE" => instance do
      Bountybase.setup
      
      Event.severity = :debug
      
      prepare_deployment

      applications.each do |application|
        @application = application
        
        prepare_application
        deploy_application
        scale_application
        
        @application = nil
      end
    end
  end
  
  def head(subdir)
    Dir.chdir(subdir) do
      sys "git rev-parse --verify --short HEAD"
    end
  rescue Errno::ENOENT
  end
  
  def git_changed?(dir)
    return false
    
    Dir.chdir(dir) do
      if !sys("git diff --exit-code")
        "unstaged"
      elsif !sys("git diff --exit-code --cached")
        "uncommitted"
      end
    end
  end
  
  def verify_bountybase_versions
    return unless bountybased = head("vendor/bountybased")
    if changes = git_changed?("vendor/bountybased")
      die <<-MSG
The bountybased directory contains #{changes} changes. Please commit these changes and repeat.
MSG
    end
    
    bountybase = head("vendor/bountybase")
    return unless bountybased != bountybase

    Bountybase.logger.warn "bountybased and bountybase versions differ (#{bountybased} vs #{bountybase}). Fetching current version:"

    sys! "(cd vendor/bountybase; git pull)"
    sys! "git commit -m 'Updated bountybase submodule' vendor/bountybase .gitmodules"
  end
  
  def prepare_deployment
    verify_bountybase_versions
  end
  
  def scale_application
    @scale ||= File.read("Procfile").                   # read Procfile
      split("\n").                                      # split in lines
      reject do |line| line =~ /#/ end.                 # remove comments
      inject({}) do |hash, line|                # merge into a hash
        hash.update line.split(":").first => 1 
      end.
      map do |kv| kv.join("=") end                      # build "NAME=VALUE" parts

    heroku "ps:scale #{@scale.join(" ")}"               # scale heroku dynos
  end

  def prepare_application
    remote_instance = heroku "config:get INSTANCE"
    unless remote_instance == application
      logger.warn "Setting INSTANCE config at remote to #{application}"
      heroku "config:set INSTANCE=#{application}"
    end
  end

  def deploy_application
    sys! "git push #{application} master"
    logger.warn "Deployed", application
  end

  def heroku(cmd)
    sys! "heroku #{cmd} --app #{application}"
  end

  def sys(cmd)
    logger.debug cmd
    stdout = Kernel.send "`", "bash -c \"#{cmd}\""
    
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
