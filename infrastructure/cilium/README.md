# Cilium manifests

When first setting up a cluster, add the cilium helm repo via `helm repo add
cilium https://helm.cilium.io/` and then install the helm release via the
following command (updating the chart version if necessary):

```sh
helm install \
    cilium \
    cilium/cilium \
    --version 1.17.5 \
    --namespace kube-system \
    --values values.yaml
```
