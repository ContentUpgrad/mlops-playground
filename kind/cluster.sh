#!/bin/bash
cd "$(cd "$(dirname "$0")" > /dev/null && pwd)"

set -e

readonly KIND_NODE_IMAGE=kindest/node:v1.23.3
kind_version=$(kind version)
kind_network='kind'
reg_name='kind-registry'
reg_port='5000'


log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}


subnet_to_ip(){
  echo $1 | sed "s@0.0/16@$2@"
}

root_ca(){
  log "ROOT CERTIFICATE ..."

  mkdir -p .ssl

  if [[ -f ".ssl/root-ca.pem" && -f ".ssl/root-ca-key.pem" ]]
  then
    echo "Root certificate already exists, skipping"
  else
    openssl genrsa -out .ssl/root-ca-key.pem 2048
    openssl req -x509 -new -nodes -key .ssl/root-ca-key.pem -days 3650 -sha256 -out .ssl/root-ca.pem -subj "/CN=kube-ca"
    echo "Root certificate created"
  fi
}

install_ca_mac(){
  log "INSTALL CERTIFICATE AUTHORITY ..."

  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain .ssl/root-ca.pem

}


proxy(){
  local NAME=$1
  local TARGET=$2

  if [ -z $(docker ps --filter name=^proxy-gcr$ --format="{{ .Names }}") ]
  then
    docker run -d --name $NAME --restart=always --net=kind -e REGISTRY_PROXY_REMOTEURL=$TARGET registry:2
    echo "Proxy $NAME (-> $TARGET) created"
  else
    echo "Proxy $NAME already exists, skipping"
  fi
}

proxies(){
  log "REGISTRY PROXIES ..."

  proxy proxy-docker-hub https://registry-1.docker.io
  proxy proxy-quay       https://quay.io
  proxy proxy-gcr        https://gcr.io
  proxy proxy-k8s-gcr    https://k8s.gcr.io
}


cilium(){
    log "Install cilium CNI"
    helm upgrade --install --namespace kube-system --repo https://helm.cilium.io cilium cilium --values - <<EOF
kubeProxyReplacement: strict
k8sServiceHost: kind-control-plane
k8sServicePort: 6443
hostServices:
  enabled: false
externalIPs:
  enabled: true
nodePort:
  enabled: true
hostPort:
  enabled: true
image:
  pullPolicy: IfNotPresent
ipam:
  mode: kubernetes
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
    ingress:
      enabled: true
      annotations:
        cert-manager.io/cluster-issuer: ca-issuer
        kubernetes.io/ingress.class: nginx
      hosts:
        - hubble-ui.127.0.0.1.nip.io
EOF
}

cluster(){
    log "Create kind cluster"
    kind create cluster --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  kubeProxyMode: none
kubeadmConfigPatches:
  - |-
    kind: ClusterConfiguration
    apiServer:
      extraVolumes:
        - name: opt-ca-certificates
          hostPath: /opt/ca-certificates/root-ca.pem
          mountPath: /opt/ca-certificates/root-ca.pem
          readOnly: true
          pathType: File
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["http://proxy-docker-hub:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
      endpoint = ["http://proxy-quay:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
      endpoint = ["http://proxy-k8s-gcr:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
      endpoint = ["http://proxy-gcr:5000"]
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
    - containerPort: 80
      hostPort: 80
      listenAddress: 127.0.0.1
      protocol: TCP
    - containerPort: 443
      hostPort: 443
      listenAddress: 127.0.0.1
      protocol: TCP
  extraMounts:
  - hostPath: $PWD/.ssl/root-ca.pem
    containerPath: /opt/ca-certificates/root-ca.pem
    readOnly: true
- role: worker
  extraMounts:
    - hostPath: $PWD/.ssl/root-ca.pem
      containerPath: /opt/ca-certificates/root-ca.pem
      readOnly: true
- role: worker
  extraMounts:
    - hostPath: $PWD/.ssl/root-ca.pem
      containerPath: /opt/ca-certificates/root-ca.pem
      readOnly: true
- role: worker
  extraMounts:
    - hostPath: $PWD/.ssl/root-ca.pem
      containerPath: /opt/ca-certificates/root-ca.pem
      readOnly: true

EOF
}


cert_manager(){
  log "CERT MANAGER ..."

  helm upgrade --install --wait --timeout 15m --atomic --namespace cert-manager --create-namespace \
    --repo https://charts.jetstack.io cert-manager cert-manager --values - <<EOF
installCRDs: true
EOF
}


root_ca(){
  log "ROOT CERTIFICATE ..."

  mkdir -p .ssl

  if [[ -f ".ssl/root-ca.pem" && -f ".ssl/root-ca-key.pem" ]]
  then
    echo "Root certificate already exists, skipping"
  else
    openssl genrsa -out .ssl/root-ca-key.pem 2048
    openssl req -x509 -new -nodes -key .ssl/root-ca-key.pem -days 3650 -sha256 -out .ssl/root-ca.pem -subj "/CN=kube-ca"
    echo "Root certificate created"
  fi
}

install_ca_mac(){
  log "INSTALL CERTIFICATE AUTHORITY ..."

  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain .ssl/root-ca.pem

}


cert_manager_ca_secret(){
  kubectl delete secret -n cert-manager root-ca || true
  kubectl create secret tls -n cert-manager root-ca --cert=.ssl/root-ca.pem --key=.ssl/root-ca-key.pem
}

cert_manager_ca_issuer(){
  kubectl apply -n cert-manager -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: root-ca
EOF
}


ngnix_ingress(){
    log "Install nginx ingress controller"
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.1/deploy/static/provider/kind/deploy.yaml
}

argocd(){
  log "Installing Argocd"

  helm upgrade --install --wait --timeout 15m --atomic --namespace argocd --create-namespace \
    --repo https://argoproj.github.io/argo-helm argocd argo-cd
  sleep 120

  kubectl apply -f ./config/ingress.yaml

  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
}


proxies
root_ca
install_ca_mac
cluster
cilium
cert_manager
cert_manager_ca_secret
cert_manager_ca_issuer
ngnix_ingress
