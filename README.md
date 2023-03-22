# gitops-kubernetes-bootstrap

## Prerequisites

The following prerequisites need to be met before being able to deploy the infrastructure
using this repository:
1. Civo Account
1. Domain name, including DNS Management capabilities, compatible with `external-dns` and `cert-manager`
1. GitHub Account

## Procedure

### Deploy infrastructure

1. Add a static `hosts` entry to enable access to the ArgoCD Web UI (optional):
   ```
   sudo sed -i -E '/argocd\.local/d' /etc/hosts
   sudo echo '127.0.0.1 argocd.local' >>/etc/hosts
   ```
1. Add the following credentials to the `.envrc` file:
   ```
   # CIVO_API_KEY
   # https://www.civo.com/docs/account/api-keys
   # Used by the Civo Crossplane provider to talk to the Civo API
   export CIVO_API_KEY='<very-secret-api-key>'

   # CLOUDFLARE_API_TOKEN
   # https://developers.cloudflare.com/fundamentals/api/get-started/create-token/
   # Used by:
   # * cert-manager to use Cloudflare as DNS01 Challenge Provider for LetsEncrypt
   # * external-dns to automatically update DNS entries for the exposed services
   export CLOUDFLARE_API_TOKEN='<very-secret-token>'

   # GITHUB_TOKEN
   # https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
   # Used by:
   # * ArgoCD running on the Managed Cluster to be able to clone private repositories
   # * Kubelet running on the Managed Cluster to be able to pull images from private registries
   export GITHUB_TOKEN='<very-secret-token>'
   ```
1. Make sure to be directly connected to the Internet and to remove any proxy configuration:
   ```
   # Remove proxy configuration
   unset HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy

   # Test Internet connectivity
   curl -L -s -o /dev/null -w "%{http_code}" civo.com
   ```
1. Start the infrastructure deployment by running the `deploy.sh` script:
   ```
   ./deploy.sh
   ```

### Destroy infrastructure

Tear down the infrastructure deployment by running the `destroy.sh` script:
   ```
   ./destroy.sh
   ```

## Useful commands

### Retrieve ArgoCD initial admin password
```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Install Crossplane CLI (optional)
```
curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh
mv kubectl-crossplane ~/bin/
```

## Useful Links/Resources

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
