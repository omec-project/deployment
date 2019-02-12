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
cd $(dirname ${BASH_SOURCE[0]})
SERVICE=3
SGX_SERVICE=0
SERVICE_NAME="Collocated CP and DP"
source ./services.cfg
export NGIC_DIR=$PWD
echo "------------------------------------------------------------------------------"
echo " NGIC_DIR exported as $NGIC_DIR"
echo "------------------------------------------------------------------------------"

HUGEPGSZ=`cat /proc/meminfo  | grep Hugepagesize | cut -d : -f 2 | tr -d ' '`
MODPROBE="/sbin/modprobe"
INSMOD="/sbin/insmod"
DPDK_DOWNLOAD="https://fast.dpdk.org/rel/dpdk-18.02.tar.gz"
DPDK_DIR=$NGIC_DIR/dpdk
LINUX_SGX_SDK="https://github.com/intel/linux-sgx.git"
LINUX_SGX_SDK_BRANCH_TAG="sgx_1.9"

setup_http_proxy()
{
        while true; do
                echo
                read -p "Enter Proxy : " proxy
                export http_proxy=$proxy
                export https_proxy=$proxy
                echo "Acquire::http::proxy \"$http_proxy\";" | sudo tee -a /etc/apt/apt.conf > /dev/null
                echo "Acquire::https::proxy \"$http_proxy\";" | sudo tee -a /etc/apt/apt.conf > /dev/null

                wget -T 20 -t 3 --spider http://www.google.com
                if [ "$?" != 0 ]; then
                  echo -e "No Internet connection. Proxy incorrect? Try again"
                  echo -e "eg: http://<proxy>:<port>"
                  exit 1
                fi
        return
        done
}


setup_env()
{
        # a. Check for OS dependencies
        source /etc/os-release
        if [[ $VERSION_ID != "16.04" ]] ; then
                echo "WARNING: It is recommended to use Ubuntu 16.04..Your version is "$VERSION_ID
                echo "The libboost 1.58 dependency is not met by official Ubuntu PPA. Either attempt"
                echo "to find/compile boost 1.58 or upgrade your distribution by performing 'sudo do-release-upgrade'"
        else
                echo "Ubuntu 16.04 OS requirement met..."
        fi
        echo
        echo "Checking network connectivity..."
        # b. Check for internet connections
        wget -T 20 -t 3 --spider http://www.google.com
        if [ "$?" != 0 ]; then
                while true; do
                        read -p "No Internet connection. Are you behind a proxy (y/n)? " yn
                        case $yn in
                                [Yy]* ) $SETUP_PROXY ; return;;
                                [Nn]* ) echo "Please check your internet connection..." ; exit;;
                                * ) "Please answer yes or no.";;
                        esac
                done
        fi
}

get_agreement_download()
{
        echo
        echo "List of packages needed for NGIC build and installation:"
        echo "-------------------------------------------------------"
        echo "1.  DPDK version 16.11.4"
        echo "2.  build-essential"
        echo "3.  linux-headers-generic"
        echo "4.  git"
        echo "5.  unzip"
        echo "6.  libpcap-dev"
        echo "7.  make"
        echo "8.  hyperscan"
        echo "9.  curl"
        echo "10. openssl-dev"
        echo "11. and other library dependencies"
}

install_libs()
{
        echo "Install libs needed to build and run NGIC..."
        sudo apt-get update
        sudo apt-get -y install curl build-essential linux-headers-$(uname -r) \
                git unzip libpcap0.8-dev gcc libjson0-dev make libc6 libc6-dev \
                g++-multilib libzmq3-dev libcurl4-openssl-dev libssl-dev python-pip
        sudo pip install zmq
}
download_hyperscan()
{
        source /etc/os-release
        if [[ $VERSION_ID != "16.04" ]] ; then
                echo "Download boost manually "$VERSION_ID
                wget http://sourceforge.net/projects/boost/files/boost/1.58.0/boost_1_58_0.tar.gz
                tar -xf boost_1_58_0.tar.gz
                pushd boost_1_58_0
                sudo apt-get install g++
                ./bootstrap.sh --prefix=/usr/local
                ./b2
                ./b2 install
                popd
        else
                sudo apt-get -y install libboost-all-dev
        fi
        echo "Downloading HS and dependent libraries"
        sudo -y apt-get install cmake ragel
        wget https://github.com/01org/hyperscan/archive/v4.1.0.tar.gz
        tar -xvf v4.1.0.tar.gz
        pushd hyperscan-4.1.0
        mkdir build; pushd build
        cmake -DCMAKE_CXX_COMPILER=c++ ..
        cmake --build .
        export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PWD/lib
        popd
        export HYPERSCANDIR=$PWD
        echo "export HYPERSCANDIR=$PWD" >> ../setenv.sh
        popd
}
download_dpdk_zip()
{
        echo "Download DPDK zip"
        wget --no-check-certificate "${DPDK_DOWNLOAD}"

        if [ $? -ne 0 ] ; then
                echo "Failed to download dpdk submodule."
                return
        fi
        tar -xzvf "${DPDK_DOWNLOAD##*/}"
        rm -rf "$NGIC_DIR"/dpdk/
        rm -f "${DPDK_DOWNLOAD##*/}"
        mv "$NGIC_DIR"/dpdk-*/ "$NGIC_DIR"/dpdk
}

install_dpdk()
{
        echo "Build DPDK"
        export RTE_TARGET=x86_64-native-linuxapp-gcc
        cp -f dpdk-18.02_common_linuxapp "$DPDK_DIR"/config/common_linuxapp

        pushd "$DPDK_DIR"
        make -j 10 install T="$RTE_TARGET"
        if [ $? -ne 0 ] ; then
                echo "Failed to build dpdk, please check the errors."
                return
        fi

        if lsmod | grep rte_kni >&/dev/null; then
                echo -e "\n*************************************"
                echo "rte_kni.ko module already loaded..!!!"
                echo -e "*************************************\n"
        else
                sudo $INSMOD "$RTE_TARGET"/kmod/rte_kni.ko

                if lsmod | grep rte_kni >&/dev/null; then
                        echo -e "\n*********************************"
                        echo "Inserted 'rte_kni.ko' module..!!!"
                        echo -e "*********************************\n"
                else
                        echo -e "\n**********************************************"
                        echo "ERROR: 'rte_kni.ko' module failed to load..!!!"
                        echo -e "**********************************************\n"
                fi

        fi

        sudo modinfo igb_uio
        if [ $? -ne 0 ] ; then
                sudo $MODPROBE -v uio
                sudo $INSMOD "$RTE_TARGET"/kmod/igb_uio.ko
                sudo cp -f "$RTE_TARGET"/kmod/igb_uio.ko /lib/modules/"$(uname -r)"
                echo "uio" | sudo tee -a /etc/modules
                echo "igb_uio" | sudo tee -a /etc/modules
                sudo depmod
        fi
        popd
}

setup_dp_type()
{
        while true; do
                read -p "Do you want data-plane with Intel(R) SGX based CDR? " yn
                case $yn in
                        [Yy]* ) SGX_SERVICE=1; return;;
                        [Nn]* ) SGX_SERVICE=0; return;;
                        * ) "Please answer yes or no.";;
                esac
        done

}

configure_services()
{
#        clear
#        echo "------------------"
#        echo "Service Selection."
#        echo "------------------"
#        echo "1. Configure CP only"
#        echo "2. Configure DP only"
#        echo "3. Configure Collocated CP and DP "
        echo ""
        opt=$1
                case $opt in
                        cp)    echo "Control Plane Settings"
                                SERVICE=1
                                SERVICE_NAME="CP"
                                memory=`cat config/cp_config.cfg  | grep MEMORY | cut -d = -f 2 | tr -d ' '`
                                #setup_memory
                                setup_hugepages
                                return;;

                        dp)    echo "Data Plane Setting"
                                setup_dp_type
                                SERVICE=2
                                SERVICE_NAME="DP"
                                memory=`cat config/dp_config.cfg  | grep MEMORY | cut -d = -f 2 | tr -d ' '`
                                #setup_memory
                                download_hyperscan
                                setup_hugepages
                                return;;

                        cpdp)    echo "Control and Data Plane Setting"
                                SERVICE=3
                                SERVICE_NAME="Collocated CP and DP"
                                setup_dp_type
                                setup_collocated_memory
                                setup_memory
                                setup_hugepages
                                return;;

                        *)      echo
                                echo "Please select appropriate option."
                                echo ;;
                esac

}
setup_memory()
{
        echo
        echo "Current $SERVICE_NAME memory size : $memory (MB)"
                               if [ $SERVICE == 1 ] || [ $SERVICE == 3 ] ; then
                                                        set_size CP
                                                        sed -i '/^MEMORY=/s/=.*/='$memory'/' config/cp_config.cfg
                                                fi

                                                if [ $SERVICE == 2 ] || [ $SERVICE == 3 ] ; then
                                                        set_size DP
                                                        sed -i '/^MEMORY=/s/=.*/='$memory'/' config/dp_config.cfg
                                                fi

                                                if [ $SERVICE == 3 ] ; then
                                                        setup_collocated_memory
                                                echo "Total memory size allocated for Collocated CP and DP : $memory "
                                fi
}
set_size()
{
        while true;do
        #read -p "Enter memory size[MB] : " memory
        memory="2048"
                if [[ ! ${memory} =~ ^[0-9]+$ ]] ; then
                        echo
                        echo "Please enter valid input."
                        echo
                else
                        return
                fi
        done
}

setup_collocated_memory()
{

        dp_memory=`cat config/dp_config.cfg  | grep MEMORY | cut -d = -f 2 | tr -d ' '`
        cp_memory=`cat config/cp_config.cfg  | grep MEMORY | cut -d = -f 2 | tr -d ' '`
        memory=$(($cp_memory + $dp_memory))
}

setup_hugepages()
{
        Pages=16
        echo "SERVICE_NAME=\"$SERVICE_NAME\" " > ./services.cfg
        echo "SERVICE=$SERVICE" >> ./services.cfg
        echo "SGX_SERVICE=$SGX_SERVICE" >> ./services.cfg

        if [[ "$HUGEPGSZ" = "2048kB" ]] ; then
                #---- Calculate number of pages base on configure MEMORY and page size
                Hugepgsz=`echo $HUGEPGSZ | tr -d 'kB'`
                Pages=$((($memory*1024) / $Hugepgsz))

                echo "MEMORY (MB) : " $memory
                echo "Number of pages : " $Pages
        fi

        if [ ! "`grep nr_hugepages /etc/sysctl.conf`" ]; then
                echo "vm.nr_hugepages=$Pages" | sudo tee /etc/sysctl.conf
        else
                echo "vm.nr_hugepages=$Pages"
                sudo sed -i '/^vm.nr_hugepages=/s/=.*/='$Pages'/' /etc/sysctl.conf
        fi

        sudo sysctl -p

        sudo service procps start

        grep -s '/dev/hugepages' /proc/mounts
        if [ $? -ne 0 ] ; then
                echo "Creating /mnt/huge and mounting as hugetlbfs"
                sudo mkdir -p /mnt/huge
                sudo mount -t hugetlbfs nodev /mnt/huge
                echo "nodev /mnt/huge hugetlbfs defaults 0 0" | sudo tee -a /etc/fstab > /dev/null
        fi
}
#install_libs
#download_dpdk_zip
#install_dpdk
download_linux_sgx()
{
        echo "Download Linux SGX SDK....."
        git clone --branch $LINUX_SGX_SDK_BRANCH_TAG $LINUX_SGX_SDK
        if [ $? -ne 0 ] ; then
                        echo "Failed to clone Linux SGX SDK, please check the errors."
                        return
        fi
}

build_ngic()
{
        pushd $NGIC_DIR
        source setenv.sh
        if [ $SERVICE == 2 ] || [ $SERVICE == 3 ] ; then
                make clean
                echo "Building Libs..."
                make build-lib || { echo -e "\nNG-CORE: Make lib failed\n"; }
                echo "Building DP..."
                make build-dp || { echo -e "\nDP: Make failed\n"; }
        fi
        if [ $SERVICE == 1 ] || [ $SERVICE == 3 ] ; then
                echo "Building libgtpv2c..."
                pushd $NGIC_DIR/libgtpv2c
                        make clean
                        make || { echo -e "\nlibgtpv2c: Make failed\n"; }
                popd
                echo "Building CP..."
                make clean-cp
                make build-cp || { echo -e "\nCP: Make failed\n"; }
        fi
        popd
}

install_libs
download_dpdk_zip
install_dpdk
configure_services $1
build_ngic
