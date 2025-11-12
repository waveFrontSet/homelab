# Homelab

These are the manifests and IaC files for my homelab.

## Installation (talos)

I've migrated the cluster from a single-node k3s cluster to a three-node talos
cluster. The talos config I've used to install talos onto the nodes is in
[./talos-config](./talos-config).

Important caveat: Because I wanted to have a dualstack network setup, I needed
to deactivate the default CNI flanel. After applying the machine configs and
bootstrapping the kubernetes cluster but BEFORE bootstrapping flux, cilium needs
to be installed manually, preferably via `helm`. See
[./infrastructure/cilium/README.md](./infrastructure/cilium/README.md) for
details.
  
## Apps
  
Apps in my cluster were migrated via a lift-and-shift approach from systemd
processes provisioned via ansible.

### blocky

[blocky](https://0xerr0r.github.io/blocky/latest/) is a DNS proxy for blocking ads.
I also use it as local DNS server for my homelab, replacing pihole.

### homeassistant

[Home Assistant](https://www.home-assistant.io/) is a home automation s
platform.

### jellyfin

[Jellyfin](https://jellyfin.org/) is an opensource media server and, thus,
a replacement for the (arguably) more popular plex.

### paperless

[Paperless](https://docs.paperless-ngx.com/) is an opensource document
management system.

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
