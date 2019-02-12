resource "libvirt_volume" "sgwu-qcow2" {
    name = "sgwu.qcow2"
    count = "${var.SGWU_VM_COUNT}"
    pool = "images"
    source = "${var.DISK_IMAGE_PATH}"
    format = "qcow2"
}
resource "libvirt_volume" "sgwu-data-qcow2" {
    name = "sgwu-data-qcow2"
    count = "${var.SGWU_VM_COUNT}"
    pool = "images"
    format = "qcow2"
    size = "${var.SGWU_DISK_SIZE}"
}
resource "libvirt_cloudinit" "sgwuinit" {
    name = "sgwuinit.iso"
    pool = "images"
    count = "${var.SGWU_VM_COUNT}"
    local_hostname = "sgwu"
    ssh_authorized_key = "${file("${var.SSH_AUTHRIZED_KEY}")}"
}
resource "libvirt_domain" "domain-sgwu" {
    name = "sgwu"
    memory =  "${var.SGWU_MEM}"
    vcpu = "${var.SGWU_CPU}"
    cputune {
        cpuset = "${var.CORE_RANGE_SGWU}"
    }
    cpu {
        mode ="host-model"
    }
    count = "${var.SGWU_VM_COUNT}"
    cloudinit = "${libvirt_cloudinit.sgwuinit.id}"
    network_interface {
        hostname = "sgwu"
        network_name = "default"
        wait_for_lease = true
    }
    network_interface {
        addresses = ["${var.IP_ODL_SB_VM_NGIC_DP1_PCI}"]
        passthrough = "${var.DEF_IF_ODL_SB_VM_NGIC_DP1_PCI}"
    }
    network_interface {
        addresses = ["${var.IP_S5S8_VM_NGIC_DP1_PCI}"]   
        passthrough = "${var.DEF_IF_S5S8_VM_NGIC_DP1_PCI}"
    }
    hostdev {
        passthrough = "${var.DEF_IF_S1U_VM_NGIC_DP1_PCI}"
    }

    provisioner "file" {
        source = "interfaces-sgwu"
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
            "sudo ifup ens4",
            "sudo ifup ens5"
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
        volume_id = "${libvirt_volume.sgwu-qcow2.id}"
    }
    disk {
        volume_id = "${libvirt_volume.sgwu-data-qcow2.id}"
    }

    graphics {
        type = "spice"
        listen_type = "address"
        autoport = "true"
    }
}
