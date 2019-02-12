resource "libvirt_volume" "db-qcow2" {
        name = "db.qcow2"
        count = "${var.DB_VM_COUNT}"
        pool = "images"
        source = "${var.DISK_IMAGE_PATH}"
        format = "qcow2"
}
resource "libvirt_volume" "db-data-qcow2" {
  name = "db-data-qcow2"
  count = "${var.DB_VM_COUNT}"
  pool = "images"
  format = "qcow2"
  size = "${var.DB_DISK_SIZE}"
}
resource "libvirt_cloudinit" "dbinit" {
    name = "dbinit.iso"
    count = "${var.DB_VM_COUNT}"
    pool = "images"
    local_hostname = "db"
    ssh_authorized_key = "${file("${var.SSH_AUTHRIZED_KEY}")}"
}
resource "libvirt_domain" "domain-db" {
    name = "db"
    memory = "${var.DB_MEM}"
    vcpu = "${var.DB_CPU}"
    cputune {
        cpuset = "${var.CORE_RANGE_DB}"
     }
     cpu {
        mode ="host-model"
     }
    count = "${var.DB_VM_COUNT}"
    cloudinit = "${libvirt_cloudinit.dbinit.id}"
    network_interface {
        hostname = "db"
                network_name = "default"
		wait_for_lease = true
        }
        network_interface {
                addresses = ["${var.IP_DBN_HSS_VM_C3PO_DBN1_PCI}"]
                passthrough = "${var.DEF_IF_DBN_HSS_VM_C3PO_DBN1_PCI}"
    }
    provisioner "local-exec" {
       command = "echo 'sleeping'"
    }
    provisioner "local-exec" {
       command = "sleep 80"
    }
    provisioner "local-exec" {
       command = "echo 'done sleeping'"
    }
    provisioner "file" {
                source = "interfaces-db"
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
        volume_id = "${libvirt_volume.db-qcow2.id}"
    }
    disk {
        volume_id = "${libvirt_volume.db-data-qcow2.id}"
    }
    graphics {
        type = "spice"
        listen_type = "address"
        autoport = "true"
    }
}
