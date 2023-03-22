#!/bin/bash

echo '### Start'
date
echo

echo '### Spin up kind cluster (controlplane)'
kind create cluster --config controlplane/kind.yaml
echo -e '### Done!\n'

sleep 10

echo '### Manually deploy ArgoCD (it will be automatically managed by itself afterwards)'
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version "5.24.1" --wait
echo -e '### Done!\n'

sleep 10

echo '### Initiate Infrastructure Bootstrap on kind cluster (controlplane)'
kubectl apply -f ./controlplane/bootstrap.yaml
echo -e '### Done!\n'

echo '### Wait for all the components to be fully deployed'
sleep 30
while true; do
  kubectl -n argocd get applications --no-headers | \
    egrep -v 'Synced.*Healthy' >/dev/null
    if [[ $? -eq 1 ]]; then break; fi
  echo 'Still waiting...'
  sleep 10
done
sleep 10
echo -e '### Done!\n'

echo '### Configure Crossplane Civo Provider credentials and initiate managed cluster deployment'
sed "s/<CIVO_API_KEY>/$(echo -n ${CIVO_API_KEY} | base64)/" ./controlplane/resources/civo/providerconfig.yaml | \
  kubectl apply -f - && kubectl apply -f ./controlplane/resources/civo/cluster.yaml
echo -e '### Done!\n'

echo '### Wait for the managed cluster to be ready'
sleep 30
while true; do
  kubectl get civokubernetes.cluster.civo.crossplane.io test-crossplane --no-headers | \
    egrep 'True.*active' >/dev/null
    if [[ $? -eq 0 ]]; then break; fi
  echo 'Still waiting...'
  sleep 10
done
sleep 10
echo -e '### Done!\n'

echo '### Retrieve kubeconfig for managed cluster and store it locally'
kubectl -n crossplane-system get secrets creds-test-crossplane -o json | \
  jq -r '.data.kubeconfig | @base64d' >/var/tmp/test-crossplane.kubeconfig
echo -e '### Done!\n'

echo '### Add managed cluster to ArgoCD running on kind cluster'
argocd login argocd.local --insecure --grpc-web --username admin \
  --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
argocd cluster add test-crossplane --kubeconfig /var/tmp/test-crossplane.kubeconfig --yes
echo -e '### Done!\n'

echo '### Deploy Cloudflare credentials to managed cluster'
sed "s/<CLOUDFLARE_API_TOKEN>/${CLOUDFLARE_API_TOKEN}/" \
  managedcluster/resources/cloudflare/credentials.yaml | \
  kubectl --kubeconfig /var/tmp/test-crossplane.kubeconfig apply -f -
echo -e '### Done!\n'

echo '### Initiate Infrastructure Bootstrap on managed cluster (test-crossplane)'
kubectl apply -f ./managedcluster/bootstrap.yaml
echo -e '### Done!\n'

echo '### Wait for all the components to be fully deployed'
sleep 30
while true; do
  kubectl -n argocd get applications --no-headers | \
    egrep -v 'Synced.*Healthy' >/dev/null
    if [[ $? -eq 1 ]]; then break; fi
  echo 'Still waiting...'
  sleep 10
done
sleep 10
echo -e '### Done!\n'

echo '### Create ArgoCD Repo Creds on managed cluster'
sed "s/<GITHUB_TOKEN>/${GITHUB_TOKEN}/" \
  ./managedcluster/resources/argocd/repo-creds.yaml | \
  kubectl --kubeconfig /var/tmp/test-crossplane.kubeconfig apply -f -
echo -e '### Done!\n'

echo '### Create ImagePullSecret in assessement Namespace on managed cluster'
kubectl --kubeconfig /var/tmp/test-crossplane.kubeconfig create ns assessment
DOCKERCONFIGJSON=$(echo -n "{ \"auths\": { \"ghcr.io\": { \"auth\": \"$(echo -n "tgdfool2:${GITHUB_TOKEN}" | base64)\" } } }" | base64)
sed "s/<DOCKERCONFIGJSON>/${DOCKERCONFIGJSON}/" \
  managedcluster/resources/argocd/imagepullsecret.yaml | \
  kubectl --kubeconfig /var/tmp/test-crossplane.kubeconfig apply -f -
kubectl --kubeconfig /var/tmp/test-crossplane.kubeconfig -n assessment patch serviceaccount default \
  -p '{"imagePullSecrets": [{"name": "ghcr-imagepullsecret"}]}'
echo -e '### Done!\n'

echo '### Temporarily set Kyverno Policies to "audit" mode'
for POLICY in require-run-as-nonroot require-run-as-non-root-user; do
  kubectl --kubeconfig /var/tmp/test-crossplane.kubeconfig patch clusterpolicies.kyverno.io ${POLICY} \
    --type merge  -p '{"spec": {"validationFailureAction": "audit"}}'
done
sleep 10
echo -e '### Done!\n'

echo '### Bootstrap assessment application on managed cluster'
kubectl --kubeconfig /var/tmp/test-crossplane.kubeconfig apply -f ./applications/bootstrap.yaml
sleep 30
echo -e '### Done!\n'

echo '### Temporarily scale down assessment application to 0 replica'
kubectl --kubeconfig /var/tmp/test-crossplane.kubeconfig -n assessment \
  scale deployment assessment --replicas=0
sleep 10
echo -e '### Done!\n'

echo '### Reset Kyverno Policies to "enforce" mode'
for POLICY in require-run-as-nonroot require-run-as-non-root-user; do
  kubectl --kubeconfig /var/tmp/test-crossplane.kubeconfig patch clusterpolicies.kyverno.io ${POLICY} \
    --type merge  -p '{"spec": {"validationFailureAction": "enforce"}}'
done
sleep 10
echo -e '### Done!\n'

echo '### Scale up assessment application to 1 replica'
kubectl --kubeconfig /var/tmp/test-crossplane.kubeconfig -n assessment \
  scale deployment assessment --replicas=1
sleep 10
echo -e '### Done!\n'

date
echo
echo '### End'
