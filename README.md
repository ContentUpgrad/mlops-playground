# MLOps Playground

> The repository contains a playground for OSS cloud-native MLOps tools. Furthermore, it has bootstrap scripts to set up cluster environments locally with `kind` and in the cloud (`gke`).

The [bootstraps](./cluster) contains a lightweight k8s cluster together with `argocd` to enable gitops. In addtion to some popular services that usually come along with a k8s installation eg, prometheus & grafana.

The goal is to provide a playground, where you can combine services into a `stack` and try them out locally, or on some popular cloud provider.

> We make heavy use of `kustomize` and we are working on overlay configuration for each cluster.

In order to get going you will need `docker`, `kubectl`, `kind`, `kpt` &  `kustomize` installed.

If you are on a MacOS this is as easy as:

```bash
brew install docker kubectl kind kustomize kpt
```

Furthermore, if you are planning to develop and run the services locally you will need to increase the default resources for Docker:

- CPUs: 8 Cores
- Memory: 16 GB RAM
- Disk: 32+ GB
## Set up local kind sandbox cluster

Here we will provide a guide to set up your environment for local kubernetes development using [kind](https://kind.sigs.k8s.io/docs/user/quick-start). You are free to use [`minikube`](https://minikube.sigs.k8s.io/docs/start/) or [`Docker for Mac`](https://docs.docker.com/desktop/mac/install/), but I personally prefer kind as it is easier to get your local environment to reflect the the production environment and it is highly customizable.

> [**kind** or kubernetes in docker is a suite of tooling for local Kubernetes “clusters” where each “node” is a Docker container. kind is targeted at testing Kubernetes.](https://kind.sigs.k8s.io/docs/user/quick-start/)

The `Makefile` includes some utility functions to help you get going:

The below command will set up a local kind cluster for you together with argocd for gitops:

```bash
make startup
```

> The startup command will require you to enter your password for `sudo`. The cluster setup includes `cert-manager` & it creates a root-ca.

In order to tear down the resources and cleanup resources you may use:

```bash
make teardown
```

> **NOTE**: IF you are on Monterey you might have to turn of Preferences>Sharing>Airplay receiver. Alternatively, change the port for the local registry.

#### TODO

- [ ]  Set up [metallb](https://metallb.universe.tf/) to enable `LoadBalancer` locally.
- [ ]  Include calico & istio setup

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
- [knative-serving](./argocd/applications/knative-serving-core.yaml)
- [kserve](argocd/applications/kserve.yaml)
- [feast](argocd/applications/feast.yaml)
- [flyte](argocd/applications/flyte.yaml)

> You can also use `make mlops` which will install the mlops-tools via [deploy_mlops.sh](./hack/deploy_mlops.sh). Feel free to combine the services according to your needs.

#### TODO

- [ ]  Write relevant patches for `kind/gke/eks/aks`
- [ ]  Include more services

# [WIP] GKE

Here we provide a guide to provision a GKE cluster instead of kind. The workflow will be fairly similar as will the services, which is one of the core benefits of kubernetes.

We will make use of terraform which is an IaC tool. In order to proceed you need to install `gcloud` cli and `terraform`:

```bash
brew install --cask google-cloud-sdk
```

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

If you are not on a MacOS you can follow the official guides by [Hashicorp](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/gcp-get-started)

Replace values in [terraform.tfvars](gke/terraform.tfvars)

> You can get your `gcloud` project via `gcloud config get-value project`

Initialize, your tf workspace with `terraform init` then provision the vpc and gke with `terraform apply`

> **NOTE:** Compute Engine API and Kubernetes Engine API are required for terraform apply to work on this configuration. Enable both APIs for your Google Cloud project before continuing.


## Configure `kubectl`

Run the following command to retrieve the access credentials for your cluster and automatically configure `kubectl`

```bash
gcloud container clusters get-credentials $(terraform output -raw kubernetes_cluster_name) --region $(terraform output -raw region)
```
