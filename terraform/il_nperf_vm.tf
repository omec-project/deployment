resource "libvirt_volume" "il_nperf-qcow2" {
    name = "il_nperf.qcow2"
    count = "${var.IL_NPERF_VM_COUNT}"
    pool = "images" #CHANGE_ME
    source = "${var.DISK_IMAGE_PATH}"
    format = "qcow2"
}
# Use CloudInit to add our ssh-key to the instance
resource "libvirt_cloudinit" "il_nperfinit" {
    name = "il_nperfinit.iso"
    pool = "images" #CHANGEME
    count = "${var.IL_NPERF_VM_COUNT}"
    local_hostname = "il_nperf"
    ssh_authorized_key = "${file("${var.SSH_AUTHRIZED_KEY}")}"
}
# Create the machine for il_nperf
resource "libvirt_domain" "domain-il_nperf" {
        name = "il_nperf"
        memory = "${var.IL_NPERF_MEM}"
        vcpu = "${var.IL_NPERF_CPU}"
        cputune {
             cpuset = [ "60","61","62","63","64","65","66","67" ]
        }
        cpu {
           mode ="host-model"
        }

        count = "${var.IL_NPERF_VM_COUNT}"
    cloudinit = "${libvirt_cloudinit.il_nperfinit.id}"
    network_interface {
        hostname = "il_nperf"
                network_name = "default"
        }
        network_interface {
                addresses = ["${var.IP_S1U_IP_ILNPERF_PCI}"]
                passthrough = "${var.DEF_IF_S1U_IP_ILNPERF_PCI}"
    }
        network_interface {
                addresses = ["${var.IP_SGI_IP_ILNPERF_PCI}"]
                passthrough = "${var.DEF_IF_SGI_IP_ILNPERF_PCI}"
    }
    provisioner "file" {
        source = "interfaces-il_nperf"
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
                        "sudo ifup ens5",
                        "sudo ifup ens6"
        ]
        connection {
            type = "ssh"
            user = "ubuntu"
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
        volume_id = "${libvirt_volume.il_nperf-qcow2.id}"
    }
    graphics {
        type = "spice"
        listen_type = "address"
        autoport = "true"
    }
}
