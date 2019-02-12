Introduction:
=============
    This README describes the process you need to follow and the actions you 
need to take in order to deploy a vEPC comprising both the C3PO and NGIC 
components.
    C3PO comprises the following functional VNFs:
        MME
        HSS
        DB (Cassandra Database)
        SGW-C
        PGW-C
        FPC (includes ODL)
     NGIC comprises the following functional VNFs:
        SGW-U
        PGW-U
     Together, C3PO and NGIC constitute a fully functional vEPC, but without 
the billing and charging functions.

Process and the Information that is required:
=============================================

    An outline of the process to be followed is given below, in sequence:

        1. Ready the physical hardware
        2. Connect the physical network
        3. Gather Inventory Information related to the physical hardware and 
            physical network
        4. Plan the IP network - IP addresses, subnets
		5. Download vEPC package and run prerequisite for installation
		6. Enter the server and network information in the input configuration file
		7. Create virtual functions
			7.1 Install control plane virtual functions
			7.2 Install data plane virtual functions
		8. Deployment of VMs using terraform
		9. Complete manual validation of the deployed virtual environment and network
		10. Manually install the software required for each VNF
		11. Run an end-to-end traffic test to validate the functioning of the entire
            vEPC

1. Ready the physical hardware
=========================
    Two types of hosts are required to deploy the vEPC. 
	Host Type 1, whose configuration is given below, houses the C3PO VNFs, a.k.a the 
"control" frame VNFs. The minimum required configuration for Host Type 1 is:

    [HOST_TYPE1]
        CORES_PER_NODE = 26                      // CPU cores per NUMA node
        CORES_TOTAL = 52                         // Total CPU cores 
        MEMORY GB = 128                          // Total RAM
        DISK GB = 500                            // Total HDD size
        NUMA_NODES= 2                            // Minimum # of NUMA nodes
        NETWORK.ONBD = "2x10GbE"                 // Onboard NIC spec.
        NETWORK.FV710 = "8x10GbE = 2x(4x10GbE)"  // Additional NIC controllers

    Host Type 2 houses the NGIC VNFs, a.k.a the "data" frame VNFs. Its minimum
configuration is:

    [HOST_TYPE2]
        CORES_PER_NODE = 26                      // CPU cores per NUMA node
        CORES_TOTAL = 52                         // Total CPU cores 
        MEMORY GB = 128                          // Total RAM
        DISK GB = 500                            // Total HDD size
        NUMA_NODES = 2                           // Minimum # of NUMA nodes
        NETWORK.ONBD = "2x10GbE"                 // Onboard NIC spec.
        NETWORK.FV710 = "20x10GbE = 5x(4x10GbE)" // Additional NIC controllers
		[Review]: Why 20 NIC ports for data frame? Is this minimum required?

    The hardware installation team **MUST** ensure that the hardware installed 
meets the above minimum requirements.

	Pre-requisites - on "all" the physical hosts listed below:
	1. X64(64 bit) server class machine is needed for deployment enabled with VT-D
 technologies in BIOS settings.
 
	2. Latest Ubuntu 16.04 LTS should be installed on the server class machine.
 Latest ubuntu 16.04 LTS image can be downloaded from
	https://www.ubuntu.com/download/alternative-downloads 
	
	3. User account on the server with root privileges.
	
	4 KVM should be configured and installed on the server class machine.
	Following commands will help install the KVM packages.
	>apt-get update
	>apt-get install qemu-kvm libvirt-bin virtinst bridge-utils cpu-checker 
	>apt-get install libguestfs-tools virt-manager libvirt-dev
	
	5 Add system user to the libvirtd group
	>adduser <user> libvirtd
	
	

2. Connect the physical network
=============================
#-------------------------------------------------------------------------------
;
;                                     +--------------+
;      Control+----------------> S1MME|              |
;       Path                          |     MME      |
;                             +-------+              |        
;                             |       |              |       
;                             |       +--------------+      
;                             |                S6|         
; +----------+                |       +--------------+           +----------+
; |          |                |       |              |           |          |
; | Traffic  |                |       |    HSS       |           | Traffic  |
; | Generator|                |       |              |           | Receiver |
; |          |                |       +--------------+           |          |
; |          |                |                DB|               |          |
; +-+---+----+                |       +--------------+           +---+--+---+
;   ^   |                     |       |    DB        |               |  |    
;   |   | Data Path           |       |              |               |  |
;   |   |                     |       +--------------+               |  |
;   |   |                     |                                      |  |
;   |   |                S11  v                                      |  |
;   |   |             +------+-----+                +-----------+    |  |
;   |   |             |            |     S5S8_C     |           |    |  |
;   |   |             |   SGWC     +--------------->|   PGWC    |    |  |
;   |   |             |            +----|FPC_NB|----+           |    |  |
;   |   |             +------------+  +-v------v-+  +-----------+    |  |
;   |   |                              |   FPC    |                  |  |
;   |   |                              |          |                  |  |
;   |   |             +------------+  +-+------+-+  +-----------+    |  |
;   |   |       S1U   |            |    ^FPC_SB^    |           |+---   |
;   |   +------------>|   SGWU     +----+      +----+   PGWU    +<-----+
;   +-----------------+            +--------------->+           | SGI
;                     +------------+     S5S8_U     +-----------+
;
**TO DO
In the above network diagram, identify which are the physical connections
** END TO DO**

3. Gather Inventory Information related to the physical hardware and physical 
network
=============================

4. Plan the IP network - IP addresses, subnets
=============================

5. Download vEPC package and run prerequisite for installation
=============================
Note : Following steps needs to be repeated control and data hosts i.e. 
HOST_TYPE1 and HOST_TYPE2.

Make sure network access to "ilpm.intel-research.net" server is available.
Make sure user account for package repository is created.
Download the package using following commands:
 >cd /opt/
 >git clone https://<username>@ilpm.intel-research.net/bitbucket/scm/vccbbw/terraform_ngic_deployment.git

 Above command will download package under folder /opt/terraform_ngic_deployment

Go to folder /opt/terraform_ngic_deployment, and run pre-requisites checking script.
 >cd /opt/terraform_ngic_deployment
 >./prerequisite.sh
 
 Above script will check and install all the packages required to run terraform.
 
6. Enter the server and network information in the input configuration file
=============================
Note : Following steps needs to be repeated control and data hosts i.e. 
HOST_TYPE1 and HOST_TYPE2.

 Under the /opt/terraform_ngic_deployment/terraform folder edit the 
"c3po_ngic_input.cfg", and fill in the sections mentioned below with the 
appropriate configuration values.
 Sample configurations values are already defined in the "c3po_ngic_input.cfg".
 Please edit the relevant sections and fill them with the values that are as 
per your network and system configurations.

 On control plane host(HOST_TYPE1) edit following sections:-
 Sections to edit:
 [HOST_TYPE1] 
 [HOST_TYPE2]
 [HOST]
 [NETWORKS]
 [MME]
 [HSS]
 [DB]
 [DNS]
 [SGWC]
 [PGWC]
 [FPC]
 
 On data plane host(HOST_TYPE2) edit following sections:-
 [SGWU]
 [PGWU]
 [CTF]

7. Create virtual functions
=============================
 7.1 Install control plane virtual functions
 
 Go to control plane host(HOST_TYPE1).
 
 NOTE: The installer expects at least two 10GB NICs to be up
 (link established/detected/up) for control plane.
 Installer will fail to create the virtual functions if two 10GB NICs are not
 found.
 To install control plane functions(e.g. HOST_TYPE1 above) execute following
 script with argument "cp".
 
 Note: Below command will print the details and ask for confirmation.
 
 >cd /opt/terraform_ngic_deployment/terraform
 >./generate_device.sh cp

 Virtual functions for the following would be installed for the control-plane.  
 HSS
 DB
 MME
 SGWC
 PGWC
 FPC
 
 Validate the virtual functions created using command(TBD)
 >./listvfs_by_pf.sh
 
 7.2 Install data plane virtual functions
 
 Go to data plane host(HOST_TYPE2).
 
 For data plane functions, installer expects at least three 10GB NIC's.
 To install data plane functions(e.g. HOST_TYPE2 above) execute following
 script with argument "dp".

 Note: Below command will print the details and ask for confirmation.

 >cd /opt/terraform_ngic_deployment/terraform
 >./generate_device.sh dp 
 
 Virtual functions for the following would be installed for data-plane.
 SGWU
 PGWU

8. Deployment of VMs using terraform
=============================
 Note : Following steps needs to be repeated on control and data hosts i.e. 
HOST_TYPE1 and HOST_TYPE2.

 >cd /opt/terraform_ngic_deployment/terraform
 >terraform init
 >./deploy.sh
  
9. Complete manual validation of the deployed virtual environment and network
=============================
 Note : Following steps needs to be repeated on control and data hosts i.e. 
HOST_TYPE1 and HOST_TYPE2.

 Check created VMs using command:
 >virsh list
 
 To test network connectivity among installed VMs, use the following command
 For data plane host(HOST_TYPE2), script will validate the presence of 2 
 virtual NIC's enabled with DPDK driver for SGWU and PGWU.
 >cd /opt/terraform_ngic_deployment
 >python check_connectivity.py
 
 For ssh to any particular VM, use the following command.
 >./sshbm ubuntu <hostname>
 <hostname> is name of VM displayed in "virsh list" command output.


 To get the IP address of the deployed VM, use following commands.
 >cd /opt/terraform_ngic_deployment/terraform
 >get_vm_ip.sh shell <hostname printer in virsh list>
 
10. Manually install the software required for each VNF
=============================
[review] - This step should be obsolete after packaging.

11. Run an end-to-end traffic test to validate the functioning of the entire
vEPC
=============================
 
 Note: Directory and file naming convention is to be changed. Directory cleanup is to be done.
 
 
 #########################################
 input.cfg file takes following params :
 #########################################
 
 
 Section (M) : instance type [ SGWC | PGWC | SGWU | SGWU | FPC | MME | HSS | DB | DNS | CTF  | IL_NPERF ] and network [ NETWORKS ]

 Each Section (except NETWORKS section ) will have following parameters :
 CPU (O) : vcpu count
 INSTANCE_COUNT (M) : instance/vm count
 HOST_TYPE (M) : target host type [ 1 | 2 | 3 ]
 MEMORY (O) : memory in GB
 NETWROK.X (M) : Networks 
     SGWC : FPCNB_IP,S11_IP,S5S8C_IP
     PGWC : FPCNB_IP,S5S8C_IP
     SGWU : FPCSB_IP,S1U_IP,S5S8U_IP
     PGWU : FPCSB_IP,SGI_IP,S5S8U_IP
     FPC  : FPCNB_IP,FPCSB_IP
     MME  : S11_IP,S1MME_IP,S6A_IP 
     HSS  : DB_IP,S6A_IP 
     DB   : DB_IP 

 Section NETWORKS will have following parameters : 
 
 MGMT (O) : mgmt network address space
 FPCNB (M): fpc nb network address space
 FPCSB (O): fpc sb network address space
 S5S8C (O): s5s8 control plane network address space
 S5S8U (O): s5s8 user plane network address space
 S1U (O)  : s1u network address space
 SGI (O)  : sgi  network address space
 S11 (O)  : network address space
 S1MME (O): s1mme network address space 
 S6A (O)  : s6a network address space
 DB (O)   : db network address space


  O - Optional , M - Mandatory
 
