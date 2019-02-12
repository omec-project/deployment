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

## Host Identification Module
##########################################################
##Run the parse_ini_input.py to generate the hosts file
#########################################################
python parse_ini_input.py 1> /dev/null
sleep 5
INPUT_FILE="../input.tfvars"
HOST_CFG_FILE="../host_type.cfg"
### Hardware validation #########################################################

hardware_validation()
{

echo ""
echo "--------------------------------------------------------"
echo "Checking for Hardware requirement "
echo "--------------------------------------------------------"


CORES_PER_NODE=$(cat $HOST_CFG_FILE | grep -i CORES_PER_NODE| awk {'print $3'})

CPU_CHECK=($(lscpu | grep -wi "Core(s)" | awk {'print $4'}))
if [[ $CPU_CHECK -ge $CORES_PER_NODE ]]
then
        SOCK_CHECK=($(lscpu |grep -iw "Socket(s)" | awk {'print $2'}))
        TOTAL_CORES=$(($SOCK_CHECK*$CPU_CHECK))
        CORES_TOTAL=$(cat $HOST_CFG_FILE | grep -i CORES_TOTAL| awk {'print $3'})
        if [[ $TOTAL_CORES -ge $CORES_TOTAL ]]
        then
                #MEM_CHECK=($(free -mh | grep -i mem | awk {'print $2'} | cut -d 'G' -f 1))
                MEM_CHECK=$(dmidecode -t 17 | grep  Size: | grep 'MB\|GB' | awk {'print $2'})
                MEM=0
                for mem in ${MEM_CHECK[@]}
                do
                  (( MEM += mem ))
                done
                MEM=$(( $MEM / 1024 ))
                MEMORY=$(cat $HOST_CFG_FILE | grep -i "MEMORY GB"| awk {'print $4'})
                if [[ $MEM -ge $MEMORY ]]
                then
                        HD_CHECK=($(df -hBG --total | grep -i total | awk {'print $2'} | cut -d 'G' -f 1))
                        HD=$(cat $HOST_CFG_FILE | grep -i "DISK GB"| awk {'print $4'})
                        if [[ $HD_CHECK -ge $HD ]]
                        then
                                echo "CPU Cores,Memory and Hard Disk are sufficient. Proceeding to check the number of NIC cards.\n"
                        else
                                echo "Please have a disk space of more than" $HD "GB. The current disk space is "$HD_CHECK" GB"
                                exit
                        fi
                else
                        echo "Please have a memory of more than "$MEMORY "GB. The current memory is "$MEM
                        exit
                fi
        else
                echo "You should have a minimum of" $CORES_TOTAL "cores. The current number of cores is "$TOTAL_CORES
                exit
        fi
else
        echo "Please have" $CORES_PER_NODE "cores per socket at the minimum. The current number of cores per socket(s) is "$CPU_CHECK
        exit
fi

}

#############----checking cpu core validity---########################################################

cpu_validation () {
NUMA0_ARRAY=()
NUMA1_ARRAY=()


function numa_0_expand () {

	first=$(lscpu | grep "NUMA node0" | awk '{print $4}' | cut -d '-' -f 1)
	last=$(lscpu | grep "NUMA node0" | awk '{print $4}' | cut -d '-' -f 2 | cut -d ',' -f 1)
        first_1=$(lscpu | grep "NUMA node0"  | awk '{print $4}' | cut -d ',' -f 2 | cut -d '-' -f 1)
	last_1=$(lscpu | grep "NUMA node0"  | awk '{print $4}' | cut -d ',' -f 2 | cut -d '-' -f 2)


       for (( num=$first; num<=$last; num++ ))
	   do
		   NUMA0_ARRAY+=($num)
	   done
	   for (( num=$first_1; num<=$last_1; num++ ))
 	   do
		   NUMA0_ARRAY+=($num)
	   done


}

function numa_1_expand () {

	first=$(lscpu | grep "NUMA node1" | awk '{print $4}' | cut -d '-' -f 1)
	last=$(lscpu | grep "NUMA node1" | awk '{print $4}' | cut -d '-' -f 2 | cut -d ',' -f 1)
        first_1=$(lscpu | grep "NUMA node1"  | awk '{print $4}' | cut -d ',' -f 2 | cut -d '-' -f 1)
	last_1=$(lscpu | grep "NUMA node1"  | awk '{print $4}' | cut -d ',' -f 2 | cut -d '-' -f 2)


       for (( num=$first; num<=$last; num++ ))
	   do
		   NUMA1_ARRAY+=($num)
	   done
	   for (( num=$first_1; num<=$last_1; num++ ))
 	   do
		   NUMA1_ARRAY+=($num)
	   done


}

function key_in_NUMA0 () {
key=$1
first=0
last=$(($NUMA0_LEN-1))
c=0
	while [[ $first -le $last ]]
	do
   		mid=$((($first+$last)/2))

   		if [ ${key//\,}  -eq ${NUMA0_ARRAY[$mid]}  ]
   		then
	   		c=1
	   		return 0
   		elif [ ${key//\,} -lt ${NUMA0_ARRAY[$mid]} ]
   		then
    		last=$(($mid-1))
   		elif [ ${key//\,} -gt ${NUMA0_ARRAY[$mid]} ]
   		then
	   		first=$(($mid+1))
   		fi
	done

	if [ $c -eq 0 ]
	then
		return 1
	fi

}


function key_in_NUMA1 () {

key=$1
first=0
last=$(($NUMA1_LEN-1))
c=0

while [[ $first -le $last ]]
do
   mid=$((($first+$last)/2))

   if [ ${key//\,}  -eq ${NUMA1_ARRAY[$mid]}  ]
   then
	   c=1
	   return 0
   elif [ ${key//\,} -lt ${NUMA1_ARRAY[$mid]} ]
   then
    last=$(($mid-1))
   elif [ ${key//\,} -gt ${NUMA1_ARRAY[$mid]} ]
   then
	   first=$(($mid+1))
   fi
done

if [ $c -eq 0 ]
then
	return 1
fi

}


function validate_core_range ()	{

		COMP_NAME=$1
		COMP_ARRAY=($(grep "CORE_RANGE_${COMP_NAME}" $INPUT_FILE | cut -d '=' -f 2 | cut -d '[' -f 2 | cut -d ']' -f 1))

		COMP1_ARRAY=()

		for i in ${COMP_ARRAY[@]}
		do
			COMP1_ARRAY+=(${i//\"})
		done

		key_in_NUMA0 ${COMP1_ARRAY[0]}

		if [ $? -eq 0 ]
		then
			cnt=1
			for (( index=1; index<${#COMP1_ARRAY[@]}; index++ ))
			do
				key_in_NUMA0 ${COMP1_ARRAY[$index]}
				if [ $? -eq 0 ]
				then
					((  cnt++  ))
				fi
			done
			if [ $cnt -eq ${#COMP1_ARRAY[@]} ]
			then
        		  echo "${COMP_NAME} range is valid"
				  return 0
	  		else
				  echo "${COMP_NAME} range is INVALID"
				  return 1
			fi
		else
			key_in_NUMA1 ${COMP1_ARRAY[0]}
			if [ $? -eq 0  ]
			then
				cnt=1
				for (( index=1; index<${#COMP1_ARRAY[@]}; index++ ))
				do
					key_in_NUMA1 ${COMP1_ARRAY[$index]}
					if [ $? -eq 0 ]
					then
						((  cnt++  ))
					fi
				done
				if [ $cnt -eq ${#COMP1_ARRAY[@]} ]
				then
          			echo "${COMP_NAME} range is valid"
					return 0
	  			else
		  			echo "${COMP_NAME} range is INVALID"
					return 1
				fi
			else
				echo "${COMP_NAME} RANGE IS INVALID"
				return 1
    		fi
	 fi
}

function main () {

 echo ""
 echo "----------------------------------------------------"
 echo " Validating cpu core assigned to component"
 echo "----------------------------------------------------"
 

 lscpu | grep "NUMA node0" | awk '{print $4}' | grep '-' > /dev/null

 if [[ $? -eq 0 ]]
 then
	 numa_0_expand
	 numa_1_expand
 else
    NUMA0_ARRAY=($(lscpu | grep "NUMA node0" | awk '{print $4}'))
    NUMA1_ARRAY=($(lscpu | grep "NUMA node1" | awk '{print $4}'))

    IFS=',' read -a NUMA0_ARRAY <<< "$NUMA0_ARRAY"
    IFS=',' read -a NUMA1_ARRAY <<< "$NUMA1_ARRAY"

 fi


NUMA0_LEN=${#NUMA0_ARRAY[@]}
NUMA1_LEN=${#NUMA1_ARRAY[@]}
VM_ARRAY=(HSS MME DB FPC SPGWC SPGWU SGWC PGWC SGWU PGWU)
VM_LEN=${#VM_ARRAY[@]}
VM_VALID_LEN=${#VM_ARRAY[@]}
valid_cnt=0

for (( num_1=0; num_1<$VM_LEN; num_1++ ))
do
     COMP=${VM_ARRAY[$num_1]}
	 grep -i CORE_RANGE_${COMP} $INPUT_FILE > /tmp/a
	 if [ $? -eq 0 ]
	 then
         validate_core_range ${COMP}
		 if [ $? -eq 0 ]
		 then
			 ((valid_cnt++))
		 fi
	else
		VM_VALID_LEN=$(expr $VM_VALID_LEN - 1)
	fi
done

    if [[ $VM_VALID_LEN -eq 0 ]]
    then
        echo "---------------------------------------------------"
        echo "Core range is not defined for any component.Exiting "
        echo "---------------------------------------------------"
        exit 1
    else
    if [[ $valid_cnt -eq  $VM_VALID_LEN   ]]
	then
                echo "-------------------------------------------"
		echo "Proceeding further"
                echo "-------------------------------------------"
		return 0
	else
                echo "------------------------------------------------"
                echo "Exiting"
	        echo "------------------------------------------------"
	        exit 1
	fi
    fi

}
main

}


### Check number of 10Gb NICS and then find out what needs to be deployed.
### Network card validation ################################################################

network_card_validation()
{

echo ""
echo "---------------------------------------------------------"
echo "Checking for NIC requirement  "
echo "---------------------------------------------------------"

NGIC_DEF_CFG="../c3povm_defs.cfg"
cp $NGIC_DEF_CFG.blank $NGIC_DEF_CFG
IF_DEV_LIST=($(lshw -c network -businfo | grep -i '10GbE\|10-Gigabit' |grep -v 'eno1' | awk '{print $2;}'))

for link in ${IF_DEV_LIST[@]}
do
   ifconfig $link up
   sleep 1
done

OPER_STATE=()
OPER_STATE_UP=()
OPER_STATE_UNUSED=()

#NUM_DEV_LIST=${#IF_DEV_LIST[@]}
if [[ ${#IF_DEV_LIST[@]} -ge "2" ]]
then
        cnt=0
        echo "Number of 10GB NICS available are greater than or equal to 2. We can go ahead and create virtual functions"
        for (( index=0; index<${#IF_DEV_LIST[@]}; index++ ))
        do
                STATE=($(cat /sys/class/net/${IF_DEV_LIST[$index]}/operstate 2> /dev/null ))
                if  [[ $STATE == "up" ]]
                then
                        OPER_STATE[$cnt]=${IF_DEV_LIST[$index]}
                        ip link show ${OPER_STATE[$cnt]} |grep -E "vf|MAC" 1> /tmp/a
                        if [ $? -eq 0 ] ; then
                                echo "Virtual functions are already created on  ${OPER_STATE[$cnt]}"
                        else
                                echo "Following interface is available for creation of vf  ${OPER_STATE_UP[$cnt]}"
                                TEMP_STATE[$cnt]=${OPER_STATE[$cnt]}
                                echo  ${TEMP_STATE[$cnt]}
                                echo $cnt
                        fi

                        echo ${OPER_STATE_UP[@]}
                        ((cnt++));
                fi
        done
else
	echo "Insufficient NIC's"
	exit 1
fi

}

##########################################################################

hardware_validation
cpu_validation
network_card_validation
