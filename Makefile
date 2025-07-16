# Makefile
# --- START .env file loading ---
# Include the make_env.mk file which defines the load_env_vars function
# Include the environment setup
# Include the environment setup
ifeq (.env,$(wildcard .env))
include make_env.mk
# Define empty and space variables in the main Makefile too, for consistency
empty :=
space := $(empty) $(empty)
# Call the function to load environment variables
$(eval $(call load_env_vars))
endif
# Optionally, export these variables to the environment
# $(info VAGRANT_SYNC_METHOD is set to '$(VAGRANT_SYNC_METHOD)')
export MAKE_DIR
export MAKE_DEBUG_OUTPUT
export VAGRANT_SYNC_METHOD

# Makefile for setting up a Vagrant environment with a specific box and provisioning script

vagrant_box_update: 
	vagrant box update

vagrant_provision_basic: vagrant_box_update vagrant_install_vagrant_plugins
	cd $(MAKE_DIR)
	@echo "----------------- Make: Building basic VM ..."
	vagrant up --provision-with "detect-arch","kernel","time-sync" $(MAKE_DEBUG_OUTPUT)
	vagrant reload --provision-with "install-essentials" $(MAKE_DEBUG_OUTPUT)
	@echo "----------------- Make: Basic VM is up and running."

vagrant_provision_tools: vagrant_provision_basic vagrant_install_vbguest_to_vm
	cd $(MAKE_DIR)
	@echo "----------------- Make: Starting tools provision ..."
	vagrant provision --provision-with "install-docker","install-git","directories" $(MAKE_DEBUG_OUTPUT)
	@echo "----------------- Make: tools provisioned"

vagrant_provision_my_code: vagrant_provision_tools .load_my_code
	@echo "----------------- Make: Provisioning code..."
	@echo "----------------- Make: Provisioned code."

.load_my_code: 
	cd $(MAKE_DIR)
	@echo "----------------- Make: Loading code"
	@if [ "$(VAGRANT_SYNC_METHOD)" = "rsync" ]; then \
		echo "----------------- Make: ... Sync method is rsync. Running vagrant rsync..."; \
		vagrant rsync $(MAKE_DEBUG_OUTPUT); \
		vagrant provision --provision-with "file" $(MAKE_DEBUG_OUTPUT); \
	elif [ "$(VAGRANT_SYNC_METHOD)" = "git_pull" ]; then \
		echo "----------------- Make: ... Sync method is git_pull. Running vagrant provision --provision-with 'install-my-code'..."; \
		vagrant provision --provision-with "git-pull","file" $(MAKE_DEBUG_OUTPUT); \
	else \
		echo "----------------- Make: ... Unknown VAGRANT_SYNC_METHOD: $(VAGRANT_SYNC_METHOD). Skipping code sync."; \
		echo "----------------- Make: ... Please set VAGRANT_SYNC_METHOD to 'rsync' or 'git_pull' in your .env file."; \
	fi
	@echo "----------------- Make: Loaded code"

vagrant_up: vagrant_provision_my_code
	cd $(MAKE_DIR)
	@echo "----------------- Make: Starting Docker environment..."
	vagrant provision --provision-with "docker_compose","cleanup" $(MAKE_DEBUG_OUTPUT)

vagrant_reload: .load_my_code
	cd $(MAKE_DIR)
	@echo "----------------- Make: Loading code to VM and provisioning docker"
	vagrant reload --provision-with "docker_compose" $(MAKE_DEBUG_OUTPUT)
	@echo "----------------- Make: Vagrant environment reloaded."

all: vagrant_up 

vagrant_install_vbguest_to_vm:  vagrant_install_vagrant_plugins vagrant_provision_basic
	@echo "----------------- Make: Installing vagrant-vbguest plugin to VM..."
	@echo "----------------- Make: ... Updating Vagrant vbguest plugin code to be compatible with Ruby 3.2.0 and later:"
	bash fix_vagrant.sh $(MAKE_DEBUG_OUTPUT)
	@echo "----------------- Make: ... Installing vagrant-vbguest plugin to VM..."
	vagrant vbguest --do install --auto-reboot $(MAKE_DEBUG_OUTPUT)
	@echo "----------------- Make: Installed vagrant-vbguest plugin to VM."
	
vagrant_install_vagrant_plugins: 
	@echo "----------------- Make: Installing Vagrant plugins..."
	@vagrant plugin list | findstr vagrant-docker-compose >nul ||vagrant plugin install vagrant-docker-compose
	@vagrant plugin list | findstr vagrant-vbguest >nul || vagrant plugin install vagrant-vbguest
	@vagrant plugin list | findstr vagrant-reload >nul || vagrant plugin install vagrant-reload
	@vagrant plugin list | findstr vagrant-hostmanager >nul || vagrant plugin install vagrant-hostmanager
	@vagrant plugin list | findstr vagrant-cachier >nul || vagrant plugin install vagrant-cachier
	@vagrant plugin list | findstr vagrant-envbash >nul || vagrant plugin install vagrant-envbash
	@echo "----------------- Make: Installed Vagrant plugins"

clean:
	@echo "----------------- Make: Cleaning up Vagrant environment..."
	vagrant destroy -f
	@echo "----------------- Make: Vagrant environment cleaned up."

.PHONY:  vagrant_up_basic vagrant_up_tools vagrant_up vagrant_reload all clean install_vbguest_plugin install_vbguest box_update
.DEFAULT_GOAL := all
