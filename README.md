# Homelab

These are the manifests and IaC files for my homelab.

## Installation (K3S)

I decided to use [k3s](https://docs.k3s.io/) as a lightweight Kubernetes
cluster implementation, running on a mini pc in my local network as a
single node.

### Dualstack setup

Installing K3S with IPv4 and IPv6 (= dualstack) support requires specific
settings. Here's the install command I've used.

```sh
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable servicelb \ 
--cluster-cidr=10.42.0.0/16,2001:cafe:42::/56 \
--service-cidr=10.43.0.0/16,2001:cafe:43::/112 \
--flannel-backend=none \
--disable-network-policy" sh -
```

Explanation:

- `--disable servicelb` disables the default load balancer service (I'm using
  metallb instead).
- The `cluster_cidr` und `service_cidr` options define the IPv4 and IPv6 ranges
  for the cluster and internal services, respectively.
- `--flannel-backend=none` and `--disable-network-policy` disable the default
  networking service flannel (because I couldn't get IPv6 to run with it and
  opted for calico instead).
