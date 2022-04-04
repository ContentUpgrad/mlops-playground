#!/usr/bin/env bash

set -e

# FUNCTIONS

deploy(){
  local app=$1
  kubectl apply -n argocd -f argocd/applications/${app}.yaml

  kubectl delete secret -A -l owner=helm,name=${app}
}

deploy feast
deploy flyte
deploy knative-serving-core
deploy knative-serving-crds
# deploy knative-serving-net-istio
deploy kserve
