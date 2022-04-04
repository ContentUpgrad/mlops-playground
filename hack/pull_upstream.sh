#!/usr/bin/env bash

# Requires kubectl-slice & yq, helm3

set -euo pipefail


# Functions

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}


slice_explode(){
    local name=$1
    local filename=$2

    log "explode and slice ${filename}.yaml"

    yq 'explode(.)' "${name}/upstream/${filename}.yaml" > "${name}/upstream/${filename}-explode.yaml"
    # Move manifests to separate files
    kubectl-slice --input-file="${name}/upstream/${filename}-explode.yaml" --output-dir="${name}/upstream/"
    rm "${name}/upstream/${filename}.yaml" "${name}/upstream/${filename}-explode.yaml"
}

create_kustomization(){
    local name=$1

    log "Writing kustomization.yaml"
    cat <<EOF >"${name}/upstream/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
$(ls -1 ${name}/upstream/|sed -e 's/^/- /'| sed -n '/kustomization.yaml/!p')
EOF
}

pull_release_manifests(){
    local name=$1
    local repo=$2
    local version=$3
    local manifest=$4
    local url="https://github.com/${repo}/releases/download/${version}/${manifest}.yaml"

    log "Pulling upstream ${repo} ${version}"
    mkdir -p "./${name}/upstream/"
    curl -sSL -o "./${name}/upstream/${manifest}.yaml" "${url}"

    slice_explode ${name} ${manifest}
    create_kustomization ${name}

    log "Pulled ${repo} upstream ${version} to ./${name}/upstream/"
}

pull_helm_manifests(){
    local chart=$1
    local repo=$2
    local url=$3
    local version=$4

    log "Pulling ${chart} from ${url}"
    helm repo add ${repo} ${url}
    helm repo update ${repo}
    mkdir -p "./${chart}/upstream/"
    helm template "${chart}-${version}" ${repo}/${chart} --version ${version} -n ${chart} > "./${chart}/upstream/output.yaml"
    slice_explode ${chart} "output"
    create_kustomization ${chart}
}


# Flyte
readonly FLYTE_VERSION="v0.19.3-b3"
readonly FLYTE_REPO="flyteorg/flyte"
readonly FLYTE_MANIFEST="flyte_sandbox_manifest"
# Feast
readonly FEAST_VERSION="0.19.3"
readonly FEAST_URL="https://feast-helm-charts.storage.googleapis.com"
readonly FEAST_REPO="feast-charts"
readonly FEAST_CHART="feast"
# Knative Serving
readonly KNATIVE_SERVING_VERSION="knative-v1.3.0"
readonly KNATIVE_SERVING_REPO="knative/serving"
readonly KNATIVE_NET_ISTIO_REPO="knative/net-istio"
# Kserve
readonly KSERVE_VERSION="v0.8.0"
readonly KSERVE_REPO="kserve/kserve"

pull_release_manifests "flyte-sandbox" $FLYTE_REPO $FLYTE_VERSION $FLYTE_MANIFEST
pull_helm_manifests $FEAST_CHART $FEAST_REPO $FEAST_URL $FEAST_VERSION
pull_release_manifests "knative/core" $KNATIVE_SERVING_REPO $KNATIVE_SERVING_VERSION "serving-core"
pull_release_manifests "knative/crds" $KNATIVE_SERVING_REPO $KNATIVE_SERVING_VERSION "serving-crds"
pull_release_manifests "knative/net-istio" $KNATIVE_NET_ISTIO_REPO $KNATIVE_SERVING_VERSION "release"
pull_release_manifests "kserve" $KSERVE_REPO $KSERVE_VERSION "kserve"
