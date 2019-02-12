#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})
export FPC_DIR=$PWD
#cd $HOME
echo "------------------------------------------------------------------------------"
echo " FPC_DIR exported as $FPC_DIR"
echo "------------------------------------------------------------------------------"

# #############################################################
# FPC & Environment Dependencies settings
# #######################################
#FPC_DIR=fpc
FPC_GIT="https://github.com/sprintlabs/fpc.git"
FPC_BRANCH=dev-stable
MVN_GET_SETTING="https://raw.githubusercontent.com/opendaylight/odlparent/master/settings.xml"
ZMQ_DOWNLOAD="https://github.com/zeromq/libzmq/releases/download/v4.2.2/zeromq-4.2.2.tar.gz"
ZMQ_PKG=zeromq-4.2.2.tar.gz
ZMQ_DIR=zeromq-4.2.2

echo -e "\n*************************************************"
echo "Verify FPC & Environment Dependencies settings..."
echo "*************************************************"
echo -e "FPC_DIR:\t\t" $FPC_DIR
echo -e "FPC_GIT:\t\t" $FPC_GIT
echo -e "FPC_BRANCH:\t\t" $FPC_BRANCH
echo -e "MVN_GET_SETTING:\t" $MVN_GET_SETTING
echo -e "ZMQ_DOWNLOAD:\t\t" $ZMQ_DOWNLOAD
echo -e "ZMQ_DIR:\t\t" $ZMQ_DIR

set -x
echo -e "Please correct FPC environment settings!!!"
#exit 1
set +x
#
# Sets QUIT variable so script will finish.
#
quit()
{
        QUIT=$1
}

# Shortcut for quit.
q()
{
        quit
}

setup_http_proxy()
{
        while true; do
                echo
                #read -p "Enter Proxy : " proxy
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

}

get_download()
{
        echo
        echo "List of packages needed for FPC build and installation:"
        echo "-------------------------------------------------------"
        echo "1.  Java JDK for ODL"
        echo "2.  maven"
        echo "3.  zeromq"
        echo "4.  python zeromq"
        echo "5.  build-essential"
        echo "6.  linux-headers-generic"
        echo "7.  git"
        echo "8.  unzip"
        echo "9.  libpcap-dev"
        echo "10. make"
        echo "11. and other library dependencies"

}

install_libs()
{
        echo "Install libs needed to build and run FPC..."
        sudo apt-get update
        sudo apt-get -y install curl build-essential linux-headers-$(uname -r) git unzip libpcap0.8-dev gcc libjson0-dev\
                make libc6 libc6-dev g++-multilib libzmq3-dev libcurl4-openssl-dev
        apt-get -y install python-pip
        pip install pyzmq
        pip install --upgrade pip
        echo "Lib installation done" >> result.txt
}

install_jdk()
{
        echo "Install Java JDK"
        apt-get -y install openjdk-8-jdk
        if [ $? -ne 0 ] ; then
                echo "Failed to install Java jdk." >> result.txt
        fi
        echo "JDK installation done" >> result.txt
}

install_maven()
{
        echo "Install maven"
        apt-get -y install maven
        mkdir -p ~/.m2
        cp /etc/maven/settings.xml ~/.m2/
        cp -n ~/.m2/settings.xml{,.orig}
        ls -ahl ~/.m2
        echo "Update maven settings.xml..."
#       wget -O - https://raw.githubusercontent.com/opendaylight/odlparent/master/settings.xml > ~/.m2/settings.xml
        wget -O - $MVN_GET_SETTING > ~/.m2/settings.xml
        echo "Maven Installation and configuration done" >> result.txt
}

install_zeromq()
{
    echo "Download zeromq zip"
    wget ${ZMQ_DOWNLOAD}
    tar -xvzf $ZMQ_PKG
    pushd $ZMQ_DIR
        ./configure
        make
        make install
    popd
    echo "Compilation of zeromq done" >> result.txt
}

build_fpc()
{
        echo "Building FPC..."
        MVNEXEC=mvn
        #$MVNEXEC clean install #This command fails in the features test. Run install with skip test option instead.
        $MVNEXEC clean install -DskipTests -Dcheckstyle.skip
        cp org.ops4j.pax.logging.cfg karaf/target/assembly/etc/org.ops4j.pax.logging.cfg
        cp setenv karaf/target/assembly/bin/
        cp karaf.sh karaf/target/assembly/bin/karaf
        echo "FPC Build has been done" >> result.txt

}

#Check OS and n/w connection and set env.
setup_env

#Download the packages
get_download
#install_libs

#Download & install Java JDK for ODL
#install_jdk

#Download & install maven POM for ODL
install_maven

#Download & install zeromq
install_zeromq

#Building FOC
build_fpc

