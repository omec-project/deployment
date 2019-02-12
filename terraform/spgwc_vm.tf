resource "libvirt_volume" "spgwc-qcow2" {
        name = "spgwc.qcow2"
        count = "${var.SPGWC_VM_COUNT}"
        pool = "images"
        source = "${var.DISK_IMAGE_PATH}"
        format = "qcow2"
}
resource "libvirt_volume" "spgwc-data-qcow2" {
  name = "spgwc-data-qcow2"
  count = "${var.SPGWC_VM_COUNT}"
  pool = "images"
  format = "qcow2"
  size = "${var.SPGWC_DISK_SIZE}"
}
resource "libvirt_cloudinit" "spgwcinit" {
    name = "spgwcinit.iso"
    pool = "images"
    count = "${var.SPGWC_VM_COUNT}"
    local_hostname = "spgwc"
    #ssh_authorized_key = "${file("/home/ubuntu/.ssh/id_rsa.pub")}"
    ssh_authorized_key = "${file("${var.SSH_AUTHRIZED_KEY}")}"
}
resource "libvirt_domain" "domain-spgwc" {
    name = "spgwc"
    memory = "${var.SPGWC_MEM}"
    vcpu = "${var.SPGWC_CPU}"
    cputune {
        cpuset = "${var.CORE_RANGE_SPGWC}"
     }
     cpu {
        mode ="host-model"
     }
    count = "${var.SPGWC_VM_COUNT}"
    cloudinit = "${libvirt_cloudinit.spgwcinit.id}"
    network_interface {
        hostname = "spgwc"
                network_name = "default"
                wait_for_lease = true
        }
        network_interface {
                addresses = ["${var.IP_S11_VM_NGIC_CP1_PCI}"]
                passthrough = "${var.DEF_IF_S11_VM_NGIC_CP1_PCI}"
    }
        network_interface {
                addresses = ["${var.IP_ODL_NB_VM_NGIC_CP1_PCI}"]
                passthrough = "${var.DEF_IF_ODL_NB_VM_NGIC_CP1_PCI}"
    }
        network_interface {
                addresses = ["${var.IP_S5S8_SGWC_VM_NGIC_CP1_PCI}"]
                passthrough = "${var.DEF_IF_S5S8_SGWC_VM_NGIC_CP1_PCI}"
    }
    provisioner "local-exec" {
       command = "echo 'sleeping'"
    }
    provisioner "local-exec" {
       command = "sleep 105"
    }
    provisioner "local-exec" {
       command = "echo 'done sleeping'"
    }
    provisioner "file" {
                source = "interfaces-spgwc"
                destination = "/tmp/interfaces"
                connection {
                type = "ssh"
                user = "ubuntu"
                private_key = "${file("${var.PRIVATE_SSH_KEY}")}"
                agent = "false"
                }
    }
    provisioner "remote-exec" {
        inline = [
            "sudo cp /tmp/interfaces /etc/network/interfaces",
            "sudo ifup ens4",
            "sudo ifup ens5",
            "sudo ifup ens6"
        ]
        connection {
            type = "ssh"
            user = "ubuntu"
            private_key = "${file("${var.PRIVATE_SSH_KEY}")}"
            agent = "false"
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
        volume_id = "${libvirt_volume.spgwc-qcow2.id}"
    }
    disk {
        volume_id = "${libvirt_volume.spgwc-data-qcow2.id}"
    }

    graphics {
        type = "spice"
        listen_type = "address"
        autoport = "true"
    }
}

