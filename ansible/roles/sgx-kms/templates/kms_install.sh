#! /bin/bash
DEST_DIR="{{ DEPS_DIR }}"

build_kms_deps()
{
        sudo apt-get install cmake

        cd $DEALERDIR/deps
        #build mbedtls-SGX
        git clone https://github.com/bl4ck5un/mbedtls-SGX.git
        cp mbedtls_sgx_ra_*.patch mbedtls-SGX/
        cd mbedtls-SGX
        git apply mbedtls_sgx_ra_prebuild.patch
        mkdir build
        cd build
        cmake ..
        make -j
        make install
        sleep 3
        cd ../
        git apply mbedtls_sgx_ra_postbuild.patch

        #download rapidjson
        git submodule init
        git submodule update
}

build_kms()
{
        cd $BASEDIR
        make clean
        make SGX_MODE=HW SGX_DEBUG=1
}


replace_dealer_mrenclave_mrsigner()
{
        cd $BASEDIR
        #replace MRENCLAVE value of Dealer in Enclave/ca_bundle.h file
        sed -i "0,/DEALER_MRENCLAVE/{s/DEALER_MRENCLAVE/${DEALER_MRENCLAVE}/}" Enclave/ca_bundle.h

        #replace MRSIGNER value of Dealer in Enclave/ca_bundle.h file
        sed -i "0,/DEALER_MRSIGNER/{s/DEALER_MRSIGNER/${DEALER_MRSIGNER}/}" Enclave/ca_bundle.h
}

BASEDIR=$PWD
DEALERDIR=$BASEDIR/../dealer

DEALER_MRENCLAVE=$1
DEALER_MRSIGNER=$2

build_kms_deps
replace_dealer_mrenclave_mrsigner
build_kms
