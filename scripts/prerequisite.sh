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

USER="ubuntu" 
IMAGE_PATH="/opt/ubuntu-16.04-server-cloudimg-amd64-disk1.img"
TERRAFORM_BIN_PATH="/usr/local/bin/terraform"
download_dir="/opt"
echo "**************Prerequsite Test***********************"
echo "KVM pool validation: -"
echo "-------------------"
POOL_NAME=`virsh pool-list | grep  images | awk '{ print $1 }'`
POOL_STATUS=`virsh pool-list | grep  images | awk '{ print $2 }'`
if [  $POOL_NAME == "images"  -a  $POOL_STATUS == "active"  ] ; then 
	echo "$POOL_NAME pool already exist"
else 
	if [ -e "/var/lib/libvirt/images" ] ; then 
		virsh pool-define-as images --type dir --target /var/lib/libvirt/images
		virsh pool-autostart images
		virsh pool-start images 
	fi
fi

echo "User validation: -"
echo "---------------"
###User validation and creation of user not exist
if getent passwd $USER > /dev/null 2>&1; then 
	echo "$USER user already exist" 
else 
	useradd -d /home/$USER -m $USER
	mkdir /home/$USER/.ssh 
   	sudo -u $USER bash -c echo -e "\n\n\n" | ssh-keygen -t rsa -f /home/$USER/.ssh/id_rsa -q -N ""
	chown $USER:$USER -R /home/$USER/.ssh/
        echo "$USER has been created and ssh key generated"
#   sudo -u $USER bash -c cat /dev/zero | ssh-keygen -t rsa -f /home/$USER/.ssh/id_rsa -q -N ""
fi

##Download the ubuntu cloud image and terraform packages
echo "Downloading Packages:-" 
echo "---------------------" 
	if [ -e $IMAGE_PATH ] ; then 
		echo "Ubuntu cloud image already exist" 
	else
		echo "Downloding Ubuntu cloud image" 
  		wget https://cloud-images.ubuntu.com/releases/16.04/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img -P $download_dir
		qemu-img resize $IMAGE_PATH 16GB
	fi
	if [ -e $TERRAFORM_BIN_PATH ]; then 
		echo "Terraform binary already present.." 
	else 
		echo "downloading terraform binary"
		apt-get install zip -y
		wget -qO- -O $download_dir/terraform.zip https://releases.hashicorp.com/terraform/0.11.7/terraform_0.11.7_linux_amd64.zip && unzip $download_dir/terraform.zip -d $download_dir && rm $download_dir/terraform.zip && mv $download_dir/terraform $TERRAFORM_BIN_PATH 
		#Verify terraform is installed succesfully
		terraform -version
		if [ $? -eq 0 ]; then
			echo "Terraform installed successfully."
		else
			echo "Terraform installation failed."
		fi
	fi
