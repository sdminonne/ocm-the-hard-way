#!/bin/env bash

source ./hack/common.sh

#TODO:  check hub cluster is there

for c in  $(kubectl --context=$(get_client_context_from_cluster_name hub) get managedclusters -o=jsonpath='{.items[?(@.metadata.name!="hub")].metadata.name}')
do
    delete_cluster "$c"
done

delete_cluster hub

