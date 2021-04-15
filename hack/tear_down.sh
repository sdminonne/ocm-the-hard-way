#!/usr/bin/env bash

source ./hack/common.sh

################################################################################
# Help: displays usage
################################################################################
bold=$(tput bold)
normal=$(tput sgr0)
Help()
{
 # Display Help
 echo "$0 removes the specified hub and all its managed clusters"
 echo
 echo "Syntax: deploy_hub [ -h|n|p ]" 
 echo "options:"
 echo "-A remove ${bold}all${normal} clusters for the specified cluster provider. Default: False (Obviously)."
 echo "-h Print this help."
 echo "-n <hubname> Specify the name of the hub, Default: ${DEFAULT_HUBNAME}"
 echo "-p <kind|minikube> Specify the cluster provider: kind or minikube. Default ${DEFAULT_CLUSTER_PROVIDER}"
 echo
}

LOCAL_CLUSTER_PROVIDER=${DEFAULT_CLUSTER_PROVIDER}
HUBNAME=${DEFAULT_HUBNAME}
ALL='false'

###############################################################
# Main program                                                #
###############################################################
while getopts "Ahn:p:" arg; do
    case $arg in
	A) ALL='true'
	    ;;
	
	h) # display Usage
	    Help
	    exit
	    ;;
	n) HUBNAME=${OPTARG}
	   ;;
	p) LOCAL_CLUSTER_PROVIDER=${OPTARG}
	   ;;
	*) 
	    Help
	    exit
            ;;
    esac
done
shift $((OPTIND-1))
	      
echo_green "Hub cluster name     -> ${HUBNAME}"
echo_green "Cluster provider     -> ${LOCAL_CLUSTER_PROVIDER=}"

clusters=""
if [[ "${ALL}" = "true" ]];
then
    echo_yellow "Removing all clusters for ${LOCAL_CLUSTER_PROVIDER=}"
    clusters=$(get_all_clusters);
else
    clusters=$(kubectl --context=$(get_client_context_from_cluster_name ${HUBNAME} ) get managedclusters -o=jsonpath='{.items[?(@.metadata.name!="hub")].metadata.name}')
    delete_cluster ${HUBNAME}
fi


for cluster in ${clusters};
do delete_cluster ${cluster}
done

