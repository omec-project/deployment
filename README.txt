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
	5. Download vEPC package
	6. Enter the server and network information in the input configuration file
	7. Execute run.sh script. 
	   This script perform below action on deployment hosts. 
	   7.1 Create virtual functions
	   7.2 Create VM's using Terraform
           7.3 Build and configure each VNF using Ansible. 
	8. Complete manual validation of the deployed virtual environment and network
        9. Run an end-to-end traffic test to validate the functioning of the entire
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
        NETWORK.ONBD = "2x1GbE"                 // Onboard NIC spec.
        NETWORK.FV710 = "4x10GbE = 1x(4x10GbE)"  // Additional NIC controllers

    Host Type 2 houses the NGIC VNFs, a.k.a the "data" frame VNFs. Its minimum
configuration is:

    [HOST_TYPE2]
        CORES_PER_NODE = 26                      // CPU cores per NUMA node
        CORES_TOTAL = 52                         // Total CPU cores 
        MEMORY GB = 128                          // Total RAM
        DISK GB = 500                            // Total HDD size
        NUMA_NODES = 2                           // Minimum # of NUMA nodes
        NETWORK.ONBD = "2x1GbE"                 // Onboard NIC spec.
        NETWORK.FV710 = "8x10GbE = 2x(4x10GbE)" // Additional NIC controllers

    The hardware installation team **MUST** ensure that the hardware installed 
meets the above minimum requirements.

	Pre-requisites - on "all" the physical hosts listed below:
	1. X64(64 bit) server class machine is needed for deployment enabled with VT-D
 technologies in BIOS settings.
 
	2. Latest Ubuntu 16.04 LTS should be installed on the server class machine.
 Latest ubuntu 16.04 LTS image can be downloaded from
	https://www.ubuntu.com/download/alternative-downloads 
	
	3. User account on the server with root privileges.

        4. Ubuntu account must be present on each servers with ssh-keyless connection 
 between remote host to deployment hosts ( control plane and data plane ). 
 Also need ssh-keyless connection between data plane host and SGX system. 

        5. Remote host Dependancy: 
        Installation of Ansible ( Version 2.6 above ) and dependancy. 
		
	For latest version of Ansible: 
        -----------------------------
	Manual : 
	> apt-add-repository ppa:ansible/ansible
	> apt-get update
	> apt-get install ansible
	> apt-get install python2.7 python-pip 
        > pip install ipaddress pyyaml
		
	Automate: 
	> cd /opt/deployment/setupremote
	>./prerequisite.sh
	
	For specific version : 
	----------------------
	pip install ansible==<version_id> 

        6. KVM should be configured and installed on the each target hosts.
 	Manual: 
        Following commands will help install the KVM packages.
				
	6.1 Edit grub file 
	> vim /etc/default/grub
        After:					
         GRUB_CMDLINE_LINUX=""					
        Add:					
          GRUB_CMDLINE_LINUX="intel_iommu=on"					
		
        6.2 reboot server for grub config to take effect		
        > update-grub					
        > reboot 
    
        6.3 To check VT-D is enabled from OS end: 	
	    > dmesg | grep -i dmar					
        E.g.:					
        Note:					
        // Virtualization enaled in BIOS:					
        DMAR: IOMMU enabled					
       // VT-D enables in BIOS					
       DMAR: Intel(R) Virtualization Technology for Directed I/O					

       Automate: 
	   6.4 Install the KVM packages
        >apt-get update
        >apt-get install qemu-kvm libvirt-bin virtinst bridge-utils cpu-checker
        >apt-get install libguestfs-tools virt-manager libvirt-dev
		>adduser root libvirtd

       6.5 To check if kvm is loaded:				
        > lsmod | grep kvm				
       E.g.:				
       root@ilepc1:#  lsmod | grep -i kvm				
       kvm_intel             172032  25				
       kvm                   544768  1 kvm_intel				
       irqbypass              16384  16 kvm,vfio_pci	

	

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

Download the package using following commands:
 >cd /opt/
 >git clone https://github.com/omec-project/deployment.git

 Above command will download package under folder /opt/deployment

 
6. Enter the server and network information in the input configuration file
=============================
Note : Following steps needs to be repeated control and data hosts i.e. 
HOST_TYPE1 and HOST_TYPE2.

 Under the /opt/deployment folder edit the 
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


7. Deployment of VMs using terraform
=============================
 Note : Following steps from remote deployment host.

 >cd /opt/deployment/setupremote
 >./run.sh
  
8. Complete manual validation of the deployed virtual environment and network
=============================
 Note : Following steps needs to be repeated on control and data hosts i.e. 
HOST_TYPE1 and HOST_TYPE2.

 Check created VMs using command:
 >virsh list
 
 
 For ssh to any particular VM, use the following command.
 >./sshvm.sh ubuntu <hostname>
 <hostname> is name of VM displayed in "virsh list" command output.


 To get the IP address of the deployed VM, use following commands.
 >cd /opt/deployment/scripts
 >get_vm_ip.sh shell <hostname printer in virsh list>
 

9. Run an end-to-end traffic test to validate the functioning of the entire
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
 
