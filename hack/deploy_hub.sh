#!/usr/bin/env bash

source ./hack/common.sh

export HUBNAME=${HUBNAME:-hub}

if [ -z ${LOCAL_CONTAINER_ENGINE+x} ];then 
    echo "LOCAL_CONTAINER_ENGINE is unset"; 
    echo "Set 'LOCAL_CONTAINER_ENGINE'. Must be 'docker' on Mac OS."
    exit 1
else 
    echo "LOCAL_CONTAINER_ENGINE is set to '$LOCAL_CONTAINER_ENGINE'";
fi


create_cluster ${HUBNAME}

deploy_images_to_cluster ${HUBNAME}

HUBCONTEXT=$(get_client_context_from_cluster_name ${HUBNAME})
echo_green "HUB context -> ${HUBCONTEXT}"

kubectl --context=${HUBCONTEXT} apply -f https://raw.githubusercontent.com/open-cluster-management/api/main/cluster/v1/0000_00_clusters.open-cluster-management.io_managedclusters.crd.yaml
kubectl --context=${HUBCONTEXT} apply -f https://raw.githubusercontent.com/open-cluster-management/api/main/operator/v1/0000_01_operator.open-cluster-management.io_clustermanagers.crd.yaml

kubectl --context=${HUBCONTEXT} apply -f https://raw.githubusercontent.com/open-cluster-management/api/581cab55c7971e2f8428c1062ba7012885114e34/cluster/v1alpha1/0000_01_clusters.open-cluster-management.io_managedclustersetbindings.crd.yaml
kubectl --context=${HUBCONTEXT} apply -f https://raw.githubusercontent.com/open-cluster-management/api/581cab55c7971e2f8428c1062ba7012885114e34/cluster/v1alpha1/0000_00_clusters.open-cluster-management.io_managedclustersets.crd.yaml
kubectl --context=${HUBCONTEXT} apply -f https://raw.githubusercontent.com/open-cluster-management/api/main/work/v1/0000_00_work.open-cluster-management.io_manifestworks.crd.yaml
kubectl --context=${HUBCONTEXT} apply -f https://raw.githubusercontent.com/open-cluster-management/api/main/work/v1/0000_01_work.open-cluster-management.io_appliedmanifestworks.crd.yaml

#TODO check CRDs are correctly deployed

kubectl  --context=${HUBCONTEXT} create ns open-cluster-management
wait_until "namespace_active ${HUBCONTEXT} open-cluster-management"

kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/open-cluster-management/cluster-manager-sa.yaml
kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/clusterroles/cluster-manager-clusterrole.yaml
kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/clusterrolebindings//cluster-manager-clusterrolebinding.yaml
kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/open-cluster-management/cluster-manager-deployment.yaml
wait_until "deployment_up_and_running ${HUBCONTEXT} open-cluster-management cluster-manager" 5 60

kubectl --context=${HUBCONTEXT} create namespace open-cluster-management-hub
wait_until "namespace_active ${HUBCONTEXT} open-cluster-management-hub"

kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/open-cluster-management-hub/cluster-manager-registration-controller-sa.yaml
kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/open-cluster-management-hub/cluster-manager-work-webhook-sa.yaml
kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/open-cluster-management-hub/cluster-manager-registration-webhook-sa.yaml
kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/clusterroles/cluster-manager-registration-controller-clusterrole.yaml 
kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/clusterrolebindings/cluster-manager-registration-controller-clusterrolebinding.yaml 
kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/open-cluster-management-hub/cluster-manager-registration-controller-deployment.yaml
wait_until "deployment_up_and_running ${HUBCONTEXT} open-cluster-management-hub cluster-manager-registration-controller" 5 30


kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/clusterroles/cluster-manager-work-webhook-clusterrole.yaml
kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/clusterrolebindings/cluster-manager-work-webhook-clusterrolebinding.yaml

certsdir=$(mktemp -d)

kube::util::create_signing_certkey "" "${certsdir}" serving '"server auth"'

kube::util::create_serving_certkey "" "${certsdir}" "serving-ca" cluster-manager-work-webhook.open-cluster-management-hub.svc "cluster-manager-work-webhook.open-cluster-management-hub.svc" "cluster-manager-work-webhook.open-cluster-management-hub.svc"

KUBE_CA=$(kubectl --context=${HUBCONTEXT} config view --minify=true --flatten -o json | jq '.clusters[0].cluster."certificate-authority-data"' -r)
cat artifacts/hub/open-cluster-management-hub/cluster-manager-work-webhook-list-template.yaml | \
    sed "s/TLS_SERVING_CERT/$(base64 ${certsdir}/serving-cluster-manager-work-webhook.open-cluster-management-hub.svc.crt | tr -d '\n')/g" | \
    sed "s/TLS_SERVING_KEY/$(base64 ${certsdir}/serving-cluster-manager-work-webhook.open-cluster-management-hub.svc.key | tr -d '\n')/g" | \
    sed "s/SERVICE_SERVING_CERT_CA/$(base64 ${certsdir}/serving-ca.crt | tr -d '\n')/g" | \
    sed "s/KUBE_CA/${KUBE_CA}/g" | \
    kubectl  --context=${HUBCONTEXT}  apply -f -
wait_until "deployment_up_and_running ${HUBCONTEXT} open-cluster-management-hub cluster-manager-work-webhook" 5 30

kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/clusterroles/cluster-manager-registration-webhook-clusterrole.yaml 
kubectl --context=${HUBCONTEXT} apply -f artifacts/hub/clusterrolebindings/cluster-manager-registration-webhook-clusterrolebinding.yaml 

certsdir=$(mktemp -d)

kube::util::create_signing_certkey "" "${certsdir}" serving '"server auth"'

kube::util::create_serving_certkey "" "${certsdir}" "serving-ca" cluster-manager-registration-webhook.open-cluster-management-hub.svc "cluster-manager-registration-webhook.open-cluster-management-hub.svc" "cluster-manager-registration-webhook.open-cluster-management-hub.svc"

KUBE_CA=$(kubectl --context=${HUBCONTEXT} config view --minify=true --flatten -o json | jq '.clusters[0].cluster."certificate-authority-data"' -r)
cat artifacts/hub/open-cluster-management-hub/cluster-manager-registration-webhook-list.template.yaml | \
    sed "s/TLS_SERVING_CERT/$(base64 ${certsdir}/serving-cluster-manager-registration-webhook.open-cluster-management-hub.svc.crt | tr -d '\n')/g" | \
    sed "s/TLS_SERVING_KEY/$(base64 ${certsdir}/serving-cluster-manager-registration-webhook.open-cluster-management-hub.svc.key | tr -d '\n')/g" | \
    sed "s/SERVICE_SERVING_CERT_CA/$(base64 ${certsdir}/serving-ca.crt | tr -d '\n')/g" | \
    sed "s/KUBE_CA/${KUBE_CA}/g" | \
    kubectl  --context=${HUBCONTEXT}  apply -f -


wait_until "deployment_up_and_running ${HUBCONTEXT} open-cluster-management-hub cluster-manager-registration-webhook" 5 30

echo_green "Hub deployed"

exit

