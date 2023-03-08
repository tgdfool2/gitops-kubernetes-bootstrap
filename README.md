# gitops-kubernetes-bootstrap

## Procedure

```
kind create cluster --config controlplane/kind.yaml

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version "5.24.1" --wait

k apply -f \
  https://raw.githubusercontent.com/tgdfool2/gitops-kubernetes-bootstrap/main/controlplane/bootstrap.yaml

# Retrieve admin password:
k -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

export CIVO_API_KEY='<very-secret-api-key>'
sed "s/<CIVO_API_KEY>/${CIVO_API_KEY}/" controlplane/resources/civo/providerconfig.yaml | k apply -f -

k apply -f controlplane/resources/civo/cluster.yaml

k -n crossplane-system get secrets creds-test-crossplane -o json | jq -r '.data.kubeconfig | @base64d' \
  >/var/tmp/test-crossplane.kubeconfig

argocd login argocd.local --insecure --grpc-web --username admin \
  --password "$(k -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
argocd cluster add test-crossplane --kubeconfig /var/tmp/test-crossplane.kubeconfig --yes

export CLOUDFLARE_API_TOKEN='<very-secret-token>'
sed "s/<CLOUDFLARE_API_TOKEN>/${CLOUDFLARE_API_TOKEN}/" \
  managedcluster/resources/cloudflare/credentials.yaml | \
  k --kubeconfig /var/tmp/test-crossplane.kubeconfig apply -f -

k apply -f \
  https://raw.githubusercontent.com/tgdfool2/gitops-kubernetes-bootstrap/main/managedcluster/bootstrap.yaml

# Tear down
k delete -f controlplane/resources/civo/cluster.yaml
kind delete cluster -n test-crossplane

# Install Crossplane CLI (optional)
curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh
mv kubectl-crossplane ~/bin/
```

## Resources

### kind
* https://magmax.org/en/blog/argocd/
* https://hub.docker.com/r/kindest/node/tags
* https://nickjanetakis.com/blog/configuring-a-kind-cluster-with-nginx-ingress-using-terraform-and-helm

### Crossplane
* https://www.youtube.com/watch?v=Dw0SMLHZvXM
* https://github.com/anais-codefresh/crossplane-example
* https://github.com/vfarcic/crossplane-composite-demo.git

### ArgoCD Secrets management
* https://medium.com/containers-101/gitops-secret-management-with-azure-csi-secret-store-960800a550e6
* https://github.com/Azure/secrets-store-csi-driver-provider-azure#provide-identity-to-access-key-vault
* https://cloud.redhat.com/blog/how-to-use-argocd-deployments-with-github-tokens

### ArgoCD Example Apps
* https://github.com/argoproj/argocd-example-apps
* https://github.com/dockersamples/example-voting-app

### ArgoCD App of Apps
* https://www.youtube.com/watch?v=GAu1INNeE7E&t=2s&ab_channel=CloudNativeSkunkworks
