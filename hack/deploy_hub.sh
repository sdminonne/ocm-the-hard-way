#!/usr/bin/env bash

ROOTDIR=$(git rev-parse --show-toplevel)

source "${ROOTDIR}/hack/common.sh"

################################################################################
# Help: displays usage
################################################################################
Help()
{
 # Display Help
 echo "$0 deploys OCM hub "
 echo
 echo "Syntax: deploy_hub [ -e|h|n|p ]"
 echo "options:"
 echo "-e <podman> Specify the container engine. Default: \"${DEFAULT_CONTAINER_ENGINE}\""
 echo "-h Print this help."
 echo "-n <hubname> Specify the name of the hub, Default: \"${DEFAULT_HUBNAME}\""
 echo "-p <kind|minikube> Specify the cluster provider: kind or minikube. Default \"${DEFAULT_CLUSTER_PROVIDER}"\"
 echo
}

CONTAINER_ENGINE=${DEFAULT_CONTAINER_ENGINE}
CLUSTER_PROVIDER=${DEFAULT_CLUSTER_PROVIDER}
HUBNAME=${DEFAULT_HUBNAME}

###############################################################
# Main program                                                #
###############################################################
while getopts "e:hn:p:" arg; do
 case $arg in
     h) # display Usage
	 Help
	 exit
	 ;;
     n) HUBNAME=${OPTARG}
        ;;
     e) CONTAINER_ENGINE=${OPTARG}
	;;
     p) CLUSTER_PROVIDER=${OPTARG}
	;;
     *)
         Help
	 exit
         ;;
 esac
done
shift $((OPTIND-1))


validate_config

echo_green "Hub name         -> ${HUBNAME}"
echo_green "Container engine -> ${CONTAINER_ENGINE}"
echo_green "Cluster provider -> ${CLUSTER_PROVIDER=}"

#TODO double check whether HUBNAME exists

build_images

create_cluster ${HUBNAME}

deploy_images_to_cluster ${HUBNAME}

HUBCONTEXT=$(get_client_context_from_cluster_name ${HUBNAME})
echo_green "HUB context -> ${HUBCONTEXT}"

kubectl  --context=${HUBCONTEXT} create ns open-cluster-management
wait_until "namespace_active ${HUBCONTEXT} open-cluster-management"

kubectl  --context=${HUBCONTEXT} create ns open-cluster-management-hub
wait_until "namespace_active ${HUBCONTEXT} open-cluster-management-hub"


kubectl config use-context ${HUBCONTEXT}
cd ${ROOTDIR}/repos/registration-operator && make deploy-hub || { echo_red >&2 "Cannot deploy registration operator for hub."; exit 1; }

wait_until "deployment_up_and_running ${HUBCONTEXT} open-cluster-management-hub cluster-manager-work-webhook" 10 60
wait_until "deployment_up_and_running ${HUBCONTEXT} open-cluster-management-hub cluster-manager-registration-webhook" 10 60

echo_green "Hub deployed"

exit
