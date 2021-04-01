#!/bin/env bash

source ./hack/common.sh

nuke_cluster() {
    name=$1
    
    minikube stop  -p "$name"
    minikube delete -p "$name"
    rm -rf "${ROOTDIR}/$name"-kubeconfig
}


#TODO:  check hub cluster is there
for c in  $(kubectl --context=hub get managedclusters -o=jsonpath='{.items[?(@.metadata.name!="hub")].metadata.name}')
do
    nuke_cluster "$c"
done

nuke_cluster hub

