packer {
  required_plugins {
    virtualbox = {
      version = "~> 1.0"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

variable "cpus" {
  type    = string
  default = "4"
}

variable "disk_size" {
  type    = string
  default = "20000"
}

variable "headless" {
  type    = string
  default = "true"
}

variable "hostname" {
  type    = string
  default = "bionic64"
}

variable "http_proxy" {
  type    = string
  default = "${env("http_proxy")}"
}

variable "https_proxy" {
  type    = string
  default = "${env("https_proxy")}"
}

variable "iso_checksum" {
  type    = string
  default = "b8f31413336b9393ad5d8ef0282717b2ab19f007df2e9ed5196c13d8f9153c8b"
}

variable "iso_checksum_type" {
  type    = string
  default = "sha256"
}

variable "iso_name" {
  type    = string
  default = "ubuntu-20.04-live-server-amd64.iso"
}

variable "iso_path" {
  type    = string
  default = "iso"
}

variable "iso_url" {
  type    = string
  default = "http://old-releases.ubuntu.com/releases/focal/ubuntu-20.04-live-server-amd64.iso"
}

variable "memory" {
  type    = string
  default = "4096"
}

variable "no_proxy" {
  type    = string
  default = "${env("no_proxy")}"
}

variable "preseed" {
  type    = string
  default = "preseed.cfg"
}

variable "ssh_fullname" {
  type    = string
  default = "ubuntu"
}

variable "ssh_password" {
  type    = string
  default = "ubuntu"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "update" {
  type    = string
  default = "true"
}

variable "version" {
  type    = string
  default = "0.1"
}

variable "virtualbox_guest_os_type" {
  type    = string
  default = "Ubuntu_64"
}

variable "vm_name" {
  type    = string
  default = "around-backend"
}

source "virtualbox-iso" "around" {
  boot_command = [
    "<enter><wait><enter><f6><esc><wait> ",
    "autoinstall<wait>",
    " cloud-config-url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/user-data<wait>",
    " ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'",
    "<wait5><enter>"
  ]
  boot_wait               = "50s"
  disk_size               = "${var.disk_size}"
  guest_os_type           = "${var.virtualbox_guest_os_type}"
  hard_drive_interface    = "sata"
  headless                = "${var.headless}"
  http_directory          = "http"
  iso_checksum            = "${var.iso_checksum_type}:${var.iso_checksum}"
  iso_urls                = [
    "${var.iso_path}/${var.iso_name}", 
    "${var.iso_url}"
  ]
  output_directory        = "output"
  shutdown_command        = "echo '${var.ssh_password}'|sudo -S shutdown -P now"
  ssh_username            = "${var.ssh_username}"
  ssh_password            = "${var.ssh_password}"
  ssh_timeout             = "30m"
  ssh_port                = 22
  ssh_wait_timeout        = "10000s"
  guest_additions_mode    = "disable"
  vboxmanage              = [
    ["modifyvm", "{{ .Name }}", "--audio", "none"], 
    ["modifyvm", "{{ .Name }}", "--usb", "off"], 
    ["modifyvm", "{{ .Name }}", "--vram", "12"], 
    ["modifyvm", "{{ .Name }}", "--vrde", "off"], 
    ["modifyvm", "{{ .Name }}", "--nictype1", "virtio"], 
    ["modifyvm", "{{ .Name }}", "--memory", "${var.memory}"], 
    ["modifyvm", "{{ .Name }}", "--cpus", "${var.cpus}"],
    ["modifyvm", "{{ .Name }}", "--rtcuseutc", "on"]
  ]
  virtualbox_version_file = ".vbox_version"
  vm_name                 = "${var.vm_name}"
  format                  = "ova"
}

build {
  sources = ["source.virtualbox-iso.around"]
  
  # Копирование SSH-ключа
  provisioner "file" {
    source      = "F:/VSprojects/.ssh/id_ed255519.pub"
    destination = "/home/${var.ssh_username}/authorized_keys"
  }
  
  # Предварительная проверка состояния системы
  provisioner "shell" {
    inline = [
      "echo 'Initial system state:'",
      "df -h",
      "ls -la /tmp"
    ]
  }
  
  provisioner "file" {
    source      = "resources"
    destination = "/tmp/"
  }

  provisioner "file" {
    source      = "script"
    destination = "/tmp/"
  }
  
  # Диагностика после копирования файлов
  provisioner "shell" {
    inline = [
      "echo 'Files in /tmp after copying:'",
      "ls -la /tmp",
      "echo 'Files in script directory (if present):'",
      "ls -la /tmp/script || echo 'script directory not found'",
      "echo 'Checking permissions on script files:'",
      "find /tmp -name '*.sh' -ls || echo 'No script files found'"
    ]
  }
  
  # Установка прав на выполнение для скриптов
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "mkdir -p /root/script-backup",
      "if [ -d '/tmp/script' ]; then cp -rf /tmp/script/* /root/script-backup/; fi",
      "chmod +x /tmp/script/*.sh",
      "chmod +x /root/script-backup/*.sh || echo 'No scripts in backup location'",
      "ls -la /tmp/script/"
    ]
  }
  
  # Базовые настройки системы и установка всех компонентов
  provisioner "shell" {
    environment_vars  = [
      "DEBIAN_FRONTEND=noninteractive", 
      "UPDATE=${var.update}", 
      "SSH_USERNAME=${var.ssh_username}", 
      "SSH_PASSWORD=${var.ssh_password}", 
      "http_proxy=${var.http_proxy}", 
      "https_proxy=${var.https_proxy}", 
      "no_proxy=${var.no_proxy}"
    ]
    execute_command   = "echo '${var.ssh_password}'|{{ .Vars }} sudo -E -S bash '{{ .Path }}'"
    expect_disconnect = true
    scripts           = ["script/update.sh"]
  }
  
  # После перезагрузки проверяем состояние системы
  provisioner "shell" {
    inline = [
      "echo 'System state after update and reboot:'",
      "df -h",
      "uptime",
      "echo 'Checking for successful installation of components:'"
    ]
  }
  
  # Настройка SSH безопасности
  provisioner "shell" {
    environment_vars  = [
      "SSH_USERNAME=${var.ssh_username}"
    ]
    execute_command   = "echo '${var.ssh_password}'|{{ .Vars }} sudo -E -S bash '{{ .Path }}'"
    scripts           = ["script/ssh.sh"]
  }
  
  # Очистка системы в конце
  provisioner "shell" {
    environment_vars  = [
      "SSH_USERNAME=${var.ssh_username}"
    ]
    execute_command   = "echo '${var.ssh_password}'|{{ .Vars }} sudo -E -S bash '{{ .Path }}'"
    scripts           = ["script/cleanup.sh"]
  }
  
  # Финальная проверка установленных компонентов
  provisioner "shell" {
    inline = [
      "echo '==== Проверка установленных компонентов ===='",
      "java -version || echo 'Java not installed'",
      "mvn --version || echo 'Maven not installed'",
      "docker --version || echo 'Docker not installed'",
      "docker-compose --version || echo 'Docker Compose not installed'",
      "systemctl status jenkins || echo 'Jenkins not installed/running'",
      "nginx -v || echo 'Nginx not installed'",
      "echo '==== Проверка завершена ===='"
    ]
  }
}