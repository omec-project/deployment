import constants
import ConfigParser
import ipaddress
import os

diagram = """\
                                     +--------------+
      Control+----------------> S1MME|     MME      |
       Path                  +-------|              |        
                             |       +--------------+   
                             |               |
                             |              S6A
                             |               |         
 +----------+                |       +--------------+           +----------+
 | Traffic  |                |       |     HSS      |           | Traffic  |
 | Generator|               S11      |              |           | Receiver |
 |          |                |       +--------------+           |          |
 |          |                |              |                   |          | 
 +-+---+----+                |              DB                  +---+--+---+
   |   |                     |              |                       |  |
   |   |                     |       +--------------+               |  |
   |   |                     |       |      DB      |               |  |    
   |   | Data Path           |       |              |               |  |
   |   |                     |       +--------------+               |  |
   |   |                     |                                      |  |
   |   |                     |                                      |  |
   |   |             +------------+                +-----------+    |  |
   |   |             |   SGWC     |----S5S8_PGWC---|   PGWC    |    |  |
   |   |             |            |                |           |    |  |
   |   |             +------------+                 +----------+    |  |
   |   |                    |         +----------+        |         |  |
   |   |                    +FPCNB----|   FPC    |---FPCNB+         |  |
   |   |                              |          |                  |  |
   |   |                    +FPCSB----+----------+---FPCSB+         |  |
   |   |                    |                             |         |  |
   |   |             +------------+                +-----------+    |  |
   |   +------------ |     S1U    |                |           |----+  |
   +----S1U----------|            |-----S5S8_SGWU--|   PGWU    |--SGI--+
                     +------------+                +-----------+
"""


def parse_ini_file():
    config = ConfigParser.ConfigParser()
    config.optionxform = str
    config.read(constants.INPUT_FILE_PATH)
    return config


def check_connectivity(config):
    global diagram
    test_result = '\033[40;32m{}\033[m'.format("TEST PASSED")
    f = os.popen('virsh list | awk \'NR >2 { print $2 }\'')
    running_vms = f.read().strip('\n')
    # print("Following VMs are running:\n"+running_vms+"\n")
    for src_host in config.sections():
        if running_vms.__contains__(str(src_host).lower()) and constants.INSTANCE_TYPES.__contains__(
                src_host) and not config.get(src_host,
                                             constants.INSTANCE_COUNT) == "0":
            # print("Checking "+src_host+" ....connection")
            # print("....................................\n")
            os.system(['clear', 'cls'][os.name == 'nt'])
            print(diagram)
            for dest_host in eval('constants.' + src_host + '_CONN'):
                for interface in eval('constants.' + dest_host):
                    temp = str(interface).replace('_S', '_P') if str(interface).__contains__('_S') else str(
                        interface).replace('_P', '_S') if str(
                        interface).__contains__('_P') else interface
                    if eval('constants.' + src_host).__contains__(temp):
                        print("Checking " + src_host + ":" + interface + ".....")
                        dest_ip = config.get(dest_host, "NETWORK.1." + interface + "_IP")
                        f = os.popen('virsh domifaddr ' + str(
                            src_host).lower() + ' |grep ipv4 |awk \'{print $4}\' |cut -d \'/\' -f1')
                        src_ip = f.read().strip('\n')
                        # print(src_host+"<-----"+interface+"-------->"+dest_host)
                        if dest_host == "PGWU" or dest_host == "SGWU" or dest_host == "IL_NPERF":
                            f = os.popen(
                                'ssh -q -o \'StrictHostKeyChecking no\' -i /home/ubuntu/.ssh/id_rsa ubuntu@' + src_ip + ' python /opt/ngic/dpdk/tools/dpdk-devbind.py --status | awk \'/drv=igb_uio/{count++} END{print count}\'')
                            result = f.read().strip('\n')
                            if not "2" in str(result):
                                # print("Not Bound to dpdk"+result+"\n")
                                test_result = '\033[40;31m{}\033[m'.format("TEST FAILED")
                                if interface == 'DB':
                                    diagram = diagram.replace(interface, '\033[40;31m{}\033[m'.format(interface), 1)
                                else:
                                    diagram = diagram.replace(interface, '\033[40;31m{}\033[m'.format(interface))
                            else:
                                if interface == 'DB':
                                    diagram = diagram.replace(interface, '\033[40;32m{}\033[m'.format(interface), 1)
                                else:
                                    diagram = diagram.replace(interface, '\033[40;32m{}\033[m'.format(interface))
                                # print("Bound to dpdk\n")
                        else:
                            f = os.popen(
                                'ssh -q -o \'StrictHostKeyChecking no\' -i /home/ubuntu/.ssh/id_rsa ubuntu@' + src_ip + ' \'ping -q -c 5 -W 1 ' + dest_ip + '\'')
                            result = f.read().strip('\n')
                            if "errors" in str(result):
                                test_result = '\033[40;31m{}\033[m'.format("TEST FAILED")
                                if interface == 'DB':
                                    diagram = diagram.replace(interface, '\033[40;31m{}\033[m'.format(interface), 1)
                                else:
                                    diagram = diagram.replace(interface, '\033[40;31m{}\033[m'.format(interface))
                            # print("Not Connected\n"+result+"\n")
                            else:
                                if interface == 'DB':
                                    diagram = diagram.replace(interface, '\033[40;32m{}\033[m'.format(interface), 1)
                                else:
                                    diagram = diagram.replace(interface, '\033[40;32m{}\033[m'.format(interface))
                            # print("Connected\n")
                        break
    #  print("....................................\n\n")

    print(test_result)


if __name__ == '__main__':
    try:
        check_connectivity(parse_ini_file())
    except ValueError as err:
        print(err)
