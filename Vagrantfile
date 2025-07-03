## Vagrantfile for setting up a Debian VM with
# Docker, Git, and Docker Compose.
# It will also clone a specified Git repository and start the Docker containers defined in a docker-compose.yml file.
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
  config.vm.network "forwarded_port", guest: 8081, host: 8081
 end

   
  #  headers must be present before Guest Additions are built.
  config.vbguest.auto_update = false
  config.vm.provision "arch", 
  run: "once", 
  preserve_order: true,
  type: "shell", 
  inline: <<-SHELL
    # What architecture are we on? Needed for installing the headers
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64)
        ARCH=amd64
        ;;
      i386|i686)
        ARCH=i386
        ;;
      aarch64)
        ARCH=arm64
        ;;
      armv7l)
        ARCH=armhf
        ;;
      armv6l)
        ARCH=armel
        ;;
      ppc64le)
        ARCH=ppc64el
        ;;
      *)
        echo "Unknown architecture: $ARCH"
        exit 1
        ;;
    esac
    echo "Debian architecture: $ARCH"
    # Ensure kernel and headers match, reboot maybe necessary to switch to new kernel
    # zstd for better initial RAMFS compression  
    echo "Updating package list and ensuring kernel and headers match"
    sudo apt-get update
    sudo apt-get install -y linux-image-$ARCH linux-headers-$ARCH zstd
    if [ -f /var/run/reboot-required ]; then
      echo "Reboot"
      sudo reboot
    fi
  # Rebooting stops the provisioner running, so we need to run the rest of the provisioning after a reload
  SHELL
      
  # Second provisioner: everything else (will run after 'vagrant reload --provision')
  config.vm.provision "rest", run: "always", preserve_order: true,
  type: "shell", 
  inline: <<-SHELL
    # ... rest of your provisioning (Docker, Git, etc.) ...
    # Install required tools
    # build essentials, needed for the VB guest additions
    # curl gnupg lsb-release apt-transport-https to add the docker repo and GPG key
    echo "Installing Essentials"
    sudo apt-get install -y build-essential dkms
    sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https

    echo "Remove any old Docker key"
    sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
    echo "Download and install the new Docker GPG key"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "Add the Docker repository to the sources list using the signed-by option"
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu bionic stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Update the package index and upgrade existing packages"
    sudo apt-get update
    sudo apt-get -y upgrade

    echo "Install docker and git"
    sudo apt-get install -y \
      git \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-compose-plugin

    TZ="Europe/Berlin"
    echo "Set time zone to $TZ"
    echo "$TZ" | sudo tee /etc/timezone
    sudo dpkg-reconfigure -f noninteractive tzdata

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

    echo "Verify that Git is installed correctly..."
    if ! command -v git >/dev/null 2>&1; then
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

  # Third provisioner: clone or pull the Git repository 
  config.vm.provision "git-pull", run: "always", preserve_order: true,
  type: "shell", 
  env: { "BRANCH" => ENV["BRANCH"] || "main" }, # default to main branch if not set
  inline: <<-SHELL
    REPO_URL="https://github.com/sprevrha/sandbox-vagrant.git"
    echo "Clone or pull branch $BRANCH from Git repository $REPO_URL"
    TARGET_DIR="/opt/sandbox-vagrant-$BRANCH"
    if git ls-remote --exit-code --heads "$REPO_URL" "$BRANCH" >/dev/null 2>&1; then
      if [ ! -d "$TARGET_DIR" ]; then
        git clone -b "$BRANCH" "$REPO_URL" "$TARGET_DIR"
      elif [ -d "$TARGET_DIR/.git" ]; then
        echo "Directory $TARGET_DIR exists and is a git repository. Pulling latest changes..."
        cd "$TARGET_DIR"
        git pull origin "$BRANCH"
      else
        echo "ERROR: $TARGET_DIR exists but is not a git repository." >&2
        exit 1
      fi
    else
      echo "ERROR: Repository or branch does not exist: $REPO_URL ($BRANCH)" >&2
      exit 1
    fi
    sudo chown -R vagrant:vagrant /opt/sandbox-vagrant-$BRANCH
  SHELL

  # Fourth provisioner: start docker containers using docker-compose 
  config.vm.provision "docker-up", run: "always", preserve_order: true,
  env: { "BRANCH" => ENV["BRANCH"] || "main" }, # default to main branch if not set
  type: "shell", 
  inline: <<-SHELL
    TARGET_DIR="/opt/sandbox-vagrant-$BRANCH"
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