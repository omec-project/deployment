#!/bin/bash 
USER="ubuntu" 
echo "**************Prerequsite Test***********************"
echo "Ansible"
echo "-------------------"

if if ! type -P  ansible-playbook > /dev/null; then
	echo "Installing ansible"
	apt-get --assume-yes install ansible
fi
