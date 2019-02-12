resource "libvirt_volume" "sgwc-qcow2" {
        name = "sgwc.qcow2"
        count = "${var.SGWC_VM_COUNT}"
        pool = "images"
        source = "${var.DISK_IMAGE_PATH}"
        format = "qcow2"
}
resource "libvirt_volume" "sgwc-data-qcow2" {
  name = "sgwc-data-qcow2"
  count = "${var.SGWC_VM_COUNT}"
  pool = "images"
  format = "qcow2"
  size = "${var.SGWC_DISK_SIZE}"
}
resource "libvirt_cloudinit" "sgwcinit" {
    name = "sgwcinit.iso"
    pool = "images"
    count = "${var.SGWC_VM_COUNT}"
    local_hostname = "sgwc"
    #ssh_authorized_key = "${file("/home/ubuntu/.ssh/id_rsa.pub")}"
    ssh_authorized_key = "${file("${var.SSH_AUTHRIZED_KEY}")}"
}
resource "libvirt_domain" "domain-sgwc" {
    name = "sgwc"
    memory = "${var.SGWC_MEM}"
    vcpu = "${var.SGWC_CPU}"
    cputune {
        cpuset = "${var.CORE_RANGE_SGWC}"
     }
     cpu {
        mode ="host-model"
     }
    count = "${var.SGWC_VM_COUNT}"
    cloudinit = "${libvirt_cloudinit.sgwcinit.id}"
    network_interface {
        hostname = "sgwc"
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
                source = "interfaces-sgwc"
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
        volume_id = "${libvirt_volume.sgwc-qcow2.id}"
    }
    disk {
        volume_id = "${libvirt_volume.sgwc-data-qcow2.id}"
    }

    graphics {
        type = "spice"
        listen_type = "address"
        autoport = "true"
    }
}

