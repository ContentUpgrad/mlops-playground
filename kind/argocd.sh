#!/usr/bin/env bash

set -e

# CONSTANTS

readonly DOMAIN=127.0.0.1.nip.io


# FUNCTIONS

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

argocd(){
  log "ARGOCD ..."

  helm upgrade --install --wait --timeout 15m --atomic --namespace argocd --create-namespace \
    --repo https://argoproj.github.io/argo-helm argocd argo-cd --values - <<EOF
dex:
  enabled: false
redis:
  enabled: true
redis-ha:
  enabled: false
repoServer:
  serviceAccount:
    create: true
server:
  config:
    url: https://argocd.$DOMAIN
    application.instanceLabelKey: argocd.argoproj.io/instance
    admin.enabled: 'true'
    resource.exclusions: |
      - apiGroups:
          - cilium.io
        kinds:
          - CiliumIdentity
        clusters:
          - '*'
    resource.compareoptions: |
      ignoreResourceStatusField: all
  rbacConfig:
    policy.default: role:readonly
    policy.csv: |
      g, argocd-admin, role:admin
  extraArgs:
    - --insecure
  ingress:
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: ca-issuer
    enabled: true
    hosts:
      - argocd.$DOMAIN
    tls:
      - secretName: argocd.$DOMAIN
        hosts:
          - argocd.$DOMAIN
EOF
}

# RUN

argocd

# DONE

log "ARGOCD READY !"

echo "ARGOCD: https://argocd.$DOMAIN"

PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "ADMIN: admin PASSWORD:$PASSWORD"
