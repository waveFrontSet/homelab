talos_version      = "v1.12.8"
kubernetes_version = "1.35.4"


nodes = {
  pneuma = {
    ip           = "192.168.2.102"
    install_disk = "/dev/nvme0n1"
    interface    = "enp1s0"
  }
  ontos = {
    ip           = "192.168.2.103"
    install_disk = "/dev/nvme0n1"
    interface    = "enp0s31f6"
  }
  logos = {
    ip           = "192.168.2.104"
    install_disk = "/dev/nvme0n1"
    interface    = "enp0s31f6"
  }
}
