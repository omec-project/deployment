variable "DISK_IMAGE_PATH" {
     default = "/opt/ubuntu-16.04-server-cloudimg-amd64-disk1.img"
}
variable "PRIVATE_SSH_KEY" {
	default = "/home/ubuntu/.ssh/id_rsa"
}
variable "SSH_AUTHRIZED_KEY" {
	default = "/home/ubuntu/.ssh/id_rsa.pub"
}

# Define network device name
variable "DEF_IF_S11_MACVTAP_CP1" {
	default = ""
}
variable "DEF_IF_S11_VM_NGIC_CP1_PCI" {
        default = ""
}

variable "DEF_IF_S5S8_SGWC_VM_NGIC_CP1_PCI" {
	default = ""
}
variable "DEF_IF_S5S8_PGWC_VM_NGIC_CP2_PCI" {
	default = ""
}
variable "DEF_IF_ODL_NB_VM_NGIC_CP1_PCI" {
	default = ""
}
variable "DEF_IF_ODL_NB_VM_NGIC_CP2_PCI" {
	default = ""
}
variable "DEF_IF_ODL_NB_VM_FPC_ODL1_PCI" {
	default = ""
}
variable "DEF_IF_ODL_SB_VM_FPC_ODL1_PCI" {
	default = ""
}
variable "DEF_IF_ODL_SB_VM_NGIC_DP1_PCI" {
	default = ""
}
variable "DEF_IF_ODL_SB_VM_NGIC_DP2_PCI" {
	default = ""
}
variable "DEF_IF_S1U_VM_NGIC_DP1_PCI" {
	default = ""
}
variable "DEF_IF_S5S8_VM_NGIC_DP1_PCI" {
	default = ""
}
variable "DEF_IF_S5S8_VM_NGIC_DP2_PCI" {
	default = ""
}
variable "DEF_IF_SGI_VM_NGIC_DP2_PCI" {
	default = ""
}
variable "DEF_IF_MME_S11_VM_C3PO_MME1_PCI" {
        default = ""
}
variable "DEF_IF_MME_S6_VM_C3PO_MME1_PCI" {
        default = ""
}
variable "DEF_IF_MME_S1MME_VM_C3PO_MME1_PCI" {
        default = ""
}
variable "DEF_IF_HSS_S6_VM_C3PO_HSS1_PCI" {
        default = ""
}
variable "DEF_IF_HSS_DB_VM_C3PO_HSS1_PCI" {
        default = ""
}
variable "DEF_IF_DBN_HSS_VM_C3PO_DBN1_PCI" {
        default = ""
}
variable "DEF_IF_DNS_DDNS_VM_C3PO_DNS1_PCI" {
        default = ""
}
variable "DEF_IF_CTF_RF_VM_C3PO_CTF1_PCI" {
        default = ""
}
variable "DEF_IF_CDF_RF_VM_C3PO_CDF1_PCI" {
        default = ""
}
variable "DEF_IF_S1U_IP_ILNPERF_PCI" {
        default = ""
}
variable "DEF_IF_SGI_IP_ILNPERF_PCI" {
        default = ""
}

# Define the IP address variable

variable "IP_S11_MACVTAP_CP1" {
	default = ""
}

variable "IP_S11_VM_NGIC_CP1_PCI" {
	default = ""
}
variable "IP_ODL_NB_VM_NGIC_CP1_PCI" {
	default = ""
}
variable "IP_ODL_SB_VM_FPC_ODL1_PCI" {
  default = ""
}
variable "IP_ODL_NB_VM_FPC_ODL1_PCI" {
  default = ""
}
variable "IP_S5S8_VM_NGIC_DP1_PCI" {
  default = ""
}
variable "IP_ODL_SB_VM_NGIC_DP1_PCI" {
  default = ""
}
variable "IP_S1U_VM_NGIC_DP1_PCI" {
  default = ""
}
variable "IP_ODL_NB_VM_NGIC_CP2_PCI" {
  default = ""
}
variable "IP_S5S8_PGWC_VM_NGIC_CP2_PCI" {
  default = ""
}
variable "IP_SGI_VM_NGIC_DP2_PCI" {
  default = ""
}
variable "IP_S5S8_VM_NGIC_DP2_PCI" {
  default = ""
}
variable "IP_ODL_SB_VM_NGIC_DP2_PCI" {
  default = ""
}
variable "IP_S5S8_SGWC_VM_NGIC_CP1_PCI" {
  default = ""
}
variable "IP_MME_S11_VM_C3PO_MME1_PCI"{
	default = ""
}
variable "IP_MME_S1MME_VM_C3PO_MME1_PCI"{
	default = ""
}
variable "IP_MME_S6_VM_C3PO_MME1_PCI"{
	default = ""
}
variable "IP_HSS_S6_VM_C3PO_HSS1_PCI"{
        default = ""
}
variable "IP_HSS_DB_VM_C3PO_HSS1_PCI"{
        default = ""
}
variable "IP_DBN_HSS_VM_C3PO_DBN1_PCI"{
        default = ""
}
variable "IP_DNS_DDNS_VM_C3PO_DNS1_PCI"{
        default = ""
}
variable "IP_CTF_RF_VM_C3PO_CTF1_PCI"{
        default = ""
}
variable "IP_CDF_RF_VM_C3PO_CDF1_PCI"{
        default = ""
}
variable "IP_S1U_IP_ILNPERF_PCI"{
        default = ""
}
variable "IP_SGI_IP_ILNPERF_PCI"{
        default = ""
}

# Define the variable for vm counts
variable "PGWU_VM_COUNT" {
  default = "0"
}

variable "FPC_VM_COUNT" {
	default = "0"
}
variable "SGWC_VM_COUNT" {
	default = "0"
}
variable "PGWC_VM_COUNT" {
	default = "0"
}
variable "SPGWC_VM_COUNT" {
        default = "0"
}
variable "SPGWU_VM_COUNT" {
        default = "0"
}

variable "SGWU_VM_COUNT" {
	default = "0"
}
variable "MME_VM_COUNT" {
        default = "0"
}
variable "HSS_VM_COUNT" {
        default = "0"
}
variable "DB_VM_COUNT" {
        default = "0"
}
variable "IL_NPERF_VM_COUNT" {
        default = "0"
}

# Define variable for CPU count
variable "FPC_CPU" {
	default = ""
}
variable "SGWC_CPU" {
	default = ""
}
variable "PGWC_CPU" {
	default = ""
}
variable "SPGWC_CPU" {
        default = ""
}
variable "SGWU_CPU" {
	default = ""
}
variable "PGWU_CPU" {
	default = ""
}
variable "SPGWU_CPU" {
        default = ""
}
variable "MME_CPU" {
    default = ""
}
variable "HSS_CPU" {
    default = ""
}
variable "DB_CPU" {
    default = ""
}
variable "IL_NPERF_CPU" {
    default = ""
}

# Define the variable for core range
variable "CORE_RANGE_FPC" {
    type = "list"
    default = []
}
variable "CORE_RANGE_MME" {
    type = "list"
    default = []
}
variable "CORE_RANGE_HSS" {
    type = "list"
    default = []
}
variable "CORE_RANGE_DB" {
    type = "list"
    default = []
}
variable "CORE_RANGE_SGWC" {
    type = "list"
    default = []
}
variable "CORE_RANGE_PGWC" {
    type = "list"
    default = []
}
variable "CORE_RANGE_SPGWC" {
    type = "list"
    default = []
}
variable "CORE_RANGE_SGWU" {
    type = "list"
    default = []
}
variable "CORE_RANGE_PGWU" {
    type = "list"
    default = []
}
variable "CORE_RANGE_SPGWU" {
    type = "list"
    default = []
}

#Define variable for memory
variable "FPC_MEM" {
	default = ""
}
variable "SGWC_MEM" {
	default = ""
}
variable "PGWC_MEM" {
	default = ""
}
variable "SPGWC_MEM" {
        default = ""
}

variable "SGWU_MEM" {
	default = ""
}
variable "PGWU_MEM" {
	default = ""
}
variable "SPGWU_MEM" {
        default = ""
}

variable "MME_MEM" {
    default = ""
}
variable "HSS_MEM" {
    default = ""
}
variable "DB_MEM" {
    default = ""
}
variable "IL_NPERF_MEM" {
    default = ""
}

# Terraform variable for disk size

variable "MME_DISK_SIZE" {
    default = ""
}
variable "HSS_DISK_SIZE" {
    default = ""
}
variable "DB_DISK_SIZE" {
    default = ""
}
variable "FPC_DISK_SIZE" {
    default = ""
}
variable "SGWC_DISK_SIZE" {
    default = ""
}
variable "PGWC_DISK_SIZE" {
    default = ""
}
variable "SPGWC_DISK_SIZE" {
    default = ""
}

variable "SGWU_DISK_SIZE" {
    default = ""
}
variable "PGWU_DISK_SIZE" {
    default = ""
}
variable "SPGWU_DISK_SIZE" {
    default = ""
}

variable "CTF_DISK_SIZE" {
    default = ""
}
variable "CDF_DISK_SIZE" {
    default = ""
}
variable "DNS_DISK_SIZE" {
    default = ""
}
