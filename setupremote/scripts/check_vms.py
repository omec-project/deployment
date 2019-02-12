import threading
import constants_spgw as constants
import ConfigParser
import ipaddress
import time
import os
import check_vms_constants
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
   |   |             +-----------------------------------------+    |  |
   |   |             |                   SPGWC        	       |    |  |
   |   |             |                                         |    |  |
   |   |             +-----------------------------------------+    |  |
   |   |                    |         +----------+                  |  |
   |   |                    +FPCNB----|   FPC    |                  |  |
   |   |                              |          |                  |  |
   |   |                    +FPCSB----+----------+                  |  |
   |   |                    |                                       |  |
   |   |             +-----------------------------------------+    |  |
   |   +------------ |                                         |----+  |
   +----S1U----------|                   SPGWU                |--SGI--+
                     +-----------------------------------------+
"""
status=""
host_change_status=""
hosts={}
hosts_list=[]
status_cmd = check_vms_constants.status_lcmd
host_change_cmd=check_vms_constants.host_change_cmd

def get_hosts(config):
    global hosts
    for sect in config.sections():
        if constants.INSTANCE_TYPES.__contains__(sect) and not config.get(sect,
                                             constants.INSTANCE_COUNT) == "0":
            host_type=config.get(sect, constants.HOST_TYPE)
            ip=config.get("HOST", host_type).split('@')[1].split('"')[0]
            hosts[sect]=ip
    for key, value in config.items("HOST"):
        ip=value.split('@')[1].split('"')[0]
        if ip in hosts.values():
            hosts_list.append(ip)

def parse_ini_file():
    config = ConfigParser.ConfigParser()
    config.optionxform = str
    config.read(constants.INPUT_FILE_PATH)
    return config

def check_connectivity(config,temp_host_list):
    print "Check connectivity started"
    global diagram
    global hosts
    running_vms=set()
    test_result = '\033[40;32m{}\033[m'.format("TEST PASSED")
    for value in temp_host_list:
        f = os.popen(' sudo ssh '+value+' virsh list | awk \'NR >2 { print $2 }\'')
        lines = f.read().strip('\n')
        running_vms.update(lines.splitlines())
#    print("Following VMs are running:\n"+running_vms+"\n")
    for src_host in config.sections():
        if src_host.lower() in running_vms and constants.INSTANCE_TYPES.__contains__(
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
                       # print("Checking " + src_host + ":" + interface + ".....")
                        dest_ip = config.get(dest_host, "NETWORK.1." + interface + "_IP")
                        f = os.popen('sudo ssh '+hosts.get(src_host)+' virsh domifaddr ' + str( src_host).lower() + ' |grep ipv4 |awk \'{print $4}\' |cut -d \'/\' -f1')
                        src_ip = f.read().strip('\n')
                        #print src_ip
                        print(src_host+"<-----"+interface+"-------->"+dest_host)
                        if dest_host == "SPGWU" or dest_host == "IL_NPERF":
                            #Comment below one line when DP is up
                            continue
                            f = os.popen(
                                'sudo ssh '+hosts.get(src_host)+' ssh -q -o \'StrictHostKeyChecking no\' -i /home/ubuntu/.ssh/id_rsa ubuntu@' + src_ip + ' python /opt/ngic/dpdk/tools/dpdk-devbind.py --status | awk \'/drv=igb_uio/{count++} END{print count}\'')
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
                            f = os.popen('sudo ssh '+hosts.get(src_host)+' "ssh -q -o \'StrictHostKeyChecking no\' -i /home/ubuntu/.ssh/id_rsa ubuntu@' + src_ip + ' \'ping -q -c 5 -W 1 ' + dest_ip + '\'"')
                            result = f.read().strip('\n')
                        #    print 'ssh '+hosts.get(src_host)+' ssh -q -o \'StrictHostKeyChecking no\' -i /home/ubuntu/.ssh/id_rsa ubuntu@' + src_ip + ' \'ping -q -c 5 -W 1 ' + dest_ip + '\''
                         #   print result
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




def nth_repl(s, sub, repl, nth):
    find = s.find(sub)
    i = find != -1
    while find != -1 and i != nth:
        find = s.find(sub, find + 1)
        i += 1
    if i == nth:
        return s[:find]+repl+s[find + len(sub):]
    return s


class STATUS(object):

    def __init__(self):
        thread = threading.Thread(target=self.run, args=())
        thread.daemon = True
        thread.start()

    def run(self):
         global status_cmd
         global status
         while True:
            f = os.popen(status_cmd)
            status= f.read().strip('\n')

            time.sleep(check_vms_constants.event_interval)


class HOST_CHANGE(object):

    def __init__(self):
        thread = threading.Thread(target=self.run, args=())
        thread.daemon = True
        thread.start()

    def run(self):
        global host_change_status
        global hosts_list
        global status_cmd
        global status
        global host_change_cmd
        while True:
            if "ssh" in host_change_cmd:
                f = os.popen(host_change_cmd)
                host_change_status= f.read().strip('\n')

            if 'terraform_setup : Deploy' in status and len(hosts_list)>0:
                 temp_host=str(hosts_list.pop(0))
                 host_change_cmd="ssh "+temp_host+" "+check_vms_constants.host_change_cmd
                 status_cmd="ssh "+temp_host+" "+check_vms_constants.status_rcmd

            if 'PLAY RECAP' in host_change_status and len(hosts_list)>0:
                 temp_host = str(hosts_list.pop(0))
                 host_change_cmd = "ssh " + temp_host + " " + check_vms_constants.host_change_cmd
                 status_cmd = "ssh " + temp_host + " " + check_vms_constants.status_rcmd

            time.sleep(check_vms_constants.event_interval)

class Fun(object):

    def __init__(self,vm,created_cmd,configured_cmd):
        global hosts
        self.vm=vm
        self.created_cmd="ssh "+str(hosts.get(vm))+" "+created_cmd
        self.configured_cmd="ssh "+str(hosts.get(vm))+" "+configured_cmd
        thread = threading.Thread(target=self.run, args=())
        thread.daemon = True
        thread.start()

    def run(self):
        create_check_done=False
        configured_check_done=False
        while True:
            global diagram
            if not create_check_done:
               f = os.popen(self.created_cmd)
               create_status= f.read().strip('\n')
               if create_status:
                  if self.vm == 'MME' or self.vm == 'DB' or self.vm == 'FPC':
                     diagram = nth_repl(diagram,self.vm, '\033[40;33m{}\033[m'.format(self.vm),2)
                  else:
                     diagram = nth_repl(diagram,self.vm, '\033[40;33m{}\033[m'.format(self.vm),1)
                  create_check_done=True

            if not configured_check_done:
               f = os.popen(self.configured_cmd)
               configured_status=f.read().strip('\n')
               if configured_status:
                  if self.vm == 'MME' or self.vm == 'DB' or self.vm == 'FPC':
                     diagram = nth_repl(diagram,self.vm, '\033[40;32m{}\033[m'.format(self.vm),2)
                  else:
                    diagram = nth_repl(diagram,self.vm, '\033[40;32m{}\033[m'.format(self.vm),1)
                  configured_check_done=True

            if create_check_done and configured_check_done:
               break

            time.sleep(check_vms_constants.event_interval)



get_hosts(parse_ini_file())
for key, value in hosts.items():
    os.system('ssh '+value+' "sudo touch /tmp/deploy.log"')

temp_host_list = hosts_list[:]

vm_status=STATUS()
host_change=HOST_CHANGE()
vms=check_vms_constants.vms

for i in range(len(vms)):
    fun=Fun(vms[i],eval('check_vms_constants.'+vms[i].lower().replace('-','_')+'_created_cmd'),eval('check_vms_constants.'+vms[i].lower().replace('-','_')+'_configured_cmd'))


timeout = time.time() + 60*3 
while True:
    if 'PLAY RECAP' in host_change_status and len(hosts_list)==0:
        break
    os.system(['clear', 'cls'][os.name == 'nt'])
    print(diagram)
    print('Progress : ' +status)
    time.sleep(5)

check_connectivity(parse_ini_file(),temp_host_list)


