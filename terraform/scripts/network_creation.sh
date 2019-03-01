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

source lib/parseoptions.sh
source lib/ask2continue.sh

network_card_validation(){
echo "---------------------------------------------------------"
echo "Checking for NIC requirement  "
echo "---------------------------------------------------------"
TERRAFORM_VAR_IN_FILE="../input.tfvars"
NGIC_DEF_CFG="../c3povm_defs.cfg"
INPUT_CFG="../../c3po_ngic_input.cfg"
cp $NGIC_DEF_CFG.blank $NGIC_DEF_CFG
ip_list=`cat $INPUT_CFG |grep ^HOST_TYPE | grep '@' |cut -d '@' -f2 | cut -d '"' -f1`
for i in $ip_list
do

   temp_var=`ifconfig |grep -B1 $i | awk '{print $1 }' |grep -v inet`
   if [ ! -z $temp_var ] ; then
       mgmt_int=`ifconfig |grep -B1 $i | awk '{print $1 }' |grep -v inet`
   fi
done
echo "MGMT_INT=$mgmt_int"

IF_DEV_LIST_TMP=($(lshw -c network -businfo | grep -i '10GbE\|10-Gigabit' | awk '{print $2;}' |grep -v 'network'))
echo "Before : ${IF_DEV_LIST_TMP[@]}"
IF_DEV_LIST=(${IF_DEV_LIST_TMP[@]/$mgmt_int})
echo "After : ${IF_DEV_LIST[@]}"

for link in ${IF_DEV_LIST[@]}
do
   ifconfig $link up
   sleep 2
done

OPER_STATE=()
OPER_STATE_UP=()
OPER_STATE_UNUSED=()

#NUM_DEV_LIST=${#IF_DEV_LIST[@]}
if [ ${#IF_DEV_LIST[@]} -ge "2" ]; then
	cnt=0
	echo "Number of 10GB NICS available are greater than or equal to 2. We can go ahead and create virtual functions"
	for (( index=0; index<${#IF_DEV_LIST[@]}; index++ ))
    do
        STATE=($(cat /sys/class/net/${IF_DEV_LIST[$index]}/operstate 2> /dev/null ))
        if [ $STATE == "up" ]; then
        OPER_STATE[$cnt]=${IF_DEV_LIST[$index]}
            ip link show ${OPER_STATE[$cnt]} |grep -E "vf|MAC" 1> /tmp/a
            if [ $? -eq 0 ] ; then
                echo "Virtual functions are already created on  ${OPER_STATE[$cnt]}"
            else
                TEMP_STATE[$cnt]=${OPER_STATE[$cnt]}
                echo "Available interface for VF creation:  ${TEMP_STATE[$cnt]}"
            fi
                echo ${OPER_STATE_UP[@]}
                ((cnt++));
        fi
    done
fi
}

# calling network_card_validation function
network_card_validation
OPER_STATE_UP=(${TEMP_STATE[@]})
OPER_UP_LEN=${#OPER_STATE_UP[@]}

# Declare function for pci card value hex-decimal
pci_hex2decimal() {
	DP_PCI="$(cut -d':' -f2 <<< "$1")"
    DP_SLOT="$(cut -d':' -f3 <<< "$1")"
    DP_SLOT1="$(cut -d'.' -f1 <<< "$DP_SLOT")"
    DP_SLOT2="$(cut -d'.' -f2 <<< "$DP_SLOT")"
    DP_PCI=$(printf %d 0x$DP_PCI)
    echo "pci_0000_"$DP_PCI"_"$DP_SLOT1"_"$DP_SLOT2""
}

pci_addr_mapping() {
    IF_PCI_LIST=()
    for (( index=0; index<${#OPER_STATE_UP[@]}; index++ ))
    do
	IF_PCI_LIST+=($(lshw -c network -businfo| grep -i "${OPER_STATE_UP[$index]}" | awk '{print $1;}'))
    done
    echo ${IF_PCI_LIST[@]}
    PCI_LEN=${#IF_PCI_LIST[@]}
    PCI_LIST=()
    PCI_LIST_UNUSED=()

    for (( index=0; index<$PCI_LEN; index++ ))
    do
        DP_PCI="$(cut -d':' -f2 <<< "${IF_PCI_LIST[$index]}")"
        DP_SLOT="$(cut -d':' -f3 <<< "${IF_PCI_LIST[$index]}")"
        DP_SLOT1="$(cut -d'.' -f1 <<< "$DP_SLOT")"
        DP_SLOT2="$(cut -d'.' -f2 <<< "$DP_SLOT")"
        DP_PCI=$(printf %d 0x$DP_PCI)
        PCI_LIST[$index]="pci_0000_"$DP_PCI"_"$DP_SLOT1"_"$DP_SLOT2""
    done
    echo ${PCI_LIST[@]}
}

pci_map() {
	if grep -i $1 $TERRAFORM_VAR_IN_FILE
    then
        PHY_INT1=$(cat $TERRAFORM_VAR_IN_FILE | grep -i $1 | awk {'print $3'}| cut -d '"' -f 2)
        cnt=0
        for (( index=0; index<$OPER_UP_LEN; index++ ))
        do
            if [  ${PHY_INT1} ==  ${OPER_STATE_UP[$index]}  ]; then
                PHY_INT=($(lshw -c network -businfo| grep -i "${PHY_INT1}" | awk {'print $1'}))
                RETURN_VAL=$(pci_hex2decimal $PHY_INT)
            else
                OPER_STATE_UNUSED[$cnt]=${OPER_STATE_UP[$index]}
                ((cnt++));
            fi
        done

        if [ $cnt -eq $OPER_UP_LEN ]; then
            echo "please provide physical inteface which LINK is UP"
            exit 1
        fi
	fi
}

phy_pci_map(){

    if [[ $1 == "CP1" ]] ; then
        pci_map $2
        S1MME_PHY_DEV=${RETURN_VAL}
        sed -i s/S1MME_PFDEV=/S1MME_PFDEV="${S1MME_PHY_DEV}"/g $NGIC_DEF_CFG
        sed -i s/^CTRL_PFDEV=/CTRL_PFDEV=${OPER_STATE_UNUSED[0]}/g $NGIC_DEF_CFG
    elif [[ $1 == "DP1" ]] ; then
        pci_map $2
        SGWU_S1U_PHY_DEV=${RETURN_VAL}
        pci_map $3
        PGWU_SGI_PHY_DEV=${RETURN_VAL}
        #pci_map $3
        #SGWU_S5S8_PHY_DEV=${RETURN_VAL}
        #pci_map $4
        #PGWU_SGI_PHY_DEV=${RETURN_VAL}
        #pci_map $5
        #SGWU_S5S8_PHY_DEV=${RETURN_VAL}
        sed -i s/DEF_IF_S1U_VM_NGIC_DP1_PCI=/DEF_IF_S1U_VM_NGIC_DP1_PCI="${SGWU_S1U_PHY_DEV}"/g $NGIC_DEF_CFG
        sed -i s/DEF_IF_SGI_VM_NGIC_DP2_PCI=/DEF_IF_SGI_VM_NGIC_DP2_PCI="${PGWU_SGI_PHY_DEV}"/g $NGIC_DEF_CFG
        #sed -i s/DEF_IF_S5S8_VM_NGIC_DP1_PCI=/DEF_IF_S5S8_VM_NGIC_DP1_PCI="${SGWU_S5S8_PHY_DEV}"/g $NGIC_DEF_CFG
        #sed -i s/DEF_IF_S5S8_VM_NGIC_DP2_PCI=/DEF_IF_S5S8_VM_NGIC_DP2_PCI="${PGWU_S5S8_PHY_DEV}"/g $NGIC_DEF_CFG
    elif [[ $1 == "SPG1" ]] ; then
        pci_map $2
        S1MME_PHY_DEV=${RETURN_VAL}
        pci_map $3
        SGWU_S1U_PHY_DEV=${RETURN_VAL}
        pci_map $4
        PGWU_SGI_PHY_DEV=${RETURN_VAL}
        sed -i s/S1MME_PFDEV=/S1MME_PFDEV="${S1MME_PHY_DEV}"/g $NGIC_DEF_CFG
        sed -i s/DEF_IF_S1U_VM_NGIC_DP1_PCI=/DEF_IF_S1U_VM_NGIC_DP1_PCI="${SGWU_S1U_PHY_DEV}"/g $NGIC_DEF_CFG
        sed -i s/DEF_IF_SGI_VM_NGIC_DP2_PCI=/DEF_IF_SGI_VM_NGIC_DP2_PCI="${PGWU_SGI_PHY_DEV}"/g $NGIC_DEF_CFG

    else
        exit 1
        #sed -i s/S1MME_PFDEV=/S1MME_PFDEV="${PCI_LIST[0]}"/g $NGIC_DEF_CFG
        #sed -i s/DEF_IF_S1U_VM_NGIC_DP1_PCI=/DEF_IF_S1U_VM_NGIC_DP1_PCI="${PCI_LIST[2]}"/g $NGIC_DEF_CFG
        #sed -i s/DEF_IF_SGI_VM_NGIC_DP2_PCI=/DEF_IF_SGI_VM_NGIC_DP2_PCI="${PCI_LIST[3]}"/g $NGIC_DEF_CFG
    fi
}

vnf_creation(){
	echo -e "\tCreation of VF on Device:\t" $1
    echo -e "\tTotal Number of VF:\t\t" $2
    echo "Create $2 VFs > /sys/class/net/$1/device/sriov_numvfs"
    echo $2 > /sys/class/net/$1/device/sriov_numvfs
    #Set Conrol PF Device Interface 'ON'
    set -x
    ip link set dev $1 up
    set +x
}

vnf_deletion(){
    echo -e "\tDeletion of VF on Device:\t" $1
    echo 0 > /sys/class/net/$1/device/sriov_numvfs
    #ip link set dev $1 down
    ip link show $1
}

ctrl_plane(){
    if [ ${#OPER_STATE_UP[@]} -ge "2" ]; then
        # Writing the PCI device and modifying them as per need to populate ngicvm_defs.cfg
        pci_addr_mapping
#################################################################
#### Check if physical interface is defined for S1MME ###########
#################################################################
        if grep -q -E 'S1MME_PHY_DEV' $TERRAFORM_VAR_IN_FILE
        then
            phy_pci_map CP1 S1MME_PHY_DEV
        else
            sed -i s/S1MME_PFDEV=/S1MME_PFDEV="${PCI_LIST[0]}"/g $NGIC_DEF_CFG
            sed -i s/^CTRL_PFDEV=/CTRL_PFDEV=${OPER_STATE_UP[1]}/g $NGIC_DEF_CFG
        fi
		source $NGIC_DEF_CFG
		echo ">>>$CTRL_PFDEV"
        echo "Creation of virtual function for Control Plane :"
        vnf_creation $CTRL_PFDEV $NUM_CTRL_VF
        sleep 3
        ./network_mapping.sh cp_vf
        exit 0
    else
        echo "Insufficient NIC"
        exit 1
    fi
}
# REDMINE TASK : 108 : Disable physical interface assigment for S5S8 in DP vms.
data_plane(){
    if [[ ${#OPER_STATE_UP[@]} -ge "3" ]]
    then
        echo ${OPER_STATE_UP[0]}
        sed -i s/DP_CTRL_PFDEV=/DP_CTRL_PFDEV=${OPER_STATE_UP[0]}/g $NGIC_DEF_CFG
        #sed -i s/DTPL_DP1_PFDEV=/DTPL_DP1_PFDEV=${OPER_STATE_UP[1]}/g $NGIC_DEF_CFG
        #sed -i s/DTPL_DP2_PFDEV=/DTPL_DP2_PFDEV=${OPER_STATE_UP[2]}/g $NGIC_DEF_CFG

        # Writing the PCI devices and modifying them as per need to populate ngicvm_defs.cfg
        pci_addr_mapping
#################################################################
#### Check if physical interface is defined for SGWU ############
#################################################################
        #if grep -q -E 'SGWU_S1U_PHY_DEV|SGWU_S5S8_PHY_DEV|PGWU_SGI_PHY_DEV|PGWU_S5S8_PHY_DEV' $TERRAFORM_VAR_IN_FILE
        if grep -q -E 'SGWU_S1U_PHY_DEV|PGWU_SGI_PHY_DEV' $TERRAFORM_VAR_IN_FILE
        then
            #phy_pci_map DP1 SGWU_S1U_PHY_DEV SGWU_S5S8_PHY_DEV PGWU_SGI_PHY_DEV PGWU_S5S8_PHY_DEV
            phy_pci_map DP1 SGWU_S1U_PHY_DEV PGWU_SGI_PHY_DEV 
        else
            sed -i s/DEF_IF_S1U_VM_NGIC_DP1_PCI=/DEF_IF_S1U_VM_NGIC_DP1_PCI="${PCI_LIST[1]}"/g $NGIC_DEF_CFG
            #sed -i s/DEF_IF_S5S8_VM_NGIC_DP1_PCI=/DEF_IF_S5S8_VM_NGIC_DP1_PCI="${PCI_LIST[2]}"/g $NGIC_DEF_CFG
            #sed -i s/DEF_IF_S5S8_VM_NGIC_DP2_PCI=/DEF_IF_S5S8_VM_NGIC_DP2_PCI="${PCI_LIST[3]}"/g $NGIC_DEF_CFG
            sed -i s/DEF_IF_SGI_VM_NGIC_DP2_PCI=/DEF_IF_SGI_VM_NGIC_DP2_PCI="${PCI_LIST[2]}"/g $NGIC_DEF_CFG
        fi
		source $NGIC_DEF_CFG
		echo ">>>$DP_CTRL_PFDEV"
        echo "Creation of virtual function for Data Plane :"
        vnf_creation $DP_CTRL_PFDEV $NUM_DP_CTRL_PF
        sleep 3
        ./network_mapping.sh dp_vf
        exit 0
    else
        echo "Minimum number of NIC cards needed to deploy data plane VM's do not match. Please have atleast 3 NICS available\n"

    fi
}

spgw_plane(){
    if [ ${#OPER_STATE_UP[@]} -ge "4" ]; then
        # Writing the PCI device and modifying them as per need to populate ngicvm_defs.cfg
        pci_addr_mapping
        sed -i s/CTRL_PFDEV=/CTRL_PFDEV=${OPER_STATE_UP[1]}/g $NGIC_DEF_CFG
        if grep -q -E 'S1MME_PHY_DEV|SGWU_S1U_PHY_DEV|PGWU_SGI_PHY_DEV' $TERRAFORM_VAR_IN_FILE
        then
            phy_pci_map SPG1 S1MME_PHY_DEV SGWU_S1U_PHY_DEV PGWU_SGI_PHY_DEV
        else
            sed -i s/S1MME_PFDEV=/S1MME_PFDEV="${PCI_LIST[0]}"/g $NGIC_DEF_CFG
            sed -i s/DEF_IF_S1U_VM_NGIC_DP1_PCI=/DEF_IF_S1U_VM_NGIC_DP1_PCI="${PCI_LIST[2]}"/g $NGIC_DEF_CFG
            sed -i s/DEF_IF_SGI_VM_NGIC_DP2_PCI=/DEF_IF_SGI_VM_NGIC_DP2_PCI="${PCI_LIST[3]}"/g $NGIC_DEF_CFG

        fi
		    source $NGIC_DEF_CFG
            echo "Creating virtual functions:"
            vnf_creation $CTRL_PFDEV $NUM_CTRL_VF
            sleep 3
            ./network_mapping.sh spgw_vf
            exit 0
	else
        echo "Insufficient NIC"
        exit 1
    fi
}

case $1 in
    cp|CP)
        ctrl_plane
        ;;
    dp|DP)
        data_plane
        ;;
    spgw|SPGW)
        spgw_plane
        ;;
    *)
        echo "Invalid option"
        ;;
esac
