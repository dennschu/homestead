class Homestead
  def Homestead.configure(config, settings, projectRootPath)
    # Set The VM Provider
    ENV['VAGRANT_DEFAULT_PROVIDER'] = settings["provider"] ||= "virtualbox"

    # Configure Local Variable To Access Scripts From Remote Location
    scriptDir = File.dirname(__FILE__)

    # Load optionally local configuration
    local_config_path = File.expand_path( projectRootPath + '/Homestead-local.yaml')
    local_config = ( File.exists? local_config_path ) ? YAML::load(File.read( local_config_path )) : Hash.new

    # Prevent TTY Errors
    config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"

    # Allow SSH Agent Forward from The Box
    config.ssh.forward_agent = true

    # Configure The Box
    config.vm.box = settings["box"] ||= "laravel/homestead"
    config.vm.box_version = settings["version"] ||= ">= 0"
    config.vm.hostname = settings["hostname"] ||= "homestead"

    # Configure A Private Network IP
    config.vm.network :private_network, ip: settings["ip"] ||= "192.168.10.22"

    # Configure Additional Networks
    if settings.has_key?("networks")
      settings["networks"].each do |network|
        config.vm.network network["type"], ip: network["ip"], bridge: network["bridge"] ||= nil
      end
    end

    # Configure A Few VirtualBox Settings
    config.vm.provider "virtualbox" do |vb|
      vb.name = settings["name"] ||= "homestead-7"
      vb.customize ["modifyvm", :id, "--memory", settings["memory"] ||= "2048"]
      vb.customize ["modifyvm", :id, "--cpus", settings["cpus"] ||= "2"]
      vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize ["modifyvm", :id, "--ostype", "Ubuntu_64"]
    end

    # Configure A Few VMware Settings
    ["vmware_fusion", "vmware_workstation"].each do |vmware|
      config.vm.provider vmware do |v|
        v.vmx["displayName"] = "homestead"
        v.vmx["memsize"] = settings["memory"] ||= 2048
        v.vmx["numvcpus"] = settings["cpus"] ||= 1
        v.vmx["guestOS"] = "ubuntu-64"
      end
    end

    # Configure A Few Parallels Settings
    config.vm.provider "parallels" do |v|
      v.update_guest_tools = true
      v.memory = settings["memory"] ||= 2048
      v.cpus = settings["cpus"] ||= 1
    end

    # Standardize Ports Naming Schema
    if (settings.has_key?("ports"))
      settings["ports"].each do |port|
        port["guest"] ||= port["to"]
        port["host"] ||= port["send"]
        port["protocol"] ||= "tcp"
      end
    else
      settings["ports"] = []
    end

    # Default Port Forwarding
    default_ports = {
      80   => 8000,
      443  => 44300,
      3306 => 33060,
      5432 => 54320
    }

    # Use Default Port Forwarding Unless Overridden
    default_ports.each do |guest, host|
      unless settings["ports"].any? { |mapping| mapping["guest"] == guest }
        config.vm.network "forwarded_port", guest: guest, host: host, auto_correct: true
      end
    end

    # Add Custom Ports From Configuration
    if settings.has_key?("ports")
      settings["ports"].each do |port|
        config.vm.network "forwarded_port", guest: port["guest"], host: port["host"], protocol: port["protocol"], auto_correct: true
      end
    end

    # Configure The Public Key For SSH Access
    if settings.include? 'authorize'
      # @todo iterate over public keys when of type array
      if File.exists? File.expand_path(settings["authorize"])
        config.vm.provision "shell" do |s|
          s.inline = "echo $1 | grep -xq \"$1\" /home/vagrant/.ssh/authorized_keys || echo $1 | tee -a /home/vagrant/.ssh/authorized_keys"
          s.args = [File.read(File.expand_path(settings["authorize"]))]
        end
      end
    end

    # Copy The SSH Private Keys To The Box
    if settings.include? 'keys'
      settings["keys"].each do |key|
        # @todo check for private key existence
        config.vm.provision "shell" do |s|
          s.privileged = false
          s.inline = "echo \"$1\" > /home/vagrant/.ssh/$2 && chmod 600 /home/vagrant/.ssh/$2"
          s.args = [File.read(File.expand_path(key)), key.split('/').last]
        end
      end
    end

    # Register All Of The Configured Shared Folders
    if settings.include? 'folders'
      settings["folders"].each_with_index do |folder, index|
        mount_opts = []

        if (folder["type"] == "nfs")
            mount_opts = folder["mount_options"] ? folder["mount_options"] : ['actimeo=1']
        end

        # For b/w compatibility keep separate 'mount_opts', but merge with options
        options = (folder["options"] || {}).merge({ mount_options: mount_opts })

        # Double-splat (**) operator only works with symbol keys, so convert
        options.keys.each{|k| options[k.to_sym] = options.delete(k) }

        # When "vagrant-bindfs" is available and folder type is nfs apply bindfs
        if folder["type"] == "nfs" and Vagrant.has_plugin?("vagrant-bindfs")
          config.vm.synced_folder folder["map"], "/mnt/vagrant-#{index}", type: folder["type"] ||= nil, **options
          config.bindfs.bind_folder "/mnt/vagrant-#{index}", "#{folder['to']}", owner: folder["bindfs"]["owner"], group: folder["bindfs"]["group"], perms: "#{folder["bindfs"]["permissions"]}"
        else
          config.vm.synced_folder folder["map"], folder["to"], type: folder["type"] ||= nil, **options
        end
      end
    end

    # Disable "vagrant-vbguest" plugins auto update
    # @see https://github.com/laravel/framework/issues/11439
    if Vagrant.has_plugin?("vagrant-vbguest")
      config.vbguest.auto_update = false
    end

    # Install All The Configured Nginx Sites
    config.vm.provision "shell" do |s|
        s.path = scriptDir + "/clear-nginx.sh"
    end

    settings["sites"].each do |site|
      type = site["type"] ||= "laravel"

      if (site.has_key?("hhvm") && site["hhvm"])
        type = "hhvm"
      end

      if (type == "symfony")
        type = "symfony2"
      end

      config.vm.provision "shell" do |s|
        s.path = scriptDir + "/serve-#{type}.sh"
        s.args = [site["map"], site["to"], site["port"] ||= "80", site["ssl"] ||= "443"]
      end

      # Configure The Cron Schedule
      if (site.has_key?("schedule"))
        config.vm.provision "shell" do |s|
          if (site["schedule"])
            s.path = scriptDir + "/cron-schedule.sh"
            s.args = [site["map"].tr('^A-Za-z0-9', ''), site["to"]]
          else
            s.inline = "rm -f /etc/cron.d/$1"
            s.args = [site["map"].tr('^A-Za-z0-9', '')]
          end
        end
      end

    end

    # Configure All Of The Configured Databases
    if settings.has_key?("databases")
        settings["databases"].each do |db|
          config.vm.provision "shell" do |s|
            s.path = scriptDir + "/create-mysql.sh"
            s.args = [db]
          end

          config.vm.provision "shell" do |s|
            s.path = scriptDir + "/create-postgres.sh"
            s.args = [db]
          end
        end
    end

    # Configure All Of The Server Environment Variables
    config.vm.provision "shell" do |s|
        s.path = scriptDir + "/clear-variables.sh"
    end

    if settings.has_key?("variables")
      settings["variables"].each do |var|
        config.vm.provision "shell" do |s|
          s.inline = "echo \"\nenv[$1] = '$2'\" >> /etc/php/7.0/fpm/php-fpm.conf"
          s.args = [var["key"], var["value"]]
        end

        config.vm.provision "shell" do |s|
            s.inline = "echo \"\n# Set Homestead Environment Variable\nexport $1=$2\" >> /home/vagrant/.profile"
            s.args = [var["key"], var["value"]]
        end
      end

      config.vm.provision "shell" do |s|
        s.inline = "service php7.0-fpm restart"
      end
    end

    # Update Composer On Every Provision
    config.vm.provision "shell" do |s|
      s.inline = "/usr/local/bin/composer self-update"
    end

    # Configure Blackfire.io
    if settings.has_key?("blackfire")
      config.vm.provision "shell" do |s|
        s.path = scriptDir + "/blackfire.sh"
        s.args = [
          settings["blackfire"][0]["id"],
          settings["blackfire"][0]["token"],
          settings["blackfire"][0]["client-id"],
          settings["blackfire"][0]["client-token"]
        ]
      end
    end

    # Install & Configure php xdebug
    if File.exists? scriptDir + "/xdebug/xdebug-install.sh"
      config.vm.provision "shell" do |s|
          s.path = scriptDir + "/xdebug/xdebug-install.sh"
      end
    end

    # Configure xdebug
    if File.exists? scriptDir + "/xdebug/xdebug-enable.sh" and local_config.include? 'xdebug'
      config.vm.provision "shell" do |s|
          debugMode = false
          s.path = scriptDir + "/xdebug/xdebug-enable.sh"
          s.args = [
            local_config["xdebug"]["fpm"]["enabled"].to_s,
            local_config["xdebug"]["cli"]["enabled"].to_s,
            debugMode.to_s
          ]
      end
    end

    # Configure xdebug profiler
    if File.exists? scriptDir + "/xdebug/xdebug-enable.sh" and local_config.include? 'xdebug'
      xdebug = local_config["xdebug"]
      profiler = local_config["xdebug"]["profiler"]

      if profiler["enabled"] == true and ( xdebug["fpm"]["enabled"] == false or xdebug["fpm"]["enabled"] == false )
        xdebug_fpm = xdebug["fpm"]["enabled"] ? "enabled": "disabled"
        xdebug_cli = xdebug["cli"]["enabled"] ? "enabled": "disabled"

        info_message = [
            "xdebug profiler may not work as expected because",
            ["  ", "xdebug for fpm is:", xdebug_fpm].join(" "),
            ["  ", "xdebug for cli is:", xdebug_cli].join(" ")
        ].join("\n")

        config.vm.provision "shell" do |s|
            s.inline = "echo -e \"\e[31m ${1} \e[39m\""
            s.args = [ info_message ]
        end
      end

      if File.exists? scriptDir + "/xdebug/xdebug-profiler-enable.sh"
        config.vm.provision "shell" do |s|
            debugMode = false
            s.path = scriptDir + "/xdebug/xdebug-profiler-enable.sh"
            s.args = [
              local_config["xdebug"]["profiler"]["enabled"].to_s,
              local_config["xdebug"]["profiler"]["enabled"].to_s,
              local_config["xdebug"]["profiler"]["logs"]["path"],
              local_config["xdebug"]["profiler"]["logs"]["filename"],
              debugMode.to_s
            ]
        end
      end
    end

    # Install nano code highlighting
    if File.exists? scriptDir + "/nano/ubuntu1404_add-nano-code-highlighting.sh" then
      config.vm.provision "shell" do |s|
        debugMode = false
        s.path = scriptDir + "/nano/ubuntu1404_add-nano-code-highlighting.sh"
        s.args = [ "vagrant", debugMode.to_s ]
      end
    end

  end
end
