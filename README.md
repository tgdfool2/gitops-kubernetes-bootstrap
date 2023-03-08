# kind
https://magmax.org/en/blog/argocd/
https://hub.docker.com/r/kindest/node/tags
https://nickjanetakis.com/blog/configuring-a-kind-cluster-with-nginx-ingress-using-terraform-and-helm

# Crossplane
https://www.youtube.com/watch?v=Dw0SMLHZvXM
https://github.com/anais-codefresh/crossplane-example
https://github.com/vfarcic/crossplane-composite-demo.git

# ArgoCD Secrets management
https://medium.com/containers-101/gitops-secret-management-with-azure-csi-secret-store-960800a550e6
https://github.com/Azure/secrets-store-csi-driver-provider-azure#provide-identity-to-access-key-vault
https://cloud.redhat.com/blog/how-to-use-argocd-deployments-with-github-tokens

# ArgoCD Example Apps
https://github.com/argoproj/argocd-example-apps
https://github.com/dockersamples/example-voting-app

# ArgoCD App of Apps
https://www.youtube.com/watch?v=GAu1INNeE7E&t=2s&ab_channel=CloudNativeSkunkworks

#
# Short version
#

kind create cluster --config controlplane/kind.yaml

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version "5.24.1" --wait

k apply -f \
  https://raw.githubusercontent.com/tgdfool2/gitops-kubernetes-bootstrap/main/controlplane/bootstrap.yaml

k -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# => New Password: Argo.555$

# BEGIN CIVO
export CIVO_API_KEY='<very-secret-api-key>'
sed "s/<CIVO_API_KEY>/${CIVO_API_KEY}/" controlplane/resources/civo/providerconfig.yaml | k apply -f -

k apply -f controlplane/resources/civo/cluster.yaml
# END CIVO

k -n crossplane-system get secrets creds-test-crossplane -o json | jq -r '.data.kubeconfig | @base64d' \
  >/var/tmp/test-crossplane.kubeconfig

argocd login argocd.local --insecure --grpc-web --username admin \
  --password "$(k -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
argocd cluster add test-crossplane --kubeconfig /var/tmp/test-crossplane.kubeconfig --yes

export CLOUDFLARE_API_TOKEN='<very-secret-token>'
sed "s/<CLOUDFLARE_API_TOKEN>/${CLOUDFLARE_API_TOKEN}/" \
  managedcluster/resources/external-dns/cloudflare-credentials.yaml | \
  k --kubeconfig /var/tmp/test-crossplane.kubeconfig apply -f -

k apply -f \
  https://raw.githubusercontent.com/tgdfool2/gitops-kubernetes-bootstrap/main/managedcluster/bootstrap.yaml

# Tear down
k delete -f controlplane/resources/azure/cluster.yaml
kind delete cluster -n test-crossplane



# BEGIN AZURE --- working but much slower
export AZURE_CLIENT_ID='<very-secret-client-id>'
export AZURE_CLIENT_SECRET='<very-secret-client-secret>'
export AZURE_SUBSCRIPTION_ID='<very-secret-subscription-id>'
export AZURE_TENANT_ID='<very-secret-tenant-id>'

sed -e "s/<AZURE_CLIENT_ID>/${AZURE_CLIENT_ID}/" \
    -e "s/<AZURE_CLIENT_SECRET>/${AZURE_CLIENT_SECRET}/" \
    -e "s/<AZURE_SUBSCRIPTION_ID>/${AZURE_SUBSCRIPTION_ID}/" \
    -e "s/<AZURE_TENANT_ID>/${AZURE_TENANT_ID}/" \
  controlplane/resources/azure/creds.json >/var/tmp/azure-creds.json

k create secret generic azure-creds -n crossplane-system \
  --from-file=creds=/var/tmp/azure-creds.json
k apply -f controlplane/resources/azure/providerconfig.yaml

rm -f /var/tmp/azure-creds.json

k apply -f controlplane/resources/azure/cluster.yaml
# END AZURE

#
# Start Here
#

kind create cluster --config kind/kind.yaml

#
# ingress-nginx installation
#

# Public
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install --namespace ingress-nginx --create-namespace \
  --values ingress-nginx/values-kind.yaml ingress-nginx ingress-nginx/ingress-nginx \
  --version "4.5.2"

# Internal
#helm repo add ingress-nginx-internal https://artifactory.swisscom.com/artifactory/k8s-ingress-nginx-helm-virtual
#helm repo update
#helm upgrade --install --namespace ingress-nginx --create-namespace \
#  --values ingress-nginx/values-kind.yaml ingress-nginx ingress-nginx-internal/ingress-nginx \
#  --version "4.5.2"

#
# cert-manager installation
#

# Public
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --values cert-manager/values-kind.yaml \
  --version "v1.9.2"

# Internal
#helm repo add jetstack-internal https://artifactory.swisscom.com/artifactory/jetstack-helm-virtual
#helm repo update
#helm upgrade --install cert-manager jetstack-internal/cert-manager \
#  --namespace cert-manager --create-namespace \
#  --values cert-manager/values-kind.yaml \
#  --version "v1.9.2"

k apply -f cert-manager/cert-issuer.yaml

#
# ArgoCD Installation
#

# Public
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --values argocd/values-kind.yaml \
  --version "5.24.1"

# Internal
#helm repo add argo-internal https://artifactory.swisscom.com/artifactory/argo-helm-virtual
#helm repo update
#helm upgrade --install argocd argo-internal/argo-cd \
#  --namespace argocd --create-namespace \
#  --values argocd/values-kind.yaml \
#  --version "5.24.1"

k apply -f argocd/argocd-ingress-nginx.yaml
k -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# => New Password: Argo.555$

#
# Crossplane Installation
#

# Public
helm repo add crossplane https://charts.crossplane.io/stable
helm repo update
helm upgrade --install crossplane crossplane/crossplane \
  --namespace crossplane-system --create-namespace \
  --values crossplane/values-kind.yaml \
  --version "1.11.1"

# Internal
#helm repo add crossplane-internal https://artifactory.swisscom.com/artifactory/crossplane-helm-virtual/
#helm repo update
#helm upgrade --install crossplane crossplane-internal/crossplane \
#  --namespace crossplane-system --create-namespace \
#  --values crossplane/values-kind.yaml \
#  --version "1.11.1"

# Install CLI
curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh
mv kubectl-crossplane ~/bin/

# Civo
kubectl crossplane install provider xpkg.upbound.io/civo/provider-civo:v0.1

# Internal:
# => edit provider URL
# => xpkg-upbound-docker-remote.artifactory.swisscom.com/civo/provider-civo

# Azure
k create secret generic azure-creds -n crossplane-system \
  --from-file=creds=./crossplane/azure/azure-creds-managed-int.json
# Terrajet
#k apply -f crossplane/azure/azure-terrajet/azure-jet-provider-preview.yaml
k apply -f crossplane/azure/azure-terrajet/azure-jet-provider.yaml
k apply -f crossplane/azure/azure-terrajet/azure-jet-providerconfig.yaml
k apply -f argocd/argocd-repo-secret.yaml
k apply -f argocd/azure-infra-app.yaml

# AWS
kubectl create secret generic aws-creds -n crossplane-system --from-file=creds=./aws-creds-pcms.txt
k apply -f aws-provider.yaml
k apply -f aws-providerconfig.yaml
k apply -f aws-vpc.yaml
