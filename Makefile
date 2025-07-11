VAGRANT_DIR=.

# Makefile for setting up a Vagrant environment with a specific box and provisioning script
install_vbguest_plugin:
	@vagrant plugin list | findstr vagrant-vbguest >nul || vagrant plugin install vagrant-vbguest

install_vbguest_to_vm: install_vbguest_plugin
	@echo "Updating Vagrant vbguest plugin code to be compatible with Ruby 3.2.0 and later:"
	bash fix_vagrant.sh
	@echo "Installing vagrant-vbguest plugin to VM..."
	vagrant vbguest --do install --auto-reboot
	
box_update: 
	vagrant box update

vagrant_up_basic: box_update 
	cd $(VAGRANT_DIR)
	@echo "Starting Vagrant basic environment..."
	vagrant up --provision-with "detect-arch","kernel"
	vagrant reload --provision-with "essentials"
	@echo "Vagrant basic environment is up and running."

vagrant_up_final: vagrant_up_basic 
	cd $(VAGRANT_DIR)
	@echo "Starting vagrant final provision"
	vagrant provision --provision-with "docker","git","my-repo"

vagrant_up: vagrant_up_final
	cd $(VAGRANT_DIR)
	@echo "Starting Docker environment..."
	vagrant provision --provision-with "docker-up","cleanup"
# Define the all target
all: vagrant_up install_vbguest_to_vm

# Clean up Vagrant environment
clean:
	@echo "Cleaning up Vagrant environment..."
	vagrant destroy -f
	@echo "Vagrant environment cleaned up."

.PHONY:  vagrant_up all clean install_vbguest box_update
.DEFAULT_GOAL := all
