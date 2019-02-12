resource "libvirt_volume" "fpc-qcow2" {
    name = "fpc.qcow2"
    count = "${var.FPC_VM_COUNT}"
    pool = "images"
    source = "${var.DISK_IMAGE_PATH}"
    format = "qcow2"
}
resource "libvirt_volume" "fpc-data-qcow2" {
  name = "fpc-data-qcow2"
  count = "${var.FPC_VM_COUNT}"
  pool = "images"
  format = "qcow2"
  size = "${var.FPC_DISK_SIZE}"
}

resource "libvirt_cloudinit" "fpcinit" {
    name = "fpcinit.iso"
    pool = "images"
    count = "${var.FPC_VM_COUNT}"
    local_hostname = "fpc"
    ssh_authorized_key = "${file("${var.SSH_AUTHRIZED_KEY}")}"
}
resource "libvirt_domain" "domain-fpc" {
        name = "fpc"
        memory = "${var.FPC_MEM}"
    	vcpu = "${var.FPC_CPU}"
        cputune {
             cpuset =  "${var.CORE_RANGE_FPC}"
        }
        cpu {
           mode ="host-model"
        }
	count = "${var.FPC_VM_COUNT}"
    cloudinit = "${libvirt_cloudinit.fpcinit.id}"
    network_interface {
        hostname = "fpc"
                network_name = "default"
		wait_for_lease = true
        }
        network_interface {
                addresses = ["${var.IP_ODL_NB_VM_FPC_ODL1_PCI}"]
                passthrough = "${var.DEF_IF_ODL_NB_VM_FPC_ODL1_PCI}"
    }
        network_interface {
                addresses = ["${var.IP_ODL_SB_VM_FPC_ODL1_PCI}"]
                passthrough = "${var.DEF_IF_ODL_SB_VM_FPC_ODL1_PCI}"
    }
    provisioner "local-exec" {
       command = "echo 'sleeping'"
    }
    provisioner "local-exec" {
       command = "sleep 155"
    }
    provisioner "local-exec" {
       command = "echo 'done sleeping'"
    }
    provisioner "file" {
        source = "interfaces-fpc"
        destination = "/tmp/interfaces"
        connection {
                type = "ssh"
                user = "ubuntu"
		agent = "false"
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
            agent = "false"
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
        volume_id = "${libvirt_volume.fpc-qcow2.id}"
    }
    disk {
        volume_id = "${libvirt_volume.fpc-data-qcow2.id}"
    }

    graphics {
        type = "spice"
        listen_type = "address"
        autoport = "true"
    }
}
