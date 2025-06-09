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
- The `cluster_cidr` and `service_cidr` options define the IPv4 and IPv6 ranges
  for the cluster and internal services, respectively.
- `--flannel-backend=none` and `--disable-network-policy` disable the default
  networking service flannel (because I couldn't get IPv6 to run with it and
  opted for calico instead).
  
## Apps
  
Apps in my cluster were migrated via a lift-and-shift approach from systemd
processes provisioned via ansible.

### jellyfin

[Jellyfin](https://jellyfin.org/) is an opensource media server and, thus,
a replacement for the (arguably) more popular plex.

### paperless

[Paperless](https://docs.paperless-ngx.com/) is an opensource document
management system.

### pihole

[Pihole](https://pi-hole.net/) is a network service for blocking ads.
It also comes equipped with a simple DNS server - and that's for I mostly
use it for.

### scrapyd

[Scrapy](https://www.scrapy.org/) is my favorite Python framework for web
crawling tasks. It's mature, has sensible modules and a lot of quality of life
features. Scrapy's main concept is the `Spider` class that contains the crawl
logic. One can use Scrapy's CLI to start such a `Spider`.  For deployment of
spiders, there's a [daemon service with a JSON API called
`scrapyd`](https://scrapyd.readthedocs.io/en/stable/). It may schedule and spawn
crawling processes based on spiders.

It's tempting to improve `scrapyd` to start Kubernetes jobs instead and, indeed,
there's some effort in implementing a kubernetes-native `scrapyd` version:
[scrapyd-k8s](https://github.com/q-m/scrapyd-k8s). I'm not convinced of its
maturity yet but I'll definitely spend some time trying this one out.

Finally, there's also [scrapydweb](https://github.com/my8100/scrapydweb) that
provides a nice frontend for `scrapyd`.
