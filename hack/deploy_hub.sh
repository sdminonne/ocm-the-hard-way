#!/bin/env bash

source ./hack/common.sh

kind create cluster --name hub

#TODO check whether hub exists
# kind get clusters  | grep hub


kind get kubeconfig --name hub --internal > "${HUB_KUBECONFIG}"

operator-sdk olm install --version 0.16.1

wait_until "namespace_active kind-hub olm"
wait_until "deployment_up_and_running kind-hub olm catalog-operator"
wait_until "deployment_up_and_running kind-hub olm olm-operator"
wait_until "deployment_up_and_running kind-hub olm packageserver"

wait_until "namespace_active kind-hub operators"

kubectl --context=kind-hub create ns open-cluster-management
wait_until "namespace_active kind-hub open-cluster-management"


operator-sdk run packagemanifests deployment/cluster-manager/olm-catalog/cluster-manager/ --namespace open-cluster-management --version 0.3.0 --install-mode OwnNamespace --timeout=10m
wait_until "deployment_up_and_running kind-hub open-cluster-management cluster-manager"
wait_until "deployment_up_and_running kind-hub open-cluster-management cluster-manager-registry-server"

kubectl apply -f deployment/cluster-manager/config/samples/operator_open-cluster-management_clustermanagers.cr.yaml 
wait_until "deployment_up_and_running kind-hub open-cluster-management-hub cluster-manager-registration-controller" 
wait_until "deployment_up_and_running kind-hub open-cluster-management-hub cluster-manager-work-webhook"

echo_green "Hub deployed"

exit

