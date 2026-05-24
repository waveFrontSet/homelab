talos_version      = "v1.12.7"
kubernetes_version = "1.35.4"
talos_schematic_id = "056d8e12ba2b9711c613665c43f0ebf86eb451839a22f360a42110362f84faa1"

nodes = {
  pneuma = {
    ip           = "192.168.2.102"
    install_disk = "/dev/nvme0n1"
    hostname     = "pneuma"
  }
  ontos = {
    ip           = "192.168.2.103"
    install_disk = "/dev/nvme0n1"
    hostname     = "ontos"
  }
  logos = {
    ip           = "192.168.2.104"
    install_disk = "/dev/nvme0n1"
    hostname     = "logos"
  }
}
