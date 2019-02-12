resource "libvirt_volume" "hss-qcow2" {
        name = "hss.qcow2"
        count = "${var.HSS_VM_COUNT}"
        pool = "images"
        source = "${var.DISK_IMAGE_PATH}"
        format = "qcow2"
}
resource "libvirt_volume" "hss-data-qcow2" {
  name = "hss-data-qcow2"
  count = "${var.HSS_VM_COUNT}"
  pool = "images"
  format = "qcow2"
  size = "${var.HSS_DISK_SIZE}"
}
resource "libvirt_cloudinit" "hssinit" {
    name = "hssinit.iso"
    pool = "images"
    count = "${var.HSS_VM_COUNT}"
    local_hostname = "hss"
    ssh_authorized_key = "${file("${var.SSH_AUTHRIZED_KEY}")}"
}
resource "libvirt_domain" "domain-hss" {
    name = "hss"
    memory = "${var.HSS_MEM}"
    vcpu = "${var.HSS_CPU}"
    cputune {
        cpuset = "${var.CORE_RANGE_HSS}"
     }
     cpu {
        mode ="host-model"
     }

    count = "${var.HSS_VM_COUNT}"
    cloudinit = "${libvirt_cloudinit.hssinit.id}"
    lifecycle {
    	ignore_changes = ["user_data"]
 	 }

    network_interface {
        hostname = "hss"
                network_name = "default"
		wait_for_lease = true
        }
        network_interface {
                addresses = ["${var.IP_HSS_DB_VM_C3PO_HSS1_PCI}"]
                passthrough = "${var.DEF_IF_HSS_DB_VM_C3PO_HSS1_PCI}"
    }
        network_interface {
                addresses = ["${var.IP_HSS_S6_VM_C3PO_HSS1_PCI}"]
                passthrough = "${var.DEF_IF_HSS_S6_VM_C3PO_HSS1_PCI}"
    }
    provisioner "local-exec" {
       command = "echo 'sleeping'"
    }
    provisioner "local-exec" {
       command = "sleep 55"
    }
    provisioner "local-exec" {
       command = "echo 'done sleeping'"
    }
    provisioner "file" {
                source = "interfaces-hss"
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
        volume_id = "${libvirt_volume.hss-qcow2.id}"
    }
    disk {
        volume_id = "${libvirt_volume.hss-data-qcow2.id}"

	}
    graphics {
        type = "spice"
        listen_type = "address"
        autoport = "true"
    }
}
