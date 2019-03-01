#!/bin/bash 
USER="ubuntu" 
echo "**************Prerequsite Test***********************"
echo "Ansible"
echo "-------------------"

if ! type -P  ansible-playbook > /dev/null; then
	echo "Installing ansible"
        apt-add-repository ppa:ansible/ansible
        apt-get update
	apt-get --assume-yes install ansible
fi
