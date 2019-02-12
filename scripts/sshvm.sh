#!/usr/bin/env bash
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


login=$1
vmname=$2

#vmlist=($(virsh net-dhcp-leases default | grep "ipv4" | awk '{ print $6; }'))
vmlist=($(virsh list --name))

if [ "$vmname" == "" ]
then
  echo use: $0 \<login\> \<domain\>
  echo use a domain in: ${vmlist[*]}
  exit 1
fi

if ./get_vm_ip.sh $vmname
then
  ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /home/$1/.ssh/id_rsa $login@$(./get_vm_ip.sh $vmname)
else
  echo domain \"$vmname\" not found
  echo use a domain in: ${vmlist[*]}
fi
