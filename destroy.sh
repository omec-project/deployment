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

export TF_LOG_PATH="/var/log/terraform.log"
export TF_LOG="DEBUG"
export PATH=$PATH:$TERRAFORM_DIR

source $TERRAFORM_DIR/c3povm_defs.cfg

pushd $TERRAFORM_DIR

# Terraform destroy
terraform destroy -auto-approve --var-file=input.tfvars --var-file=network_map.tfvars
if [ $? -ne 0 ]; then 
   echo "Terraform destory failed"
   exit 1 
fi
  
popd
rm -rf /var/lib/libvirt/images/*
sleep 3

VNF_INT="$CTRL_PFDEV $DP_CTRL_PFDEV"
for interface in ${VNF_INT}
do 
    echo 0 > /sys/class/net/$interface/device/sriov_numvfs
    echo "Virtual functions are deleted on interface: $interface" 
done
