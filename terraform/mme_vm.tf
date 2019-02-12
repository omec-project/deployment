resource "libvirt_volume" "mme-qcow2" {
        name = "mme.qcow2"
        count = "${var.MME_VM_COUNT}"
        pool = "images" #CHANGE_ME
        source = "${var.DISK_IMAGE_PATH}"
        format = "qcow2"
}
resource "libvirt_volume" "mme-data-qcow2" {
  name = "mme-data-qcow2"
  count = "${var.MME_VM_COUNT}"
  pool = "images"
  format = "qcow2"
  size = "${var.MME_DISK_SIZE}"
}

resource "libvirt_cloudinit" "mmeinit" {
    name = "mmeinit.iso"
    pool = "images"
    count = "${var.MME_VM_COUNT}"
    local_hostname = "mme"
    ssh_authorized_key = "${file("${var.SSH_AUTHRIZED_KEY}")}"
}
resource "libvirt_domain" "domain-mme" {
    name = "mme"
    memory = "${var.MME_MEM}"
    vcpu = "${var.MME_CPU}"
    cputune {
        cpuset = "${var.CORE_RANGE_MME}"
     }
     cpu {
        mode ="host-model"
     }

    count = "${var.MME_VM_COUNT}"
    cloudinit = "${libvirt_cloudinit.mmeinit.id}"
    network_interface {
        hostname = "mme"
                network_name = "default"
		wait_for_lease = true
        }

        network_interface {
                addresses = ["${var.IP_MME_S6_VM_C3PO_MME1_PCI}"]
                passthrough = "${var.DEF_IF_MME_S6_VM_C3PO_MME1_PCI}"
    }
        network_interface {
                addresses = ["${var.IP_MME_S11_VM_C3PO_MME1_PCI}"]
                passthrough = "${var.DEF_IF_MME_S11_VM_C3PO_MME1_PCI}"
    }
    hostdev {
        passthrough = "${var.DEF_IF_MME_S1MME_VM_C3PO_MME1_PCI}"
        }
    provisioner "local-exec" {
       command = "echo 'sleeping'"
    }
    provisioner "local-exec" {
       command = "sleep 30"
    }
    provisioner "local-exec" {
       command = "echo 'done sleeping'"
    }
    provisioner "file" {
                source = "interfaces-mme"
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
            #"sudo ifup ens9"

        ]
        connection {
            type = "ssh"
            user = "ubuntu"
	    agent = "false"
            private_key = "${file("${var.PRIVATE_SSH_KEY}")}"
        }
    }
        # IMPORTANT
    # Ubuntu can hang is a isa-serial is not present at boot time.
    # If you find your CPU 100% and never is available this is why
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
        volume_id = "${libvirt_volume.mme-qcow2.id}"
    }
    disk {
        volume_id = "${libvirt_volume.mme-data-qcow2.id}"
    }

    graphics {
        type = "spice"
        listen_type = "address"
        autoport = "true"
    }
}
