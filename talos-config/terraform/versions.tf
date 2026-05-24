terraform {
  required_version = ">= 1.11.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.11.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.3"
    }
  }

  backend "s3" {
    bucket = "terraform-state"
    key    = "homelab/talos.tfstate"
    region = "eu-central-1"

    endpoints = {
      s3 = "http://minio.homelab"
    }

    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_lockfile                = true
  }
}
