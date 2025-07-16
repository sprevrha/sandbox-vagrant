## Vagrantfile for setting up a VM with
# Docker, Git, and Docker Compose.
# It will then clone a specified Git repository and start the Docker containers defined in a docker-compose.yml file.

unless  Vagrant.has_plugin?("vagrant-scp") && 
  Vagrant.has_plugin?("vagrant-docker-compose") && 
  Vagrant.has_plugin?("dotenv")
  # Install vagrant-docker-compose if not installed
  unless Vagrant.has_plugin?("vagrant-scp")
    system("vagrant plugin install vagrant-scp")
    puts "vagrant-scp plugin installed."
  end
  # Install vagrant-docker-compose if not installed
  unless Vagrant.has_plugin?("vagrant-docker-compose")
    system("vagrant plugin install vagrant-docker-compose")
    puts "vagrant-docker-compose plugin installed."
  end
  # Install vagrant-vm if not installed
  unless Vagrant.has_plugin?("dotenv")
    system("vagrant plugin install dotenv")
    puts "dotenv plugin installed."
  end
  puts "Dependencies installed, please try the command again."
  exit
end

require_relative './lib/browser_helper'
require 'pathname' 
require 'dotenv'
my_dotenv_file_path=ENV['DOTENVFILE'] || '.env'
unless File.exist?(my_dotenv_file_path)
  puts "ERROR: The .env file was not found at: #{my_dotenv_file_path}"
  puts "Please create this file and ensure it contains necessary environment variables."
  exit 1 
end
if ENV["VAGRANT_DEBUG"] == "1"
  puts "Reading env vars from #{my_dotenv_file_path}, overwrite: true"
end
Dotenv.load(my_dotenv_file_path, overwrite: true)
Vagrant.configure("2") do |config|

  # if ENV["VAGRANT_DEBUG"] == "1"
  #   puts "DEBUG:  Environment Variables known to Vagrantfile:"
  #   ENV.each do |key, value|
  #     puts "\t#{key}: #{value}"
  #   end
  # end
  config.vm.box = ENV["VAGRANT_BOX_NAME"] # Use a very common box for testing
  config.vm.network "forwarded_port", guest: ENV["VAGRANT_GUEST_HTTP_PORT"].to_i, host: ENV["VAGRANT_HOST_HTTP_PORT"].to_i
  config.vm.network "forwarded_port", guest: ENV["VAGRANT_GUEST_HTTPS_PORT"].to_i, host: ENV["VAGRANT_HOST_HTTPS_PORT"].to_i
  puts "Setting Host Name: #{ENV['VAGRANT_HOST_NAME']}"
  config.vm.hostname = ENV['VAGRANT_HOST_NAME']
  config.vm.provider ENV['VAGRANT_VM_PROVIDER'] do |vim|
    vim.memory = ENV['VAGRANT_VM_MEMORY']
    vim.cpus = ENV['VAGRANT_VM_CPUS']
  end
  config.vbguest.auto_update = false # We need to first update our box then trigger this manually
  # Enable hostmanager
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true # Add/remove host entries for the VM
  config.hostmanager.manage_guest = true # (Optional) Manage guest /etc/hosts for multi-VM setups
  # Define the hostname(s) for your VM
  config.hostmanager.aliases = ["www.#{ENV['VAGRANT_HOST_NAME']}"] # Add aliases if needed
  #  config.vm.network "private_network", ip: "192.168.33.10" # Example IP
  config.cache.scope = :box # cachier plugin - cashing per base box

# RSYNC - These will automatically run for vagrant reload and vagrant provision, but not with --provision-with 
  # To manually, trigger use vagrant rsync
  rsync__args = ["--verbose", "--archive", "--compress", "--delete",
    "--exclude=.*", "--exclude=logs",
    "--exclude=tmp", "--exclude=cache", 
    "--exclude=Vagrantfile"
  ]   
  # VS Code bug workaround - Construct the ENTIRE SSH command string as a single unit
  private_key_path_for_ssh = Pathname.new(Dir.pwd).join(
    ".vagrant", "machines", "default", "virtualbox", "private_key"
  ).to_s
  my_rsync_ssh_command__option_string = "-p #{ENV['VAGRANT_SSH_HOST_PORT']} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i '#{private_key_path_for_ssh}'"
  if ENV["VAGRANT_DEBUG"] == "1"
    puts "DEBUG: Rsync SSH command string content: ssh #{my_rsync_ssh_command__option_string.inspect}"
  end
  if ENV['VAGRANT_APPCODE_SYNC_METHOD'] == 'rsync'
    # ...
    config.vm.synced_folder ".", ENV['VAGRANT_VM_INSTALL_DIR'], type: "rsync",
      rsync__args: rsync__args,
      rsync__ssh_args: ["ssh #{my_rsync_ssh_command__option_string}"],
      rsync__auto: true
  else
    if ENV["VAGRANT_DEBUG"] == "1"
      puts "DEBUG: Not using rsync - will use git-pull provisioner"
    end  
  end
  # Also sync the logs
  config.vm.synced_folder "./logs/vm_system_logs", ENV['VAGRANT_VM_APP_LOG_DIR'], type: "rsync", create: true,
    mount_options: ["dmode=777", "fmode=666"],
    rsync__args: ["--verbose", "--archive", "--compress"],
    rsync__ssh_args: ["ssh #{my_rsync_ssh_command__option_string}"],
    rsync__auto: true

  # Start a Browser once the box is completely up
  app_url = "https://#{ENV['VAGRANT_HOST_NAME']}:#{ENV['VAGRANT_HOST_HTTPS_PORT']}"
  # Get the browser command using your helper module
  browser_command = BrowserHelper.get_browser_command(app_url, ENV['VAGRANT_HOST_BROWSER'])

  # Only add the trigger if up or reload
  unless browser_command.empty?
    config.trigger.after [:up, ] do
        puts "#{browser_command}"
        # system(browser_command)
    end
  end

  ##############
  # PROVISIONERS
  
  # Detect and export ARCH globally
  config.vm.provision "detect-arch",
    run: "once",
    preserve_order: true,
    type: "shell",
    inline: <<-SHELL
      set -e
      echo "Detecting guest architecture..."
      DETECTED_ARCH=$(uname -m)
      case "$DETECTED_ARCH" in
        x86_64)
          ARCH_TO_USE=amd64
          ;;
        aarch64)
          ARCH_TO_USE=arm64
          ;;
        i386|i686)
          ARCH_TO_USE=i386
          ;;
        armv7l)
          ARCH_TO_USE=armhf
          ;;
        armv6l)
          ARCH_TO_USE=armel
          ;;
        ppc64le)
          ARCH_TO_USE=ppc64el
          ;;
        *)
          echo "Unknown architecture: $DETECTED_ARCH" >&2
          exit 1
          ;;
      esac
      echo "Detected architecture: $ARCH_TO_USE"
      # Store the architecture in a file so subsequent provisioners can read it
      echo "$ARCH_TO_USE" | sudo tee /etc/vagrant_guest_arch
    SHELL

# First provisioner: ensure kernel and headers match
  # This will run before the VirtualBox Guest Additions are built.
  config.vm.provision "kernel",
  run: "once",
  preserve_order: true,
  type: "shell",
  inline: <<-SHELL
    set -e
    # Retrieve the ARCH from the file created by the 'detect-arch' provisioner
    ARCH=$(cat /etc/vagrant_guest_arch)
    echo "Using previously detected architecture: $ARCH"

    echo "Updating package list and ensuring kernel and headers match"
    sudo apt-get update
    sudo apt-get install -y zstd dpkg

    UPGRADED_KERNEL_VERSION=$(apt list --upgradable 2>/dev/null | grep linux-image | awk '{print $2}')
    if [ -n "$UPGRADED_KERNEL_VERSION" ]; then
      echo "Kernel image is upgradable to version $UPGRADED_KERNEL_VERSION. Proceeding with upgrade..."
      if grep -qi ubuntu /etc/os-release; then
        echo "Detected Ubuntu. Installing linux-image-generic, linux-headers-generic..."
        if sudo apt-get install -y linux-image-generic linux-headers-generic; then
          echo "Successfully installed linux-image-generic and linux-headers-generic"
        else
          echo "Failed to install linux-image-generic and linux-headers-generic"
          exit 1
        fi
      else
        echo "Not Ubuntu. Assuming Debian."
        echo "Debian architecture detected: $ARCH. Attempting to install linux-image-$ARCH and linux-headers-$ARCH..."
        if sudo apt-get install -y linux-image-$ARCH linux-headers-$ARCH; then
          echo "Successfully installed linux-image-$ARCH and linux-headers-$ARCH"
        else
          echo "Failed to install linux-image-$ARCH and linux-headers-$ARCH. Please check your package manager configuration."
          exit 1
        fi
      fi
    else
      KERNEL_VERSION=$(uname -r)
      echo "Kernel $KERNEL_VERSION is up to date. Checking on Headers..."
      # Check if the correct kernel headers are installed
      if ! dpkg -l | grep -q "linux-headers-$KERNEL_VERSION"; then
        echo "Matching kernel headers not found, installing..."

        if sudo apt-get install -y linux-headers-$KERNEL_VERSION; then
          echo "Successfully installed linux-headers-$KERNEL_VERSION"
        else
          echo "Exact kernel headers not found in distro. Trying distro-specific fallback..."
          if grep -qi ubuntu /etc/os-release; then
            echo "Installing linux-headers-generic..."
            if sudo apt-get install -y linux-headers-generic; then
              echo "Successfully installed linux-headers-generic"
            else
              echo "Failed to install linux-headers-generic"
              exit 1
            fi
          else
            echo "Assuming Debian."
            echo "Attempting to install linux-headers-$ARCH..."
            if sudo apt-get install -y linux-headers-$ARCH; then
              echo "Successfully installed linux-headers-$ARCH"
            else
              echo "Failed to install linux-headers-$ARCH. Please check your package manager configuration."
              exit 1
            fi
          fi
        fi
      else
        echo "Matching kernel headers found."
      fi
    fi
    # Reboot maybe necessary to switch to new kernel
    if [ -f /var/run/reboot-required ]; then
      echo "Rebooting now"
      sudo reboot
    fi
  # Rebooting stops the provisioner running, so we need to run the rest of the provisioning after a reload
  SHELL

  config.vm.provision "time-sync", 
    run: "once",
    preserve_order: true, 
    type: "shell", 
    inline: <<-SHELL
      set -e
      echo "NTP time synchronization"
      sudo apt-get install -y systemd-timesyncd
      sudo systemctl enable systemd-timesyncd
      sudo systemctl start systemd-timesyncd     
      sudo timedatectl set-ntp true # Force an immediate time sync
      echo "Set time zone to #{ENV['VAGRANT_VM_TIMEZONE']}"
      sudo timedatectl set-timezone "#{ENV['VAGRANT_VM_TIMEZONE']}"
      sudo dpkg-reconfigure -f noninteractive tzdata
    SHELL

  config.vm.provision "install-essentials", 
    run: "once",
    preserve_order: true, 
    type: "shell", 
    inline: <<-SHELL
      set -e
      echo "Installing Essentials"
      sudo apt-get install -y build-essential dkms
  SHELL

  config.vm.provision "install-docker", 
    run: "once",
    preserve_order: true,  
    type: "shell",
    inline: <<-SHELL
      set -e
      ARCH=$(cat /etc/vagrant_guest_arch)
      echo "Installing security essentials"
      sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https
      echo "Remove any old Docker key"
      sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
      echo "Download and install the new Docker GPG key"
      curl -fsSL #{ENV['DOCKER_DOWNLOAD_URL']}/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      echo "Add the Docker repository to the sources list using the signed-by option"
      echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] #{ENV['DOCKER_DOWNLOAD_URL']} #{ENV['VAGRANT_OS_RELEASE']} stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      echo "Update the package index and upgrade existing packages"
      sudo apt-get update && sudo apt-get upgrade -y

      echo "Install docker"
      sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-compose-plugin

      echo "Verify that Docker is installed correctly"
      if ! command -v docker >/dev/null 2>&1; then
        echo "Docker installation failed."
        exit 1
      fi
      echo "Installed correctly"

      echo "Verify that Docker Compose v2 is installed correctly..."
      if ! docker compose version 2>&1 | grep -q 'Docker Compose version'; then
        echo "failed."
        exit 1
      fi
      echo "Installed correctly"

      echo "Add the vagrant user to the docker group"
      sudo usermod -aG docker vagrant

      echo "Enable and start Docker"
      sudo systemctl enable docker
      sudo systemctl start docker
    SHELL

  config.vm.provision "install-git", 
    run: "once",
    preserve_order: true, 
    type: "shell",
    inline: <<-SHELL
      set -e
      echo "Installing Git..."
      sudo apt-get install -y git
      echo "Verify that Git is installed correctly..."
      if ! command -v git >/dev/null 2>&1; then
        echo "failed."
        exit 1
      fi
      echo "Installed correctly"
    SHELL

  # Ensure the install directory exists
  config.vm.provision "directories", 
    run: "once", 
    preserve_order: true,
    type: "shell", 
    inline: <<-SHELL
      set -e
      sudo mkdir -p #{ENV['VAGRANT_APPCODE_DIR']}
      sudo mkdir -p #{ENV['VAGRANT_APPCONF_DIR']}
  SHELL

  config.vm.provision "git-pull",
  run: "always",
  preserve_order: true,
  type: "shell",
  inline: <<-SHELL
    set -e 
    echo "Method is #{ENV['VAGRANT_APPCODE_SYNC_METHOD']}"
    if [ "#{ENV['VAGRANT_APPCODE_SYNC_METHOD']}" = "git-pull" ]; then
      INSTALL_DIR="#{ENV['VAGRANT_APPCODE_DIR']}"
      GIT_REPO_URL="#{ENV['GIT_REPO_URL']}"
      GIT_BRANCH="#{ENV['GIT_BRANCH']}"

      echo "Sync method is 'git-pull'. Proceeding with Git operations."
      echo "Target branch: ${GIT_BRANCH} from repository: ${GIT_REPO_URL}"

      # Check if the branch actually exists on the remote
      if ! git ls-remote --exit-code --heads "${GIT_REPO_URL}" "${GIT_BRANCH}" >/dev/null 2>&1; then
        echo "ERROR: Repository '${GIT_REPO_URL}' or branch '${GIT_BRANCH}' does not exist remotely." >&2
        exit 1
      fi

      # --- Logic for existing vs. new repository ---
      if [ ! -d "${INSTALL_DIR}" ]; then
        # Directory does not exist, perform initial clone
        echo "Directory '${INSTALL_DIR}' does not exist. Cloning repository..."
        git clone -b "${GIT_BRANCH}" "${GIT_REPO_URL}" "${INSTALL_DIR}"
      elif [ -d "${INSTALL_DIR}/.git" ]; then
        # Directory exists and is a git repository, perform pull/checkout
        echo "Directory '${INSTALL_DIR}' exists and is a Git repository. Ensuring correct branch and pulling updates..."
        cd "${INSTALL_DIR}"

        # Fetch all remote branches and tags
        git fetch origin

        # Get the currently checked out local branch
        CURRENT_LOCAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)

        if [ "${CURRENT_LOCAL_BRANCH}" != "${GIT_BRANCH}" ]; then
          # Branch has changed, or we're on a detached HEAD, or we need to switch
          echo "Current branch is '${CURRENT_LOCAL_BRANCH}', desired branch is '${GIT_BRANCH}'."
          echo "Switching to branch '${GIT_BRANCH}'..."
          # '-B' creates the branch if it doesn't exist, or resets it if it does.
          # We check out from origin/branch to ensure it's up-to-date with remote.
          if git checkout -B "${GIT_BRANCH}" "origin/${GIT_BRANCH}"; then
            echo "Successfully switched to branch '${GIT_BRANCH}'."
            # After checkout, ensure the local branch matches the remote exactly (discarding local changes)
            git reset --hard "origin/${GIT_BRANCH}"
          else
            echo "ERROR: Failed to switch to branch '${GIT_BRANCH}'. This might indicate uncommitted local changes." >&2
            echo "Please resolve manually or use VAGRANT_SYNC_METHOD=rsync." >&2
            exit 1
          fi
        else
          # Already on the desired branch, just pull latest changes (hard reset to ensure exact match)
          echo "Already on branch '${GIT_BRANCH}'. Resetting to latest remote state..."
          git reset --hard "origin/${GIT_BRANCH}"
        fi
      else
        # Directory exists but is NOT a git repository or is not empty
        if [ -d "${INSTALL_DIR}" ] && [ -z "$(find "${INSTALL_DIR}" -mindepth 1 -print -quit)" ]; then
          echo "The directory '${INSTALL_DIR}' is empty. Deleting and cloning."
          rm -rf "${INSTALL_DIR}"
          git clone -b "${GIT_BRANCH}" "${GIT_REPO_URL}" "${INSTALL_DIR}"
        else
          echo "ERROR: '${INSTALL_DIR}' exists but is not empty or a Git repository. Cannot clone." >&2
          exit 1
        fi
      fi

      # Ensure correct ownership after Git operations
      sudo chown -R vagrant:vagrant "${INSTALL_DIR}"

    else
      echo "Sync method is not 'git-pull', skipping Git operations."
      echo "You can set the sync method in your .env file using VAGRANT_APPCODE_SYNC_METHOD=git-pull or VAGRANT_APPCODE_SYNC_METHOD=rsync"
    fi
  SHELL

  dirs_to_copy = ENV['VAGRANT_EXTRA_DIRS_TO_COPY'].to_s.split(' ')
  dirs_to_copy.each do |dir|
      config.vm.provision "file", 
        run: "always", 
        preserve_order: true,
        source: dir, 
        destination: "#{ENV['VAGRANT_APPCONF_DIR']}/#{dir}"
  end
    # inline: <<-SHELL
    #   set -e

    #   IFS=' ' read -r -a dirs_array <<< "#{ENV['VAGRANT_EXTRA_DIRS_TO_COPY']}"
    #   for dir in "${dirs_array[@]}"; do
    #     echo "Copying $dir to #{ENV['VAGRANT_VM_INSTALL_DIR']}"
    #     scp #{my_rsync_ssh_command__option_string} -r "./$dir" vagrant@127.0.0.1:#{ENV['VAGRANT_VM_INSTALL_DIR']}
    # SHELL


end