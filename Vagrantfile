## Vagrantfile for setting up a VM with
# Docker, Git, and Docker Compose.
# It will then clone a specified Git repository and start the Docker containers defined in a docker-compose.yml file.
guest_port = ENV["GUEST_PORT"] || 80
host_port = ENV["HOST_PORT"] || 8090
guest_port_ssl = ENV["GUEST_PORT"] || 443
host_port_ssl = ENV["HOST_PORT"] || 8443
host_name = ENV["HOST_NAME"] || "sandbox-vagrant"
box_name = ENV["BOX_NAME"] || "ubuntu/jammy64"
code_name = ENV["CODE_NAME"] || "jammy"
branch = ENV["BRANCH"] || "main"
install_dir = ENV["INSTALL_DIR"] || "/opt/sandbox-vagrant-#{branch}"
sync_method = ENV['VAGRANT_SYNC_METHOD'] || 'git_pull' # alt: 'rsync'
sync_method = 'rsync'
repo_url = ENV['REPO_URL'] || "https://github.com/sprevrha/sandbox-vagrant.git"

Vagrant.configure("2") do |config|
  config.vm.box = box_name
  config.vm.network "forwarded_port", guest: guest_port.to_i, host: host_port.to_i
  config.vm.network "forwarded_port", guest: guest_port_ssl.to_i, host: host_port_ssl.to_i
  config.vm.hostname = host_name
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.cpus = 2
  end

    # Default to 'rsync' if not specified, or change to 'git_pull'
  

  # Map common log directories from the VM to a 'logs' folder on your host
  config.vm.synced_folder "./logs/vm_system_logs", "/var/log"

  if sync_method == 'rsync'
    # Rsync for your project root (e.g., where your Vagrantfile and docker-compose.yml are)
    # This assumes your project code is on the host in the same directory as Vagrantfile
    config.vm.synced_folder ".", install_dir, type: "rsync",
      rsync__args: ["--exclude=.git/", "--exclude=.vagrant/", "--exclude=Vagrantfile",
                    "--exclude=node_modules/", "--exclude=logs/", "--exclude=secrets/",], # Exclude common dev files
      rsync__auto: true # Automatically syncs changes from host to guest
  end

  # Provisioner to detect and export ARCH globally
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
  config.vbguest.auto_update = false
  config.vm.provision "kernel",
  run: "once",
  preserve_order: true,
  type: "shell",
  inline: <<-SHELL
    set -e
    # Retrieve the ARCH from the file created by the 'detect-arch' provisioner
    ARCH=$(cat /etc/vagrant_guest_arch)
    echo "Using detected architecture: $ARCH"

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
      fi
    fi
    # Reboot maybe necessary to switch to new kernel
    if [ -f /var/run/reboot-required ]; then
      echo "Reboot"
      sudo reboot
    fi
  # Rebooting stops the provisioner running, so we need to run the rest of the provisioning after a reload
  SHELL

  config.vm.provision "essentials", preserve_order: true, run: "always", type: "shell", inline: <<-SHELL
    set -e
    echo "Installing Essentials"
    echo "Installing build-essential and dkms..."
    sudo apt-get install -y build-essential dkms

    # NTP time synchronization
    sudo apt-get install -y systemd-timesyncd
    sudo systemctl enable systemd-timesyncd
    sudo systemctl start systemd-timesyncd     
    sudo timedatectl set-ntp true # Force an immediate time sync
    TZ="Europe/Berlin"
    echo "Set time zone to $TZ"
    sudo timedatectl set-timezone "$TZ"
    sudo dpkg-reconfigure -f noninteractive tzdata

  SHELL

  config.vm.provision "docker", preserve_order: true, run: "always", 
  type: "shell",
  inline: <<-SHELL
    set -e
    ARCH=$(cat /etc/vagrant_guest_arch)
    echo "Installing security essentials"
    sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https
    echo "Remove any old Docker key"
    sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
    echo "Download and install the new Docker GPG key"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "Add the Docker repository to the sources list using the signed-by option"
    # The `architecture` variable here is a Vagrant internal variable, which is distinct from the shell `ARCH`
    echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu #{code_name} stable" | \

      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Update the package index and upgrade existing packages"
    sudo apt-get update && sudo apt-get upgrade -y

    echo "Install docker"
    sudo apt-get install -y \
      git \
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

  config.vm.provision "git", preserve_order: true, run: "always",
  type: "shell",
  inline: <<-SHELL
    set -e
    if "#{sync_method}" == "git_pull"; then
      echo "Installing Git..."
      sudo apt-get install -y git
      echo "Verify that Git is installed correctly..."
      if ! command -v git >/dev/null 2>&1; then
        echo "failed."
        exit 1
      fi
      echo "Installed correctly"
    else
      echo "Skipping Git installation as sync method is not 'git_pull'."
    fi
  SHELL

  # Third provisioner: clone or pull the Git repository
  config.vm.provision "my-repo", run: "always", preserve_order: true,
  type: "shell",
  inline: <<-SHELL
    if "#{sync_method}" == "git_pull"; then
      echo "Sync method is 'git_pull'. Proceeding with Git operations."
      echo "Clone or pull branch #{branch} from Git repository #{repo_url}"
      TARGET_DIR="#{install_dir}"
      if git ls-remote --exit-code --heads "#{repo_url}" "#{branch}" >/dev/null 2>&1; then
        if [ ! -d "$TARGET_DIR" ]; then
          git clone -b "#{branch}" "#{repo_url}" "$TARGET_DIR"
        elif [ -d "$TARGET_DIR/.git" ]; then
          echo "Directory $TARGET_DIR exists and is a git repository. Pulling latest changes..."
          cd "$TARGET_DIR"
          git pull origin "#{branch}"
        else
          echo "ERROR: $TARGET_DIR exists but is not a git repository." >&2
          exit 1
        fi
      else
        echo "ERROR: Repository or branch does not exist: #{repo_url} (#{branch})" >&2
        exit 1
      fi
      sudo chown -R vagrant:vagrant $TARGET_DIR
    else
      echo "Sync method is not 'git_pull'. Skipping Git operations."
    fi
  SHELL

  # Fourth provisioner: start docker containers using docker-compose
  config.vm.provision "docker-up", run: "always", preserve_order: true,
  type: "shell",
  inline: <<-SHELL
    TARGET_DIR="#{install_dir}"
    echo "Ensure the docker-compose.yml file is present"
    cd $TARGET_DIR
    if [ ! -f docker-compose.yml ]; then
      echo "docker-compose.yml not found in $TARGET_DIR. Exiting."
      exit 1
    fi
    echo "Start the Docker containers (using Compose v2 plugin)"
    sudo docker compose up -d
    if [ $? -ne 0 ]; then
      echo "Failed to start Docker containers. Exiting."
      exit 1
    fi
    echo "Docker containers started successfully."
  SHELL

  # Final provisioner: cleanup and finish
  config.vm.provision "cleanup", run: "always", preserve_order: true,
  type: "shell",
  inline: <<-SHELL
    echo "Cleaning up..."
    sudo apt-get autoremove -y
    sudo apt-get clean
    echo "Provisioning complete."
  SHELL

end