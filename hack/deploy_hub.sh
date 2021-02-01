#!/bin/env bash

set -x

source ./hack/common.sh

#TODO check whether hub does not exist
# kind get clusters  | grep hub


kind create cluster --name hub

#TODO check whether hub exists
# kind get clusters  | grep hub


kind get kubeconfig --name hub --internal > ${HUB_KUBECONFIG}

operator-sdk olm install --version 0.16.1

wait_until "namespace_active kind-hub olm"
wait_until "deployment_up_and_running kind-hub olm catalog-operator"
wait_until "deployment_up_and_running kind-hub olm olm-operator"
wait_until "deployment_up_and_running kind-hub olm packageserver"

wait_until "namespace_active kind-hub operators"

kubectl --context=kind-hub create ns open-cluster-management
wait_until "namespace_active kind-hub open-cluster-management"


#mkdir -p munge-csv

#cp deploy/cluster-manager/olm-catalog/cluster-manager/manifests/cluster-manager.clusterserviceversion.yaml munge-csv/cluster-manager.clusterserviceversion.yaml.unmunged

#sed -e "s,quay.io/open-cluster-management/registration-operator:latest,quay.io/open-cluster-management/registration-operator:latest," -i deploy/cluster-manager/olm-catalog/cluster-manager/manifests/cluster-manager.clusterserviceversion.yaml

operator-sdk run packagemanifests deployment/cluster-manager/olm-catalog/cluster-manager/ --namespace open-cluster-management --version 0.3.0 --install-mode OwnNamespace --timeout=10m
wait_until "deployment_up_and_running kind-hub open-cluster-management cluster-manager"
wait_until "deployment_up_and_running kind-hub open-cluster-management cluster-manager-registry-server"

#sed -e "s,quay.io/open-cluster-management/registration,quay.io/open-cluster-management/registration:latest," deploy/cluster-manager/config/samples/operator_open-cluster-management_clustermanagers.cr.yaml | kubectl apply -f

kubectl apply -f deployment/cluster-manager/config/samples/operator_open-cluster-management_clustermanagers.cr.yaml 
wait_until "deployment_up_and_running kind-hub open-cluster-management-hub cluster-manager-registration-controller" 
wait_until "deployment_up_and_running kind-hub open-cluster-management-hub cluster-manager-work-webhook"



exit

