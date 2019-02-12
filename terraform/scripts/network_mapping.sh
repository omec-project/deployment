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
source ../c3povm_defs.cfg
NIC_DIR="/sys/class/net"
AUTOGEN="../autogen_new.cfg"
TFVAR="../network_map.tfvars"
VF_PCI_NAME_ARRAY=(DEF_IF_S11_VM_NGIC_CP1_PCI DEF_IF_S5S8_SGWC_VM_NGIC_CP1_PCI DEF_IF_S5S8_PGWC_VM_NGIC_CP2_PCI DEF_IF_ODL_NB_VM_NGIC_CP1_PCI DEF_IF_ODL_NB_VM_NGIC_CP2_PCI DEF_IF_ODL_NB_VM_FPC_ODL1_PCI DEF_IF_ODL_SB_VM_FPC_ODL1_PCI DEF_IF_MME_S11_VM_C3PO_MME1_PCI DEF_IF_MME_S6_VM_C3PO_MME1_PCI DEF_IF_HSS_S6_VM_C3PO_HSS1_PCI DEF_IF_HSS_DB_VM_C3PO_HSS1_PCI DEF_IF_DBN_HSS_VM_C3PO_DBN1_PCI DEF_IF_ODL_SB_VM_NGIC_DP1_PCI)

#VF_PCI_DP_NAME_ARRAY=(DEF_IF_S1U_VM_NGIC_DP1_PCI DEF_IF_S5S8_VM_NGIC_DP1_PCI DEF_IF_S5S8_VM_NGIC_DP2_PCI DEF_IF_SGI_VM_NGIC_DP2_PCI)
#VF_PCI_DP2CP_NAME_ARRAY=(DEF_IF_ODL_SB_VM_NGIC_DP1_PCI DEF_IF_ODL_SB_VM_NGIC_DP2_PCI)
VF_PCI_DP2CP_NAME_ARRAY=(DEF_IF_ODL_SB_VM_NGIC_DP1_PCI DEF_IF_ODL_SB_VM_NGIC_DP2_PCI DEF_IF_S5S8_VM_NGIC_DP1_PCI DEF_IF_S5S8_VM_NGIC_DP2_PCI)
VF_PCI_DP1_NAME_ARRAY=(DEF_IF_S1U_VM_NGIC_DP1_PCI DEF_IF_S5S8_VM_NGIC_DP1_PCI)
VF_PCI_DP2_NAME_ARRAY=(DEF_IF_S5S8_VM_NGIC_DP2_PCI DEF_IF_SGI_VM_NGIC_DP2_PCI)

## Nulify autogen and terrafrom device mapping cfg files
cat /dev/null > $AUTOGEN
cat /dev/null > $TFVAR
#echo "DEF_IF_MME_S1MME_VM_C3PO_MME1_PCI = \"$S1MME_PFDEV\"" >> $TFVAR
#VF for Control Interface
get_vf_interface_map()
{
if [ -d "${NIC_DIR}/$1/device" -a ! -L "${NIC_DIR}/$1/device/physfn" ]; then
	declare -a VF_PCI_BDF
	declare -a VF_INTERFACE
	k=0
	for j in $( ls "${NIC_DIR}/$1/device" ) ;
	do
		if [[ "$j" == "virtfn"* ]]; then
			VF_PCI=$( readlink "${NIC_DIR}/$1/device/$j" | cut -d '/' -f2 )
			VF_PCI_BDF[$k]=$VF_PCI
			## PCI Mapping Interfaces
			case $1 in
				$CTRL_PFDEV)
					if [ -z ${VF_PCI_NAME_ARRAY[$k]} ] ; then
                                           echo "AVAILABLE_PCI = $VF_PCI" >> $AUTOGEN
                                        else
                                           echo "${VF_PCI_NAME_ARRAY[$k]} = $VF_PCI" >> $AUTOGEN
                                        fi
					;;
#				$DTPL_DP1_PFDEV)
#					if [ -z ${VF_PCI_DP1_NAME_ARRAY[$k]} ] ; then
#                                           echo "AVAILABLE_PCI = $VF_PCI" >> $AUTOGEN
#                                        else
#                                           echo "${VF_PCI_DP1_NAME_ARRAY[$k]} = $VF_PCI" >> $AUTOGEN
#                                        fi
#                                        ;;
#				$DTPL_DP2_PFDEV)
#                                        if [ -z ${VF_PCI_DP2_NAME_ARRAY[$k]} ] ; then
#                                           echo "AVAILABLE_PCI = $VF_PCI" >> $AUTOGEN
#                                        else
#                                           echo "${VF_PCI_DP2_NAME_ARRAY[$k]} = $VF_PCI" >> $AUTOGEN
#                                        fi
#                                        ;;
				#$S1MME_PFDEV)
                                #           echo "DEF_IF_MME_S1MME_VM_C3PO_MME1_PCI = $VF_PCI" >> $AUTOGEN
                                #        ;;
				$DP_CTRL_PFDEV)
					echo "${VF_PCI_DP2CP_NAME_ARRAY[$k]} = $VF_PCI" >> $AUTOGEN ;;
				*)
					echo "Invalid interface options" ;;
			esac
			for iface in $( ls $NIC_DIR );
			do
				link_dir=$( readlink ${NIC_DIR}/$iface )
				if [[ "$link_dir" == *"$VF_PCI"* ]]; then
					VF_INTERFACE[$k]=$iface
					case $1 in
						$CTRL_PFDEV)
							if [[ -z ${VF_PCI_NAME_ARRAY[$k]} ]]; then
                                                           echo "${VF_PCI_NAME_ARRAY[$k]}" > /dev/null
                                                        else
							   echo "${VF_PCI_NAME_ARRAY[$k]} = \"$iface\"" >> $TFVAR
							fi
							;;
#						$DTPL_DP1_PFDEV)
#							if [[ -z ${VF_PCI_DP1_NAME_ARRAY[$k]} ]]; then
#                                                           echo "${VF_PCI_DP1_NAME_ARRAY[$k]}" > /dev/null
#                                                        else
#                                                           echo "${VF_PCI_DP1_NAME_ARRAY[$k]} = \"$iface\"" >> $TFVAR
#                                                        fi
#                                                        ;;
#						$DTPL_DP2_PFDEV)
#                                                        if [[ -z ${VF_PCI_DP2_NAME_ARRAY[$k]} ]]; then
#                                                           echo "${VF_PCI_DP2_NAME_ARRAY[$k]}" > /dev/null
#                                                        else
#                                                           echo "${VF_PCI_DP2_NAME_ARRAY[$k]} = \"$iface\"" >> $TFVAR
#                                                        fi
#                                                        ;;
#						$S1MME_PFDEV)
#                                                           echo "DEF_IF_MME_S1MME_VM_C3PO_MME1_PCI = \"$iface\"" >> $TFVAR
#                                                        ;;
						$DP_CTRL_PFDEV)
							if [[ -z ${VF_PCI_DP2CP_NAME_ARRAY[$k]} ]]; then
                                                           echo "${VF_PCI_DP2CP_NAME_ARRAY[$k]}" > /dev/null
                                                        else
                                                           echo "${VF_PCI_DP2CP_NAME_ARRAY[$k]} = \"$iface\"" >> $TFVAR
                                                        fi
                                                        ;;

						*)
							echo "Invalid interface options" ;;
					esac
				fi
			done
			((k++))
		fi
	done
fi
}
populate_dp_interfaces()
{
    echo DEF_IF_SGI_VM_NGIC_DP2_PCI = "\""$DEF_IF_SGI_VM_NGIC_DP2_PCI"\"" >> $TFVAR
    echo DEF_IF_S1U_VM_NGIC_DP1_PCI = "\""$DEF_IF_S1U_VM_NGIC_DP1_PCI"\"" >> $TFVAR
    # READMINE TASK : 108
    #echo DEF_IF_S5S8_VM_NGIC_DP1_PCI = "\""$DEF_IF_S5S8_VM_NGIC_DP1_PCI"\"" >> $TFVAR
    #echo DEF_IF_S5S8_VM_NGIC_DP2_PCI = "\""$DEF_IF_S5S8_VM_NGIC_DP2_PCI"\"" >> $TFVAR
}

populate_spgw_interfaces()
{
    echo DEF_IF_SGI_VM_NGIC_DP2_PCI = "\""$DEF_IF_SGI_VM_NGIC_DP2_PCI"\"" >> $TFVAR
    echo DEF_IF_S1U_VM_NGIC_DP1_PCI = "\""$DEF_IF_S1U_VM_NGIC_DP1_PCI"\"" >> $TFVAR
    echo DEF_IF_MME_S1MME_VM_C3PO_MME1_PCI = "\""$S1MME_PFDEV"\"" >> $TFVAR
}

populate_s1mme_interfaces()
{
echo DEF_IF_MME_S1MME_VM_C3PO_MME1_PCI = "\""$S1MME_PFDEV"\"" >> $TFVAR
}
case $1 in
    cp_vf|CP_VF)
	get_vf_interface_map $CTRL_PFDEV
	populate_s1mme_interfaces
	#get_vf_interface_map $S1MME_PFDEV
        ;;
    dp_vf|DP_VF)
	#get_vf_interface_map $DTPL_DP1_PFDEV
	#get_vf_interface_map $DTPL_DP2_PFDEV
	populate_dp_interfaces
	get_vf_interface_map $DP_CTRL_PFDEV
        ;;
    spgw_vf|SPGW_VF)
	get_vf_interface_map $CTRL_PFDEV
	populate_spgw_interfaces
		;;
    *)
        echo "Invalid option"
        ;;
esac
