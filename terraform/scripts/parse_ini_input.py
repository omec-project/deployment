'''
Created on May 17, 2018

@author: amiwankh

@purpose : script takes input as INI file : c3po_ngic_input.cfg
 validate it and generates the terraform variable file
 which will be used by terraform deployment

@dependencies :  pip install ipaddress

'''
import constants
import ConfigParser
import ipaddress
import os

host_ip = ""
host_type = "HOST_TYPE1"
config = ConfigParser.ConfigParser()

def find_host_interface(config):
    global host_ip
    int_name = ""
    for key, value in config.items("HOST"):
        for i in str(value).split(';'):
            ip_add = i.split('@')[1].replace('"','')
            int_temp = os.popen("ifconfig |grep -B1 'inet addr:"+ip_add+"'|awk '$1 !=\"inet\" && $1 != \"--\" {print $1}'")
            int_name = int_temp.read().strip('\n')
            #print int_name
            if int_name:
               break
        if int_name:
           break
    f = os.popen('ifconfig '+int_name+' | grep "inet\ addr" | cut -d: -f2 | cut -d" " -f1')
    host_ip = f.read().strip('\n')
    print("HOST IP "+host_ip)


def create_host_type_file(config):
    global host_type
    temp_host_type=host_type.split(".")[0]
    file = open(constants.HOST_TYPE_FILE_PATH, "w")
    file.write("\n" + temp_host_type + "\n")
    for key, value in config.items(temp_host_type):
        file.write(key + " = " + str(value) + "\n")
    file.close()

def gen_ansible_inv_file(config):
    file = open("../../ansible/group_vars/all", "w")
    components = ["MME", "HSS", "DB", "FPC", "SGWC", "PGWC", "SGWU", "PGWU", "SPGWU", "SPGWC", "SGX_DLRIN", "SGX_DLRRTR", "SGX_DLROUT", "SGX_KMS", "CTF", "CDF", "DNS"]

    file.write("---\n")
    file.write(" "+"githubuser: \"\"\n")
    file.write(" "+"githubpassword: \"\"\n")

    for section in config.sections():
        if components.__contains__(section):
            for key, value in config.items(section):
                if key.startswith(constants.NETWORK):
                    tmp_key = key.split(".")[2]
                    file.write(" "+ section+"_"+tmp_key + ": " + str(value) + "\n")
    file.close()

def create_interfaces(config):
    for section in config.sections():
        if constants.INSTANCE_TYPES.__contains__(section) and host_type==str(config.get(section, constants.HOST_TYPE)) and not config.get(section,
                                                                             constants.INSTANCE_COUNT) == "0":
            # f =open("interfaces/interface-"+str(section).lower(),"w")
            f = open("../interfaces-" + str(section).lower(), "w")
            f.write(
                "# This file describes the network interfaces available on your system\n# and how to activate them. For more information, see interfaces(5).\n")
            f.write(
                "source /etc/network/interfaces.d/*\n# The loopback network interface\nauto lo\niface lo inet loopback\n# The primary network interface\n")
            f.write("auto ens3\niface ens3 inet dhcp\n\n")
            count = 4
            for key, value in config.items(section):
                if key.startswith(constants.NETWORK):
                    arr = key.split(".")[2].split("_")
                    temp_key = (arr[0] + "_" + arr[1]) if (len(arr)) == 3 else arr[0]
                    if temp_key == constants.MGMT:
                        continue
                    address = str(value).replace('"', '')
                    network = str(config.get(constants.NETWORKS, temp_key)).replace('"', '')
                    netmask = str(
                        ipaddress.ip_network(unicode(str(config.get(constants.NETWORKS, temp_key)).replace('"', '')),
                                             strict=False).netmask)
                    f.write("# The " + str(temp_key) + " communication interface")
                    f.write("\nauto ens" + str(count) + "\niface ens" + str(
                        count) + " inet static\n\taddress\t" + address + "\n\tnetmask\t" + netmask + "\n\tnetwork\t" +
                            str(network).split("/")[0] + "\n\n")
                    count = count + 1
            f.close()



'''
 Method to parse the input INI file
'''


def parse_ini_file():
    global config
    config.optionxform = str
    config.read(constants.INPUT_FILE_PATH)
    find_host_interface(config)
    validate_instance_config(config)
    return config


'''

Method to validate instance configuration

'''


def validate_instance_config(config):
    errors = []
    global host_type

    global host_ip
    file = open(constants.HOST_TYPE_FILE_PATH, "w")
    for section in config.sections():
        if constants.INSTANCE_TYPES.__contains__(section):
            required_keys = ["INSTANCE_COUNT", "CPU", "MEMORY", "DISK", "HOST_TYPE", "NETWORK", "CORE_RANGE"]
            for key, value in config.items(section):
                if not key.startswith(
                        constants.NETWORK) and required_keys.__contains__(key):
                    required_keys.remove(key)
                elif key.startswith(constants.NETWORK):
                    required_keys.remove("NETWORK") if required_keys.__contains__("NETWORK") else "Do nothing"
                    arr = key.split(".")[2].split("_")
                    temp_key = (arr[0] + "_" + arr[1]) if (len(arr)) == 3 else arr[0]
                    if not eval('constants.' + section).__contains__(temp_key):
                        errors.append("[ERROR] Wrong n/w element " + key + " in section " + section)
                    if not ipaddress.ip_address(unicode(str(value).replace('"', ''))) in ipaddress.ip_network(
                            unicode(str(config.get(constants.NETWORKS, temp_key)).replace('"', '')), strict=False):
                        errors.append("[ERROR] Not valid ip address " + value + " for a " + temp_key + " network")
            if not section == "DNS" and not section == "CTF" and len(required_keys) > 0:
                errors.append("Missing properties for " + section + " are " + str(required_keys)[1:-1])
        elif section == "HOST":
            for key, value in config.items(section):
                if host_ip in str(value):
                   host_type=key
                   print("HOST TYPE is " + host_type)
                   break
        elif str(section).startswith(constants.HOST_TYPE):
            file.write("\n"+section + "\n")
            for key, value in config.items(section):
                file.write(key + " = " + str(value) + "\n")
    if len(errors) > 0:
        raise ValueError(errors)
    file.close()
    return False


''''

Method to parse the specifeid CPU range 

Hyphen ('-') can be specified for CPU range
Comma (',') can be used to specify individual CPUs

'''

def getCpusRange(cpus):
    if "-" in cpus:
        start,end = cpus.split("-")
        temp_range = range(int(start), int(end)+1)
        cpu_range = ', '.join('"{0}"'.format(w) for w in temp_range)
        return "["+cpu_range+"]"
    elif "," in cpus:
        temp_range = cpus.split(",")
        cpu_range = ', '.join('"{0}"'.format(w) for w in temp_range)
        return "["+cpu_range+"]"
    else:
        return "[\""+cpus+"\"]"


''''

Method to build the SGWC config

'''


def build_sgwc_config(src_config, section):
    target_config = {}
    instance_count = src_config.get(section, constants.INSTANCE_COUNT)

    target_config[constants.TF_INSTANCE_COUNT_SGWC] = instance_count
    target_config[constants.TF_CPU_COUNT_SGWC] = src_config.get(section, constants.INSTANCE_CPU)
    target_config[constants.TF_CORE_RANGE_SGWC] = getCpusRange(src_config.get(section, constants.INSTANCE_CORE_RANGE))
    target_config[constants.TF_MEMORY_SGWC] = int(src_config.get(section, constants.INSTANCE_MEMORY)) * 1024
    target_config[constants.TF_DISK_SGWC] = int(src_config.get(section, constants.INSTANCE_DISK)) * 1024 * 1024 * 1024
    target_config[constants.TF_IP_S11_VM_NGIC_CP1_PCI] = src_config.get(section,
                                                                        constants.NETWORK + "." + instance_count + "." + constants.S11_IP)
    target_config[constants.TF_IP_ODL_NB_VM_NGIC_CP1_PCI] = src_config.get(section,
                                                                           constants.NETWORK + "." + instance_count + "." + constants.FPCNB_IP)
    target_config[constants.TF_IP_S5S8_SGWC_VM_NGIC_CP1_PCI] = src_config.get(section,
                                                                              constants.NETWORK + "." + instance_count + "." + constants.S5S8_SGWC_IP)
    return target_config

''''

Method to build the SPGWC config

'''


def build_spgwc_config(src_config, section):
    target_config = {}
    instance_count = src_config.get(section, constants.INSTANCE_COUNT)

    target_config[constants.TF_INSTANCE_COUNT_SPGWC] = instance_count
    target_config[constants.TF_CPU_COUNT_SPGWC] = src_config.get(section, constants.INSTANCE_CPU)
    target_config[constants.TF_CORE_RANGE_SPGWC] = getCpusRange(src_config.get(section, constants.INSTANCE_CORE_RANGE))
    target_config[constants.TF_MEMORY_SPGWC] = int(src_config.get(section, constants.INSTANCE_MEMORY)) * 1024
    target_config[constants.TF_DISK_SPGWC] = int(src_config.get(section, constants.INSTANCE_DISK)) * 1024 * 1024 * 1024
    target_config[constants.TF_IP_S11_VM_NGIC_CP1_PCI] = src_config.get(section,
                                                                        constants.NETWORK + "." + instance_count + "." + constants.S11_IP)
    target_config[constants.TF_IP_ODL_NB_VM_NGIC_CP1_PCI] = src_config.get(section,
                                                                           constants.NETWORK + "." + instance_count + "." + constants.FPCNB_IP)
    target_config[constants.TF_IP_S5S8_SGWC_VM_NGIC_CP1_PCI] = src_config.get(section,
                                                                              constants.NETWORK + "." + instance_count + "." + constants.S5S8_SGWC_IP)
    return target_config


''''
Method to build the SGWU config

'''


def build_sgwu_config(src_config, section):
    target_config = {}
    instance_count = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_INSTANCE_COUNT_SGWU] = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_CPU_COUNT_SGWU] = src_config.get(section, constants.INSTANCE_CPU)
    target_config[constants.TF_CORE_RANGE_SGWU] = getCpusRange(src_config.get(section, constants.INSTANCE_CORE_RANGE))
    target_config[constants.TF_MEMORY_SGWU] = int(src_config.get(section, constants.INSTANCE_MEMORY)) * 1024
    target_config[constants.TF_DISK_SGWU] = int(src_config.get(section, constants.INSTANCE_DISK)) * 1024 * 1024 * 1024
    try:
        target_config[constants.TF_S1U_PHY_DEV_SGWU] = src_config.get(section, constants.S1U_PHY_DEVICE_SGWU)
    except:
        pass
    try:
        target_config[constants.TF_S5S8_PHY_DEV_SGWU] = src_config.get(section, constants.S5S8_PHY_DEVICE_SGWU)
    except:
        pass
    target_config[constants.TF_IP_ODL_SB_VM_NGIC_DP1_PCI] = src_config.get(section,
                                                                           constants.NETWORK + "." + instance_count + "." + constants.FPCSB_IP)
    target_config[constants.TF_IP_S1U_VM_NGIC_DP1_PCI] = src_config.get(section,
                                                                        constants.NETWORK + "." + instance_count + "." + constants.S1U_IP)
    target_config[constants.TF_IP_S5S8_VM_NGIC_DP1_PCI] = src_config.get(section,
                                                                         constants.NETWORK + "." + instance_count + "." + constants.S5S8_SGWU_IP)

    return target_config

''''
Method to build the SPGWU config

'''


def build_spgwu_config(src_config, section):
    target_config = {}
    instance_count = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_INSTANCE_COUNT_SPGWU] = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_CPU_COUNT_SPGWU] = src_config.get(section, constants.INSTANCE_CPU)
    target_config[constants.TF_CORE_RANGE_SPGWU] = getCpusRange(src_config.get(section, constants.INSTANCE_CORE_RANGE))
    target_config[constants.TF_MEMORY_SPGWU] = int(src_config.get(section, constants.INSTANCE_MEMORY)) * 1024
    target_config[constants.TF_DISK_SPGWU] = int(src_config.get(section, constants.INSTANCE_DISK)) * 1024 * 1024 * 1024
    try:
        target_config[constants.TF_S1U_PHY_DEV_SGWU] = src_config.get(section, constants.S1U_PHY_DEVICE_SGWU)
    except:
        pass
    try:
        target_config[constants.TF_SGI_PHY_DEV_PGWU] = src_config.get(section, constants.SGI_PHY_DEVICE_PGWU)
    except:
        pass
    target_config[constants.TF_IP_ODL_SB_VM_NGIC_DP1_PCI] = src_config.get(section,
                                                                           constants.NETWORK + "." + instance_count + "." + constants.FPCSB_IP)
    target_config[constants.TF_IP_S1U_VM_NGIC_DP1_PCI] = src_config.get(section,
                                                                        constants.NETWORK + "." + instance_count + "." + constants.S1U_IP)
    target_config[constants.TF_IP_SGI_VM_NGIC_DP2_PCI] = src_config.get(section,
                                                                         constants.NETWORK + "." + instance_count + "." + constants.SGI_IP)

    return target_config

''''

Method to build the PGWC config

'''


def build_pgwc_config(src_config, section):
    target_config = {}
    instance_count = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_INSTANCE_COUNT_PGWC] = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_CPU_COUNT_PGWC] = src_config.get(section, constants.INSTANCE_CPU)
    target_config[constants.TF_CORE_RANGE_PGWC] = getCpusRange(src_config.get(section, constants.INSTANCE_CORE_RANGE))
    target_config[constants.TF_MEMORY_PGWC] = int(src_config.get(section, constants.INSTANCE_MEMORY)) * 1024
    target_config[constants.TF_DISK_PGWC] = int(src_config.get(section, constants.INSTANCE_DISK)) * 1024 * 1024 * 1024
    target_config[constants.TF_IP_ODL_NB_VM_NGIC_CP2_PCI] = src_config.get(section,
                                                                           constants.NETWORK + "." + instance_count + "." + constants.FPCNB_IP)
    target_config[constants.TF_IP_S5S8_PGWC_VM_NGIC_CP2_PCI] = src_config.get(section,
                                                                              constants.NETWORK + "." + instance_count + "." + constants.S5S8_PGWC_IP)

    return target_config


''''

Method to build the PGWU config

'''


def build_pgwu_config(src_config, section):
    target_config = {}
    instance_count = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_INSTANCE_COUNT_PGWU] = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_CPU_COUNT_PGWU] = src_config.get(section, constants.INSTANCE_CPU)
    target_config[constants.TF_CORE_RANGE_PGWU] = getCpusRange(src_config.get(section, constants.INSTANCE_CORE_RANGE))
    target_config[constants.TF_MEMORY_PGWU] = int(src_config.get(section, constants.INSTANCE_MEMORY)) * 1024
    target_config[constants.TF_DISK_PGWU] = int(src_config.get(section, constants.INSTANCE_MEMORY)) * 1024 * 1024 * 1024
    try:
        target_config[constants.TF_SGI_PHY_DEV_PGWU] = src_config.get(section, constants.SGI_PHY_DEVICE_PGWU)
    except:
        pass
    try:
        target_config[constants.TF_S5S8_PHY_DEV_PGWU] = src_config.get(section, constants.S5S8_PHY_DEVICE_PGWU)
    except:
        pass
    target_config[constants.TF_IP_ODL_SB_VM_NGIC_DP2_PCI] = src_config.get(section,
                                                                           constants.NETWORK + "." + instance_count + "." + constants.FPCSB_IP)
    target_config[constants.TF_IP_S5S8_VM_NGIC_DP2_PCI] = src_config.get(section,
                                                                         constants.NETWORK + "." + instance_count + "." + constants.S5S8_PGWU_IP)
    target_config[constants.TF_IP_SGI_VM_NGIC_DP2_PCI] = src_config.get(section,
                                                                        constants.NETWORK + "." + instance_count + "." + constants.SGI_IP)

    return target_config


''''

Method to build the FPC config

'''


def build_fpc_config(src_config, section):
    target_config = {}
    instance_count = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_INSTANCE_COUNT_FPC] = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_CPU_COUNT_FPC] = src_config.get(section, constants.INSTANCE_CPU)
    target_config[constants.TF_CORE_RANGE_FPC] = getCpusRange(src_config.get(section, constants.INSTANCE_CORE_RANGE))
    target_config[constants.TF_MEMORY_FPC] = int(src_config.get(section, constants.INSTANCE_MEMORY)) * 1024
    target_config[constants.TF_DISK_FPC] = int(src_config.get(section, constants.INSTANCE_DISK)) * 1024 * 1024 * 1024
    target_config[constants.TF_IP_ODL_SB_VM_FPC_ODL1_PCI] = src_config.get(section,
                                                                           constants.NETWORK + "." + instance_count + "." + constants.FPCSB_IP)
    target_config[constants.TF_IP_ODL_NB_VM_FPC_ODL1_PCI] = src_config.get(section,
                                                                           constants.NETWORK + "." + instance_count + "." + constants.FPCNB_IP)

    return target_config


''''

Method to build the MME config

'''


def build_mme_config(src_config, section):
    target_config = {}
    instance_count = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_INSTANCE_COUNT_MME] = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_CPU_COUNT_MME] = src_config.get(section, constants.INSTANCE_CPU)
    target_config[constants.TF_CORE_RANGE_MME] = getCpusRange(src_config.get(section, constants.INSTANCE_CORE_RANGE))
    target_config[constants.TF_MEMORY_MME] = int(src_config.get(section, constants.INSTANCE_MEMORY)) * 1024
    target_config[constants.TF_DISK_MME] = int(src_config.get(section, constants.INSTANCE_DISK)) * 1024 * 1024 * 1024
    #target_config[constants.TF_S1MME_PHY_DEV_MME] = src_config.get(section, constants.S1MME_PHY_DEV_MME)
    try:
       target_config[constants.TF_S1MME_PHY_DEV_MME] = src_config.get(section, constants.S1MME_PHY_DEV_MME)
    except:
       pass
    target_config[constants.TF_IP_MME_S11_VM_C3PO_MME1_PCI] = src_config.get(section,
                                                                             constants.NETWORK + "." + instance_count + "." + constants.S11_IP)
    target_config[constants.TF_IP_MME_S1MME_VM_C3PO_MME1_PCI] = src_config.get(section,
                                                                               constants.NETWORK + "." + instance_count + "." + constants.S1MME_IP)
    target_config[constants.TF_IP_MME_S6_VM_C3PO_MME1_PCI] = src_config.get(section,
                                                                            constants.NETWORK + "." + instance_count + "." + constants.S6A_IP)

    return target_config


''''

Method to build the HSS config

'''


def build_hss_config(src_config, section):
    target_config = {}
    instance_count = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_INSTANCE_COUNT_HSS] = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_CPU_COUNT_HSS] = src_config.get(section, constants.INSTANCE_CPU)
    target_config[constants.TF_CORE_RANGE_HSS] = getCpusRange(src_config.get(section, constants.INSTANCE_CORE_RANGE))
    target_config[constants.TF_MEMORY_HSS] = int(src_config.get(section, constants.INSTANCE_MEMORY)) * 1024
    target_config[constants.TF_DISK_HSS] = int(src_config.get(section, constants.INSTANCE_DISK)) * 1024 * 1024 * 1024
    target_config[constants.TF_IP_HSS_DB_VM_C3PO_HSS1_PCI] = src_config.get(section,
                                                                            constants.NETWORK + "." + instance_count + "." + constants.DB_IP)
    target_config[constants.TF_IP_HSS_S6_VM_C3PO_HSS1_PCI] = src_config.get(section,
                                                                            constants.NETWORK + "." + instance_count + "." + constants.S6A_IP)

    return target_config


''''

Method to build the DB config

'''


def build_db_config(src_config, section):
    target_config = {}
    instance_count = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_INSTANCE_COUNT_DB] = src_config.get(section, constants.INSTANCE_COUNT)
    target_config[constants.TF_CPU_COUNT_DB] = src_config.get(section, constants.INSTANCE_CPU)
    target_config[constants.TF_CORE_RANGE_DB] = getCpusRange(src_config.get(section, constants.INSTANCE_CORE_RANGE))
    target_config[constants.TF_MEMORY_DB] = int(src_config.get(section, constants.INSTANCE_MEMORY)) * 1024
    target_config[constants.TF_DISK_DB] = int(src_config.get(section, constants.INSTANCE_DISK)) * 1024 * 1024 * 1024
    target_config[constants.TF_IP_DBN_HSS_VM_C3PO_DBN1_PCI] = src_config.get(section,
                                                                             constants.NETWORK + "." + instance_count + "." + constants.DB_IP)

    return target_config


def build_frame_type(src_config, section):
    target_config = {}
#    frame_type = src_config.get(section, constants.FRAME_TYPE)
    target_config[constants.TF_FRAME_TYPE] = (src_config.get(section, constants.FRAME_TYPE))
    return target_config

''''

Method to build the terraform variable file (*.tfvars)

'''


def build_configuration(src_config):
    target_config = {}

    for section in src_config.sections():
        if section == constants.FRAME:
           target_config.update(build_frame_type(src_config, section))
        if constants.INSTANCE_TYPES.__contains__(section) and host_type == str(src_config.get(section, constants.HOST_TYPE)) and not src_config.get(section,
                                                                                 constants.INSTANCE_COUNT) == "0":
                if section == constants.INSTANCE_SGWC:
                    target_config.update(build_sgwc_config(src_config, section))
                if section == constants.INSTANCE_SPGWC:
                    target_config.update(build_spgwc_config(src_config, section))

                if section == constants.INSTANCE_PGWC:
                    target_config.update(build_pgwc_config(src_config, section))

                if section == constants.INSTANCE_FPC:
                    target_config.update(build_fpc_config(src_config, section))

                if section == constants.INSTANCE_MME:
                    target_config.update(build_mme_config(src_config, section))

                if section == constants.INSTANCE_HSS:
                    target_config.update(build_hss_config(src_config, section))

                if section == constants.INSTANCE_DB:
                    target_config.update(build_db_config(src_config, section))

                if section == constants.INSTANCE_SGWU:
                    target_config.update(build_sgwu_config(src_config, section))

                if section == constants.INSTANCE_SPGWU:
                    target_config.update(build_spgwu_config(src_config, section))

                if section == constants.INSTANCE_PGWU:
                    target_config.update(build_pgwu_config(src_config, section))


    return target_config


'''

Method to write terraform variable to file

'''


def write_variable_file(target_config):
    file = open(constants.TERRAFORM_VAR_FILE_PATH, "w")
    for key, value in target_config.items():
        file.write(key + " = " + str(value) + "\n")

    file.close()

if __name__ == '__main__':
    # writeVariableFile()
    # src_config = parseInputFile()
    # parseIniFile()
    # testing()
    try:
        parse_ini_file()
        #write_variable_file(build_configuration(parse_ini_file()))
        write_variable_file(build_configuration(config))
        print("--------------------------------------------------------")
        print("Output file generated at : ", constants.TERRAFORM_VAR_FILE_PATH)
        print("--------------------------------------------------------")
        create_interfaces(config)
        print("Interfaces file generated at interfaces dir")
        print("--------------------------------------------------------")
        create_host_type_file(config)
        print("Host type file generated at current dir")
        print("--------------------------------------------------------")
        gen_ansible_inv_file(config)
        print("ansible group  file generated at ansible group_var dir")
        print("--------------------------------------------------------")
    except ValueError as err:
        print(err)
