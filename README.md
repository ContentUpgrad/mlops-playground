# MLOps Sandbox

> The repository contains a local k8s kind setup with argocd and MLOps tools. This is aimed for local development and testing of different services.


The below guide assumes that you have `docker`, `kubectl`, `kind` & `kustomize` preinstalled on your system.


If you are on a MacOS this is as easy as:

```bash
brew install docker kubectl kind kustomize dnsmasq
```

Furthermore, if you are planning to develop and run the services locally you will need to increase the default resources for Docker:

CPUs: 8 Cores
Memory: 16 GB RAM
Disk: 32+ GB
## Set up local kind sandbox cluster

Here we will provide a guide to set up your environment for local kubernetes development using [kind](https://kind.sigs.k8s.io/docs/user/quick-start). You are free to use [`minikube`](https://minikube.sigs.k8s.io/docs/start/) or [`Docker for Mac`](https://docs.docker.com/desktop/mac/install/), but I personally prefer kind as it is easier to get your local environment to reflect the the production environment and it is highly customizable.

> [**kind** or kubernetes in docker is a suite of tooling for local Kubernetes “clusters” where each “node” is a Docker container. kind is targeted at testing Kubernetes.](https://kind.sigs.k8s.io/docs/user/quick-start/)

The `Makefile` includes some utility functions to help you get going:

The below command will set up a local kind cluster for you together with argocd for gitops:

```bash
make startup
```

In order to kill the cluster and cleanup resources you may use:

```bash
make teardown
```

> **NOTE**: IF you are on Monterey you might have to turn of Preferences>Sharing>Airplay receiver. Alternatively, change the port for the local registry.

## Argocd


You can install [argocd](./kind/argocd.sh) in the kind cluster by `bash ./kind/argocd.sh` or `make argocd`.

The `argo-ui` is by default reachable at `https://argocd.127.0.0.1.nip.io`. with the default admin user `admin` and the password can be retrieved by:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

> The secret will also be printed by the bash script

The [argocd](./argocd/applications) folder contains code ArgoCD application manifests. In order to start syncing an application; run `kubectl apply -f ./argocd/applications/<application name>`.

**Available applications:**


- [prometheus-operator](./argocd/applications/prometheus-operator.yaml)
- [knative](./argocd/applications/knative.yaml)
- [kserve](argocd/applications/kserve.yaml)
- [feast](argocd/applications/feast.yaml)
- [flyte](argocd/applications/flyte.yaml)

> You can also use `make mlops` which will install the mlops-tools via [deploy_mlops.sh](./hack/deploy_mlops.sh). Feel free to combine the services according to your needs.
