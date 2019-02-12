#! /bin/bash
DEST_DIR="{{ DEPS_DIR }}"

build_dealer_deps()
{
        sudo apt-get -y install cmake
        cd $BASEDIR/deps

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

        #build sgx_tcdr
        cd ../sgx_zmq/sgx_tcdr/
        make

        #build sgx_ucdr
        cd ../sgx_ucdr/
        make

        #download rapidjson
        git submodule init
        git submodule update
}

build_dealer()
{
        cd $BASEDIR
        make clean
        make SGX_MODE=HW SGX_DEBUG=1
}


get_dealer_hash()
{
        output=($(./dealer -j conf/dealer.json -x | sed -n 's/MR.* ://p'))

        MRENCLAVE=${output[0]}
        MRSIGNER=${output[1]}
}

replace_kms_mrsigner()
{
        #replace MRSIGNER value of KMS in Enclave/ca_bundle.h file
        sed -i "/#define KMS_MRSIGNER/c\#define KMS_MRSIGNER \"${MRSIGNER}\"" Enclave/ca_bundle.h
}

print_hash_message()
{
        echo "---------------------------------------------------------------------------"
        echo "Use MRENCLAVE and MRSIGNER values while building KMS."
        echo "./install.sh <MRENCLAVE> <MRSIGNER>"
        echo "MRENCLAVE : $MRENCLAVE"
        echo "MRSIGNER  : $MRSIGNER"
        echo "---------------------------------------------------------------------------"
}

BASEDIR=$PWD

build_dealer_deps
build_dealer
get_dealer_hash
replace_kms_mrsigner
build_dealer
#get_dealer_hash
#print_hash_message
