#!/bin/bash

NIC_DIR="/sys/class/net"
for i in $( ls $NIC_DIR) ;
do
	if [ -d "${NIC_DIR}/$i/device" -a ! -L "${NIC_DIR}/$i/device/physfn" ]; then
		declare -a VF_PCI_BDF
		declare -a VF_INTERFACE
		k=0
		for j in $( ls "${NIC_DIR}/$i/device" ) ;
		do
			if [[ "$j" == "virtfn"* ]]; then
				VF_PCI=$( readlink "${NIC_DIR}/$i/device/$j" | cut -d '/' -f2 )
				VF_PCI_BDF[$k]=$VF_PCI
				#get the interface name for the VF at this PCI Address
				for iface in $( ls $NIC_DIR );
				do
					link_dir=$( readlink ${NIC_DIR}/$iface )
					if [[ "$link_dir" == *"$VF_PCI"* ]]; then
						VF_INTERFACE[$k]=$iface
#						echo $iface
					fi
				done
				((k++))
			fi
		done
		NUM_VFs=${#VF_PCI_BDF[@]}
		if [[ $NUM_VFs -gt 0 ]]; then
			#get the PF Device Description
			PF_PCI=$( readlink "${NIC_DIR}/$i/device" | cut -d '/' -f4 )
			PF_VENDOR=$( lspci -vmmks $PF_PCI | grep ^Vendor | cut -f2)
			PF_NAME=$( lspci -vmmks $PF_PCI | grep ^Device | cut -f2).
			echo "Virtual Functions on $PF_VENDOR $PF_NAME ($i):"
			echo -e "PCI BDF\t\tInterface"
			echo -e "=======\t\t========="
			for (( l = 0; l < $NUM_VFs; l++ )) ;
			do
				echo -e "${VF_PCI_BDF[$l]}\t${VF_INTERFACE[$l]}"
			done
			unset VF_PCI_BDF
			unset VF_INTERFACE
			echo " "
		fi
	fi
done
