#!/bin/bash

echo '### Start'
date
echo

echo '### Initiate managed cluster deletion'
kubectl delete -f controlplane/resources/civo/cluster.yaml
echo -e '### Done!\n'

echo '### Wait for managed cluster to be deleted'
sleep 30
while true; do
  kubectl get civokubernetes.cluster.civo.crossplane.io test-crossplane --no-headers 2>&1 | \
    egrep '"test-crossplane" not found' >/dev/null
    if [[ $? -eq 0 ]]; then break; fi
  echo 'Still waiting...'
  sleep 30
done
echo -e '### Done!\n'

echo '### Remove kubeconfig for managed cluster'
rm -f /var/tmp/test-crossplane.kubeconfig
echo -e '### Done!\n'

echo '### Delete kind cluster'
kind delete cluster -n test-crossplane
echo -e '### Done!\n'

date
echo '### End'
