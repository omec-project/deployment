resource "libvirt_volume" "pgwu-qcow2" {
    name = "pgwu.qcow2"
    count = "${var.PGWU_VM_COUNT}"
    pool = "images"
    source = "${var.DISK_IMAGE_PATH}"
    format = "qcow2"
}
resource "libvirt_volume" "pgwu-data-qcow2" {
    name = "pgwu-data-qcow2"
    count = "${var.PGWU_VM_COUNT}"
    pool = "images"
    format = "qcow2"
    size = "${var.PGWU_DISK_SIZE}"
}
resource "libvirt_cloudinit" "pgwuinit" {
    name = "pgwuinit.iso"
    pool = "images"
    count = "${var.PGWU_VM_COUNT}"
    local_hostname = "pgwu"
    ssh_authorized_key = "${file("${var.SSH_AUTHRIZED_KEY}")}"
}
resource "libvirt_domain" "domain-pgwu" {
    name = "pgwu"
    memory = "${var.PGWU_MEM}"
    vcpu = "${var.PGWU_CPU}"
    cputune {
        cpuset = "${var.CORE_RANGE_PGWU}"
    }
    cpu {
        mode ="host-model"
    }

    count = "${var.PGWU_VM_COUNT}"
    cloudinit = "${libvirt_cloudinit.pgwuinit.id}"
    network_interface {
        hostname = "pgwu"
        network_name = "default"
        wait_for_lease = true
    }
    network_interface {
        addresses = ["${var.IP_ODL_SB_VM_NGIC_DP2_PCI}"]
        passthrough = "${var.DEF_IF_ODL_SB_VM_NGIC_DP2_PCI}"
    }
    network_interface {
        addresses = ["${var.IP_S5S8_VM_NGIC_DP2_PCI}"]
        passthrough = "${var.DEF_IF_S5S8_VM_NGIC_DP2_PCI}"
    }
    hostdev {
        passthrough = "${var.DEF_IF_SGI_VM_NGIC_DP2_PCI}"
    }
    provisioner "local-exec" {
        command = "echo 'sleeping'"
    }
    provisioner "local-exec" {
        command = "sleep 60"
    }
    provisioner "local-exec" {
        command = "echo 'done sleeping'"
    }

    provisioner "file" {
        source = "interfaces-pgwu"
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
        volume_id = "${libvirt_volume.pgwu-qcow2.id}"
    }
    disk {
        volume_id = "${libvirt_volume.pgwu-data-qcow2.id}"
    }

    graphics {
        type = "spice"
        listen_type = "address"
        autoport = "true"
    }
}
