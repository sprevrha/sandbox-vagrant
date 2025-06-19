# Makefile for setting up a Vagrant 

# environment with a specific box and provisioning script
install_vbguest_plugin:
	@vagrant plugin list | findstr vagrant-vbguest >nul || vagrant plugin install vagrant-vbguest

install_vbguest_to_vm: vagrant_fix install_vbguest_plugin

	@echo "Installing vagrant-vbguest plugin to VM..."
	vagrant vbguest --do install --auto-reboot
# force the plugin to attempt the vbguest upgrade and reboot the VM if needed.
	vagrant vbguest --do install --auto-reboot
	
box_update: 
	vagrant box update

vagrant_fix: install_vbguest_plugin
	@echo "Fixing Vagrant guest additions..."
	bash fix_vagrant.sh
# Target to run vagrant up after installation
vagrant_up_basic: box_update 
	@echo "Starting Vagrant basic environment..."
	vagrant up --provision

vagrant_up: vagrant_up_basic
	@echo "Waiting 60 for the reboot to finish"
	sleep 60
	@echo "Starting vagrant final provision"
	vagrant reload --provision
# Define the all target
all: vagrant_up install_vbguest_to_vm

# Clean up Vagrant environment
clean:
	@echo "Cleaning up Vagrant environment..."
	vagrant destroy -f
	@echo "Vagrant environment cleaned up."

.PHONY:  vagrant_up all clean install_vbguest box_update
.DEFAULT_GOAL := all
