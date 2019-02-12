resource "libvirt_volume" "spgwu-qcow2" {
    name = "spgwu.qcow2"
    count = "${var.SPGWU_VM_COUNT}"
    pool = "images"
    source = "${var.DISK_IMAGE_PATH}"
    format = "qcow2"
}
resource "libvirt_volume" "spgwu-data-qcow2" {
  name = "spgwu-data-qcow2"
  count = "${var.SPGWU_VM_COUNT}"
  pool = "images"
  format = "qcow2"
  size = "${var.SPGWU_DISK_SIZE}"
}

resource "libvirt_cloudinit" "spgwuinit" {
    name = "spgwuinit.iso"
    pool = "images"
    count = "${var.SPGWU_VM_COUNT}"
    local_hostname = "spgwu"
    ssh_authorized_key = "${file("${var.SSH_AUTHRIZED_KEY}")}"
}
resource "libvirt_domain" "domain-spgwu" {
        name = "spgwu"
        memory =  "${var.SPGWU_MEM}"
        vcpu = "${var.SPGWU_CPU}"
        cputune {
              cpuset = "${var.CORE_RANGE_SPGWU}"
        }
        cpu {
           mode ="host-model"
        }
        count = "${var.SPGWU_VM_COUNT}"
    cloudinit = "${libvirt_cloudinit.spgwuinit.id}"
    network_interface {
        hostname = "spgwu"
                network_name = "default"
                wait_for_lease = true
       }
        network_interface {
                addresses = ["${var.IP_ODL_SB_VM_NGIC_DP1_PCI}"]
                passthrough = "${var.DEF_IF_ODL_SB_VM_NGIC_DP1_PCI}"
        }

      hostdev {
        passthrough = "${var.DEF_IF_S1U_VM_NGIC_DP1_PCI}"
        }
      hostdev {
        passthrough = "${var.DEF_IF_SGI_VM_NGIC_DP2_PCI}"
        }


        provisioner "file" {
        source = "interfaces-spgwu"
        destination = "/tmp/interfaces"
        connection {
                type = "ssh"
                user = "ubuntu"
                private_key = "${file("${var.PRIVATE_SSH_KEY}")}"
        }
        }
    provisioner "remote-exec" {
        inline = [
                        "sudo cp /tmp/interfaces /etc/network/interfaces",
                        "sudo ifup ens4"

        ]
        connection {
            type = "ssh"
            user = "ubuntu"
            private_key = "${file("${var.PRIVATE_SSH_KEY}")}"
        }
    }
    console {
        type = "pty"
        target_port = "0"
        target_type = "serial"
    }
    console {
        type = "pty"
        target_type = "virtio"
        target_port = "1"
    }
    disk {
        volume_id = "${libvirt_volume.spgwu-qcow2.id}"
    }
    disk {
        volume_id = "${libvirt_volume.spgwu-data-qcow2.id}"
    }

    graphics {
        type = "spice"
        listen_type = "address"
        autoport = "true"
    }
}
