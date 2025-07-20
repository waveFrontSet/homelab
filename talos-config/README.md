# Patches for talos configurations

These are my patches for machine configurations.

## Generating

```sh
talosctl gen config trinity-processor https://192.168.2.19:6443 \
  --with-secrets secrets.yaml \
  --config-patch @patches/allow-controlplane-workloads.yaml \
  --config-patch @patches/network-config.yaml \
  --config-patch @patches/install-disk.yaml \
  --config-patch @patches/interface-names.yaml \
  --config-patch @patches/kubelet-certificates.yaml \
  --config-patch @patches/cluster-ips.yaml \
  --output rendered/ --force
```

## Applying

``` sh
talosctl apply -f rendered/controlplane.yaml -n <NODE> [--insecure]
```

## Upgrading / adding extensions

Update `bare-metal.yaml` with the needed extension, then execute:

``` sh
curl -X POST --data-binary @bare-metal.yaml https://factory.talos.dev/schematics
```

This will return an id. Use that id in the following command:

``` sh
talosctl upgrade \
  --image factory.talos.dev/metal-installer/<ID>:v<TALOS-VERSION> \
  -n <NODE> --force --wait=false
```
