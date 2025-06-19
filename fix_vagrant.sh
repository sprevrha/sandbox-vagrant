#! /bin/env/sh
echo "Updating Vagrant vbguest plugin code to be compatible with Ruby 3.2.0 and later:"
for pluginDirectory in `find ~/.vagrant.d/gems/ -name 'vagrant-vbguest'`; do
        pluginFile="$pluginDirectory/hosts/virtualbox.rb"
        echo "  $pluginFile"
        test -w "$pluginFile" || error "Could not access plugin code file '$pluginFile'" 1
        sed --in-place 's/File\.exists?/File\.exist?/g' $pluginFile
done