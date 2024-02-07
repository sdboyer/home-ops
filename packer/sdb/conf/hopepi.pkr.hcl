
variable "hostname" {
  type    = string
}

variable "pi_ip" {
  type    = string
}

variable "pi_mac" {
  type    = string
}

variable "pi_netmask" {
  type    = string
  default = "255.0.0.0"
}

variable "iscsi_target_ip" {
  type    = string
  default = "10.10.1.228"
}

variable "iscsi_target_iqn" {
  type    = string
  default = "iqn.2018-11.io.sdboyer.h:rpi"
}

variable "nfs_bootroot" {
  type    = string
  default = "/mnt/std/pi/boot"
}

variable "nfs_hostname" {
  type    = string
  default = "hoperestored.h.sdboyer.io"
}

variable "nfs_ip" {
  type    = string
  default = "10.10.1.228"
}

variable "gateway" {
  type = string
  default = "10.10.1.1"
}

// variable "net_uuid" {
//   type = string
//   // default = uuidv5("dns", ${var.hostname})
//   default = uuidv4()
// }

source "arm-image" "finalize" {
  # this path enforces execution from repo root
  iso_url = "sdb/output/pibase.img"
  iso_checksum = "none"
  image_type = "raspberrypi"
  output_filename = "finalized/${var.hostname}.img"
}

build {
  sources = ["source.arm-image.finalize"]

  provisioner "file" {
    source = "sdb/tmpl/eth0.nmconnection"
    destination = "/etc/NetworkManager/system-connections/eth0.nmconnection"
  }

  provisioner "file" {
    source = "sdb/tmpl/force-nm.service"
    destination = "/etc/systemd/system/force-nm.service"
  }

  provisioner "file" {
    source = "sdb/tmpl/force-nm.sh"
    destination = "/usr/sbin/force-nm.sh"
  }

  provisioner "shell" {
    inline = [
      "echo 'Setting provisioned file permissions...'",
      "chmod 600 /etc/NetworkManager/system-connections/eth0.nmconnection",
      "chmod +x /usr/sbin/force-nm.sh",
      "systemctl enable force-nm.service",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Setting up network...'",
      // "nmcli c mod eth0 ipv4.addresses ${var.pi_ip} ipv4.method dhcp"
      // "echo '[connection]\nid=eth0\ntype=ethernet\nautoconnect=true\n\n[ipv4]\nmethod=auto\n\n[ethernet]\nmac-address=${var.pi_mac}' > /etc/NetworkManager/system-connections/eth0.nmconnection",
      // "sed -i -r -e \"s@UUID@${var.net_uuid}@\" /etc/NetworkManager/system-connections/eth0.nmconnection",
      "sed -i -r -e \"s@MAC_ADDR@${var.pi_mac}@\" /etc/NetworkManager/system-connections/eth0.nmconnection",
      "sed -i -r -e \"s@IP_ADDR@${var.pi_ip}@\" /etc/NetworkManager/system-connections/eth0.nmconnection",
      "sed -i -r -e \"s@GATEWAY@${var.gateway}@\" /etc/NetworkManager/system-connections/eth0.nmconnection",
      "chmod 600 /etc/NetworkManager/system-connections/eth0.nmconnection",
      "cat /etc/NetworkManager/system-connections/eth0.nmconnection",
      // "apt install -y dhcpcd",
      // "echo interface eth0 > /etc/dhcpcd.conf",
      // "echo static hostname=${var.hostname} >> /etc/dhcpcd.conf",
      // "echo static ip_address=${var.pi_ip} >> /etc/dhcpcd.conf",
      // "echo static routers=${var.gateway} >> /etc/dhcpcd.conf",
      // "echo static domain_name_servers=${var.gateway} >> /etc/dhcpcd.conf",
      // "systemctl enable dhcpcd",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Setting up hostname...'",
      "echo ${var.hostname} > /etc/hostname", 
      "sed -i -r -e 's/(.*)raspberrypi(.*?)$/\\1${var.hostname}\\2 ${var.hostname}.h.sdboyer.io/g' /etc/hosts",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Ensuring unique machine id...'",
      "rm -f /var/lib/dbus/machine-id /etc/machine-id",
      "dbus-uuidgen --ensure",
      "systemd-machine-id-setup",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Setting up /etc/iscsi/initiatorname.iscsi...'",
      "echo InitiatorName=iqn.2021-06.io.sdboyer.h:${var.hostname} > /etc/iscsi/initiatorname.iscsi",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Modifying boot and root files...'",
      "echo 'cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory ip=${var.pi_ip}:::${var.pi_netmask}:${var.hostname}:eth0:static ISCSI_INITIATOR=iqn.2021-06.io.sdboyer.h:${var.hostname} ISCSI_TARGET_NAME=${var.iscsi_target_iqn} ISCSI_TARGET_IP=${var.iscsi_target_ip} rw' >> /boot/cmdline.txt",
      "cat /boot/cmdline.txt | tr -d '\n' > /boot/newcmdline.txt && mv /boot/newcmdline.txt /boot/cmdline.txt",
      "echo '\ninitramfs initrd8.img followkernel' >> /boot/config.txt",
      "echo '\ndtoverlay=rpi-poe' >> /boot/config.txt",
      "echo 'dtparam=poe_fan_temp0=55000,poe_fan_temp0_hyst=5000,poe_fan_temp1=66000,poe_fan_temp1_hyst=5000' >> /boot/config.txt",
      "echo 'dtparam=poe_fan_temp2=71000,poe_fan_temp2_hyst=5000,poe_fan_temp3=73000,poe_fan_temp3_hyst=5000' >> /boot/config.txt",
      "sed -i -r -e \"s@.*/boot/firmware +.*@${var.nfs_ip}:${var.nfs_bootroot}/${var.hostname} /boot nfs defaults,vers=4.1,proto=tcp 0 0@\" /etc/fstab",
      "sed -i -r -e \"s@.*/ +.*@LABEL=${var.hostname}root / ext4 _netdev,noatime,x-systemd.requires=iscsid.service 0 1@\" /etc/fstab",
      "cat /etc/fstab",
      "sed -i -r -e \"s@(.*root=)PARTUUID=[A-Za-z0-9-]+(.*)@\\1LABEL=${var.hostname}root\\2@\" /boot/cmdline.txt",
      "sed -i -r -e \"s@ quiet@@\" /boot/cmdline.txt",
      "sed -i -r -e \"s@ init=/usr/lib/raspi-config/init_resize.sh@@\" /boot/cmdline.txt"
    ]
  }

  // provisioner "shell" {
  //   inline = [
  //     "echo 'Generating initramfs...'",
  //     "update-initramfs -v -k \"$(uname -r)\" -c -b /tmp",
  //     "mv /tmp/$(uname -r).img /boot/initrd8.img",
  //   ]
  // }

  post-processor "manifest" {
    output = "finalized/${var.hostname}-manifest.json"
  }

  post-processor "shell-local" {
    environment_vars = [
      "PI_HOSTNAME=${var.hostname}",
      "NFS_IP=${var.nfs_ip}",
      "NFS_BOOTROOT=${var.nfs_bootroot}",
      "ISCSI_TARGET_IP=${var.iscsi_target_ip}",
      "ISCSI_TARGET_IQN=${var.iscsi_target_iqn}",
      "MANIFEST=finalized/${var.hostname}-manifest.json"
    ]
    script = "/vagrant/provision-network.sh"
  }
}
