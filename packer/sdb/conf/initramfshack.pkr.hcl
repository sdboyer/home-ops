source "arm-image" "base" {
  image_type   = "raspberrypi"
  iso_checksum = "9ce5e2c8c6c7637cd2227fdaaf0e34633e6ebedf05f1c88e00f833cbb644db4b"
  iso_url      = "https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-12-11/2023-12-11-raspios-bookworm-arm64-lite.img.xz"
  output_filename = "sdb/output/compile.img"
  // Buster seems to have iscsi available in initrd in a way that bookworm does not
  // iso_checksum = "868cca691a75e4280c878eb6944d95e9789fa5f4bbce2c84060d4c39d057a042"
  // iso_url      = "http://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2021-05-28/2021-05-07-raspios-buster-arm64-lite.zip"
  // Need increased target image size due to number of updates for buster, or packer will run out of space
  // target_image_size = 2147483648
}

variable "root_pub_key" {
  type    = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA01xxdHeWb2eEXWjhSn7cTW5auWFt/UQP0/7nB+OSUundzZSc8edwipS18QsxJoaB+bmCFEBebwCpIrQ6fgypL3vonZVnWWouKtuS9sBDqLWi1m3CvlWtv31ZgamLiKpMbyhdAe3YhyijwKFTRznqvZzh30x7wAagCbmsjgIxeSM0w//Wk1RIUgh/wTeLi9KShm8PhOd0ZjJpxQ8UwBd4i3FfVWJzySvCOsPxAUG6lUGWz2vJ/doDmq0rV/T9pBvFhgLEmvO1tmXFAakQBXGZIMozuOfPZR5HbN/LoHLQFVEwb2IBk7M31AeOs95WDoXSBMm2d4HnusbHmX/W71B8Lw== /Users/sdboyer/.ssh/id_rsa"
}

build {
  sources = ["source.arm-image.base"]

  provisioner "shell" {
    environment_vars = [
      "LANGUAGE=en_US.UTF-8",
      "LANG=en_US.UTF-8",
      "LC_ALL=en_US.UTF-8",
      "LC_CTYPE=en_US.UTF-8",
      "DEBIAN_FRONTEND=noninteractive",
      "DEBCONF_NONINTERACTIVE_SEEN=true"
    ]
    inline = [
      "echo 'Reconfiguring locales...'",
      "echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen",
      "locale-gen",
      "update-locale LANG=en_US.UTF-8",
      "cat /etc/default/locale",
      "locale",
      "dpkg-reconfigure -f noninteractive locales"
    ]
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "DEBCONF_NONINTERACTIVE_SEEN=true"
    ]
    inline = [
      "echo 'tzdata tzdata/Areas select US' | debconf-set-selections",
      "echo 'tzdata tzdata/Zones/US select Eastern' | debconf-set-selections",
      "rm /etc/timezone",
      "rm /etc/localtime",
      "dpkg-reconfigure -f noninteractive tzdata"
    ]
  }

  // provisioner "shell" {
  //   inline = [
  //     "echo 'Updating apt...'",
  //     "apt update",
  //     "apt full-upgrade -y"
  //   ]
  // }

  provisioner "shell" {
    inline = [
      "echo 'Disabling wifi...'",
      "echo 'dtoverlay=disable-wifi' >> /boot/config.txt",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Disabling bluetooth...'",
      "echo 'dtoverlay=disable-bt' >> /boot/config.txt",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Setting up sshd...'",
      "touch /boot/ssh",
      "sed -i -r -e 's/#?.*?PermitRootLogin.*?$/PermitRootLogin without-password/g' /etc/ssh/sshd_config",
      "sed -i -r -e 's/#?.*?PasswordAuthentication.*?$/PasswordAuthentication no/g' /etc/ssh/sshd_config",
      "mkdir -p /root/.ssh/",
      "chmod 700 /root/.ssh",
      "echo ${var.root_pub_key} >> /root/.ssh/authorized_keys",
      "chmod 644 /root/.ssh/authorized_keys",
      "systemctl enable ssh"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Installing additional packages...'",
      // Create initramfs flag file for the iscsi module
      "touch /etc/iscsi/iscsi.initramfs",
      "apt install -y initramfs-tools open-iscsi vim hdparm rbd-nbd ceph-common",
      "systemctl start open-iscsi",
      "update-initramfs -v -k \"$(uname -r)\" -u",
    ]
  }

  post-processor "manifest" {
    output = "sdb/output/pibase-manifest.json"
  }
  post-processor "compress" {
    keep_input_artifact = false
    output = "sdb/output/pibase.img.zip"
  }
  post-processor "checksum" {
    checksum_types = ["sha256"]
    output = "sdb/output/pibase.img.sha256"
  }
}
