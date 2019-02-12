resource "libvirt_volume" "pgwc-qcow2" {
    name = "pgwc.qcow2"
    count = "${var.PGWC_VM_COUNT}"
    pool = "images"
    source = "${var.DISK_IMAGE_PATH}"
    format = "qcow2"
}
resource "libvirt_volume" "pgwc-data-qcow2" {
  name = "pgwc-data-qcow2"
  count = "${var.PGWC_VM_COUNT}"
  pool = "images"
  format = "qcow2"
  size = "${var.PGWC_DISK_SIZE}"
}

resource "libvirt_cloudinit" "pgwcinit" {
    name = "pgwcinit.iso"
    pool = "images"
    count = "${var.PGWC_VM_COUNT}"
    local_hostname = "pgwc"
    ssh_authorized_key = "${file("${var.SSH_AUTHRIZED_KEY}")}"
}
resource "libvirt_domain" "domain-pgwc" {
        name = "pgwc"
        memory = "${var.PGWC_MEM}"
    vcpu = "${var.PGWC_CPU}"
    cputune {
             cpuset = "${var.CORE_RANGE_PGWC}"
        }
        cpu {
           mode ="host-model"
        }
        count = "${var.PGWC_VM_COUNT}"
    cloudinit = "${libvirt_cloudinit.pgwcinit.id}"
    network_interface {
        hostname = "pgwc"
        network_name = "default"
		wait_for_lease = true
        }
        network_interface {
                addresses = ["${var.IP_S5S8_PGWC_VM_NGIC_CP2_PCI}"]
                passthrough = "${var.DEF_IF_S5S8_PGWC_VM_NGIC_CP2_PCI}"
    }
        network_interface {
                addresses = ["${var.IP_ODL_NB_VM_NGIC_CP2_PCI}"]
                passthrough = "${var.DEF_IF_ODL_NB_VM_NGIC_CP2_PCI}"
    }
    provisioner "local-exec" {
       command = "echo 'sleeping'"
    }
    provisioner "local-exec" {
       command = "sleep 140"
    }
    provisioner "local-exec" {
       command = "echo 'done sleeping'"
    }
    provisioner "file" {
        source = "interfaces-pgwc"
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
                        "sudo ifup ens5"
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
        volume_id = "${libvirt_volume.pgwc-qcow2.id}"
    }
    disk {
        volume_id = "${libvirt_volume.pgwc-data-qcow2.id}"
    }

    graphics {
        type = "spice"
        listen_type = "address"
        autoport = "true"
    }
}
