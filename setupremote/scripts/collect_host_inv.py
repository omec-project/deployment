'''
Created on Sept 12, 2018

@author: awanare

@purpose : script takes input as INI file : c3po_ngic_input.cfg
 validate it and generates the terraform variable file
 which will be used by terraform deployment

@dependencies :  pip install ipaddress

'''
import constants
import ConfigParser
import ipaddress
import os
import yaml

config = ConfigParser.ConfigParser()
host_ip = ""

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



def validate_spgw_instance_config(config): 
     errors = []

     SGWC_COUNT = config.get("SGWC", constants.INSTANCE_COUNT)
     PGWC_COUNT = config.get("PGWC", constants.INSTANCE_COUNT)
     SGWU_COUNT = config.get("SGWU", constants.INSTANCE_COUNT)
     PGWU_COUNT = config.get("PGWU", constants.INSTANCE_COUNT)
     SPGWC_COUNT = config.get("SPGWC", constants.INSTANCE_COUNT)
     SPGWU_COUNT = config.get("SPGWU", constants.INSTANCE_COUNT)

     if (SPGWC_COUNT == SPGWU_COUNT == "1") and ( SGWC_COUNT == PGWC_COUNT == SGWU_COUNT == PGWU_COUNT == "0"): 
        print "Valid setup for spgw deployment" 

     elif (SPGWC_COUNT == SPGWU_COUNT == "0") and (SGWC_COUNT or PGWC_COUNT or SGWU_COUNT or PGWU_COUNT == "1" ):
        print "valid setup for S5S8 Deployment" 

     else:
        errors.append("Either use (SPGWC, SPGWU) or (SGWC, PGWC, SGWU, PGWU) combination")

     if len(errors) > 0:
        raise ValueError(errors)
     return False



def validate_host_type(sections): 
    global config

    for  key, value in config.items("HOST"):

        if config.get( sections, constants.HOST_TYPE) == key:
           return value.split('@')[1].split('"')[0]+"\n"



def sgx_build(sections):
    global config

    f = open("../ansible/group_vars/sgx.yml", "r+")

    data = yaml.load(f)

    if config.get('SGX', constants.SGX_BUILD1) == '"yes"':
        data['SGX_BUILD'] = "true"


    elif  config.get('SGX', constants.SGX_BUILD1) == '"no"':
        data['SGX_BUILD'] = "false"

    else: 
        print 'SGX_BUILD should be equal to yes|no'

    f.seek(0)
    f.truncate()
    yaml.dump(data, f, default_flow_style=False, explicit_start=True)


'''
 Method for update dns_type into group vars file

'''
def dns_type(sections):
    global config

    f = open("../ansible/group_vars/c3po.yml", "r+")
    FPC_COUNT = config.get("FPC", constants.INSTANCE_COUNT)
    data = yaml.load(f)
    if FPC_COUNT == "0": 
        data['WITH_FPC'] = "no"
    else:
        data['WITH_FPC'] = "yes"
 
    if config.get('DNS', constants.HOST_TYPE) ==  config.get('CTF', constants.HOST_TYPE) == config.get('CDF', constants.HOST_TYPE):
        data['DNS_TYPE'] = "allinone"
    else:
        data['DNS_TYPE'] = "distributed"


    f.seek(0)
    f.truncate()
    yaml.dump(data, f, default_flow_style=False, explicit_start=True)
 
    
'''
 Method to generate ansible inv file
'''

def gen_host_inv_file(config):
    ip_list = set() 
    SGWC_COUNT = config.get("SGWC", constants.INSTANCE_COUNT)
    PGWC_COUNT = config.get("PGWC", constants.INSTANCE_COUNT)
    SGWU_COUNT = config.get("SGWU", constants.INSTANCE_COUNT)
    PGWU_COUNT = config.get("PGWU", constants.INSTANCE_COUNT)
    SPGWC_COUNT = config.get("SPGWC", constants.INSTANCE_COUNT)
    SPGWU_COUNT = config.get("SPGWU", constants.INSTANCE_COUNT)
    MME_COUNT = config.get("MME", constants.INSTANCE_COUNT)
    HSS_COUNT = config.get("HSS", constants.INSTANCE_COUNT)
    DB_COUNT = config.get("DB", constants.INSTANCE_COUNT)
    FPC_COUNT = config.get("FPC", constants.INSTANCE_COUNT)
 
    for key, value in config.items("HOST"):

        if config.get("SPGWU", constants.HOST_TYPE) == config.get("SPGWC", constants.HOST_TYPE) == key:
     
            if (SPGWC_COUNT == SPGWU_COUNT == "1") and ( MME_COUNT or HSS_COUNT or DB_COUNT or FPC_COUNT == "1"):
                ip_list.add(value.split('@')[1].split('"')[0]+"  HOST_TYPE=\"spgw\"")
                break
     
        #elif (config.get("SPGWU", constants.HOST_TYPE)) == key != (config.get("SPGWC", constants.HOST_TYPE)):
        if (config.get("SPGWU", constants.HOST_TYPE)) == key != (config.get("SPGWC", constants.HOST_TYPE)):

            if (SPGWU_COUNT == "1"):
                ip_list.add(value.split('@')[1].split('"')[0]+"  HOST_TYPE=\"spgw\"")
               

        if (config.get("SGWU", constants.HOST_TYPE)) == key != (config.get("SGWC", constants.HOST_TYPE)):

           if (SGWU_COUNT == "1"):
	        ip_list.add(value.split('@')[1].split('"')[0]+"  HOST_TYPE=\"dp\"")

        if (config.get("MME", constants.HOST_TYPE) or config.get("FPC", constants.HOST_TYPE)) == key:

            if (MME_COUNT or HSS_COUNT or DB_COUNT or FPC_COUNT or SPGWC_COUNT or PGWC_COUNT == 1):
 	        ip_list.add(value.split('@')[1].split('"')[0]+"  HOST_TYPE=\"cp\"")

    file = open(constants.REMOTE_HOST_INV_FILE_PATH, "w")
    file.write("[hosts]\n")

    for host_inv in ip_list:
        file.write(host_inv+"\n")
    file.close()

    file = open(constants.SGX_HOST_INV_FILE_PATH, "w")
    if config.get('SGX', constants.SGX_BUILD1) == '"yes"':
        file.write("[sgx-dealer-in]\n")
        file.write(validate_host_type("SGX_DLRIN"))
        file.write("[sgx-dealer-out]\n")
        file.write(validate_host_type("SGX_DLROUT"))
        file.write("[sgx-kms]\n")
        file.write(validate_host_type("SGX_KMS"))
        file.write("[sgx-router]\n")
        file.write(validate_host_type("SGX_KMS"))
        file.write("[ctf]\n")
        file.write(validate_host_type("CTF"))
        file.write("[cdf]\n")
        file.write(validate_host_type("CTF"))
        file.write("[dns]\n") 
        file.write(validate_host_type("DNS"))
    file.close()


'''

Method to parse the input INI file

'''
def parse_ini_file():
    global config
    config.optionxform = str
    config.read(constants.INPUT_FILE_PATH)
    validate_instance_config(config)
    validate_spgw_instance_config(config)
    return config


if __name__ == '__main__':
    try:
        parse_ini_file()
        print("--------------------------------------------------------")
	gen_host_inv_file(config)
        print("Host inv file generated at .inv")
        print("--------------------------------------------------------")
        sgx_build(config)
        dns_type(config)
    except ValueError as err:
        print(err)
