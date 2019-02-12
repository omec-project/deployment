#!/bin/bash
#
# Copyright (c) 2003-2018, Great Software Laboratory Pvt. Ltd.
# Copyright (c) 2017 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
TERRAFORM_DIR=${PWD}/terraform
TF_STATE_FILE="$TERRAFORM_DIR/terraform.tfstate"
export TF_LOG_PATH="/var/log/terraform.log"
export TF_LOG="DEBUG"
GIT_USER=$1
GIT_PASS=$2
ANSIBLE_HOME="${PWD}/ansible"
HOST_FILE="/etc/hosts"
ANSIBLE_INV="$ANSIBLE_HOME/inventory"

pushd $TERRAFORM_DIR/scripts

#deleting existing ansible inventory file
rm -rf $ANSIBLE_INV

# Parse the input.cfg and generated the terrafrom variable (output.tfvars) file
python parse_ini_input.py

popd

pushd  $TERRAFORM_DIR
# Terraform deploy
if [ -f $TF_STATE_FILE ] ; then
	echo "Terraform state file exist, again not required terraform initialization."
else
	terraform init
fi

terraform apply -auto-approve --var-file=input.tfvars --var-file=network_map.tfvars
if [ $? -eq 0 ]; then
	echo "VM installation has been done successfully"
else
	echo "some vms are installed with errors"
fi

#updating the hosts file for vm ip details
VM_NAME=($(virsh list |awk '{print $2}' |sed 1,2d |sed '$d'))
for i in ${VM_NAME[@]}
do
	for vm_ip in `virsh domifaddr $i |grep ipv4 |awk '{print $4}' |cut -d '/' -f1`
	do
		cat $HOST_FILE |grep $i > /dev/null 2>&1
                if [ $? -eq 0 ] ; then
			sed -i.bak.`date "+%d%m%Y-%H%M"` "/$i/d" $HOST_FILE
			echo "$vm_ip	$i" >> $HOST_FILE
		else
			echo "$vm_ip	$i" >> $HOST_FILE
		fi
#Generate the ansible inventory file
		echo -e "[$i]\n$vm_ip" >> $ANSIBLE_INV
        done
done
cat $ANSIBLE_INV |grep sgx 1> /dev/null
if [ $? -ne 0 ]; then
   cat $ANSIBLE_HOME/sgx_inv >> $ANSIBLE_INV
fi
echo "Hosts file has been updated successfully"
echo "Ansible inventory file has been updated successfully"
popd
#change to ansible home directory and execute ansible-playbook to configure the vm's.
pushd $ANSIBLE_HOME
#########################################################
# VM Configuration through ansible
#########################################################
#/usr/bin/ansible-playbook -i inventory  site.yml -u ubuntu -e 'ansible_python_interpreter=/usr/bin/python3' -e githubuser="$GIT_USER" -e githubpassword="$GIT_PASS"
/usr/bin/ansible-playbook -i inventory  site.yml -u ubuntu -e 'ansible_python_interpreter=/usr/bin/python3'
popd
