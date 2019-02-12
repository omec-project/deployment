#!/bin/bash 
DEST_DIR="{{ DEPS_DIR }}"
install_intel_sgx()
{
        #install Intel(R) SGX dependencies
        sudo apt-get -y update
        sudo apt-get -y install libssl-dev libcurl4-openssl-dev libprotobuf-dev build-essential

        #install Intel(R) SGX Driver
        wget https://download.01.org/intel-sgx/linux-1.9/sgx_linux_x64_driver_3abcf82.bin -P $DEST_DIR
        chmod +x $DEST_DIR/sgx_linux_x64_driver_3abcf82.bin
        sudo $DEST_DIR/sgx_linux_x64_driver_3abcf82.bin

        #install Intel(R) SGX Platform Software
        wget https://download.01.org/intel-sgx/linux-1.9/sgx_linux_ubuntu16.04.1_x64_psw_1.9.100.39124.bin -P $DEST_DIR
        chmod +x $DEST_DIR/sgx_linux_ubuntu16.04.1_x64_psw_1.9.100.39124.bin
        sudo $DEST_DIR/sgx_linux_ubuntu16.04.1_x64_psw_1.9.100.39124.bin

        #install Intel(R) SGX SDK
        wget https://download.01.org/intel-sgx/linux-1.9/sgx_linux_ubuntu16.04.1_x64_sdk_1.9.100.39124.bin -P $DEST_DIR
        chmod +x  $DEST_DIR/sgx_linux_ubuntu16.04.1_x64_sdk_1.9.100.39124.bin
        sudo echo -e "no\n/opt/intel" |$DEST_DIR/sgx_linux_ubuntu16.04.1_x64_sdk_1.9.100.39124.bin

        source /opt/intel/sgxsdk/environment
}
install_deps()
{
        install_intel_sgx
}

install_deps
