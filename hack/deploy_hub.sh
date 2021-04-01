#!/bin/env bash

source ./hack/common.sh

minikube start --driver=kvm2   -p hub

KUBECONFIG=${HUB_KUBECONFIG} minikube update-context -p hub

#kind create cluster --name hub

#TODO check whether hub exists
# kind get clusters  | grep hub

#kind get kubeconfig --name hub --internal > "${HUB_KUBECONFIG}"
operator-sdk olm install --version 0.16.1

 wait_until "namespace_active hub olm"
 wait_until "deployment_up_and_running hub olm catalog-operator"
 wait_until "deployment_up_and_running hub olm olm-operator"
 wait_until "deployment_up_and_running hub olm packageserver"

 wait_until "namespace_active hub operators"

 kubectl create ns open-cluster-management
 wait_until "namespace_active hub open-cluster-management"


 operator-sdk run packagemanifests deployment/cluster-manager/olm-catalog/cluster-manager/ --namespace open-cluster-management --version 0.3.0 --install-mode OwnNamespace --timeout=10m
 wait_until "deployment_up_and_running hub open-cluster-management cluster-manager"
 wait_until "deployment_up_and_running hub open-cluster-management cluster-manager-registry-server"

 kubectl apply -f deployment/cluster-manager/config/samples/operator_open-cluster-management_clustermanagers.cr.yaml 
 wait_until "deployment_up_and_running hub open-cluster-management-hub cluster-manager-registration-controller" 
 wait_until "deployment_up_and_running hub open-cluster-management-hub cluster-manager-work-webhook"

echo_green "Hub deployed"

exit

