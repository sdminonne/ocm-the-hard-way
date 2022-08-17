#!/usr/bin/env bash

ROOTDIR=$(git rev-parse --show-toplevel)
source "${ROOTDIR}/hack/common.sh"

################################################################################
# Help: displays usage
################################################################################
Help()
{
 # Display Help
 echo "$0 deploys OCM managed cluster "
 echo
 echo "Syntax: deploy_hub [ -b|e|h|n|p ]"
 echo "options:"
 echo "-b <hub name> Specify the name of the cluster, Default: \"${DEFAULT_HUBNAME}\""
 echo "-e <docker> Specify the container engine. Default : \"${DEFAULT_CONTAINER_ENGINE}\""
 echo "-h Print this help."
 echo "-n <cluster name> Specify the name of the cluster, Default: \"${DEFAULT_MANAGEDNAME}\""
 echo "-p <kind|minikube> Specify the cluster provider: kind or minikube. Default: \"${DEFAULT_CLUSTER_PROVIDER}\""
 echo
 echo "Exmples:"
 echo "./hack/deploy_managed.sh -b hub -n cluster-foo -p minikube"
}


CONTAINER_ENGINE=${DEFAULT_CONTAINER_ENGINE}
CLUSTER_PROVIDER=${DEFAULT_CLUSTER_PROVIDER}
HUBNAME=${DEFAULT_HUBNAME}
MANAGEDNAME=${DEFAULT_MANAGEDNAME}

###############################################################
# Main program                                                #
###############################################################
# Get the options
while getopts "b:e:hn:p:" arg; do
 case $arg in
     b) HUBNAME=${OPTARG}
	;;
     e) CONTAINER_ENGINE=${OPTARG}
	;;
     h)	 Help
	 exit
	 ;;
     n) MANAGEDNAME=${OPTARG}
	;;
     p) CLUSTER_PROVIDER=${OPTARG}
	;;
     *)  Help
	 exit
         ;;
 esac
done
shift $((OPTIND-1))

echo_green "Managed cluster name -> ${MANAGEDNAME}"
echo_green "Hub cluster name     -> ${HUBNAME}"
echo_green "Container engine     -> ${CONTAINER_ENGINE}"
echo_green "Cluster provider     -> ${CLUSTER_PROVIDER=}"

build_images


#TODO: we should check hubname is a real working cluster
create_cluster ${MANAGEDNAME}

deploy_images_to_cluster ${MANAGEDNAME}

IMAGE_REGISTRY="localhost:5000"
IMAGE_TAG="latest"
MANAGEDCONTEXT=$(get_client_context_from_cluster_name ${MANAGEDNAME})
HUBCONTEXT=$(get_client_context_from_cluster_name ${HUBNAME})

echo_green "Managed context -> ${MANAGEDCONTEXT}"
echo_green "Hub context     -> ${HUBCONTEXT}"

kubectl --context hub config view --flatten --minify > hub-kubeconfig

export MANAGED_CLUSTER_NAME=${MANAGEDNAME}
export MANAGEDCONTEXT
export HUBCONTEXT

cd repos/registration-operator/deploy/klusterlet/config && kustomize edit set image localhost:5000/open-cluster-management/registration-operator:latest && cd - || exit
cd repos/registration-operator && make deploy-spoke && cd - || exit

wait_until "namespace_active ${MANAGEDCONTEXT} open-cluster-management" 5 60
wait_until "deployment_up_and_running ${MANAGEDCONTEXT} open-cluster-management klusterlet" 10 60

wait_until "namespace_active ${MANAGEDCONTEXT} open-cluster-management-agent" 5 60
wait_until "deployment_up_and_running ${MANAGEDCONTEXT} open-cluster-management-agent klusterlet-registration-agent" 10 60

wait_until "csr_submitted ${HUBCONTEXT} ${MANAGEDNAME}" 5 60

csrname=$(kubectl --context=${HUBCONTEXT} get csr -o=jsonpath="{.items[?(@.metadata.generateName=='${MANAGEDNAME}-')].metadata.name}")
kubectl --context=${HUBCONTEXT} certificate approve  $csrname
kubectl  --context=${HUBCONTEXT} patch managedcluster ${MANAGEDNAME} -p='{"spec":{"hubAcceptsClient":true}}' --type=merge

cd repos/work && make deploy && cd - #|| { echo_red >&2 "Unable to deploy work. Aborting"; exit 1; }

wait_until "deployment_up_and_running ${MANAGEDCONTEXT} open-cluster-management-agent klusterlet-work-agent" 10 60

cat <<EOF | kubectl --context=${HUBCONTEXT} apply -f -
apiVersion: work.open-cluster-management.io/v1
kind: ManifestWork
metadata:
  name: mw-01
  namespace: ${MANAGEDNAME}
spec:
  workload:
    manifests:
    - apiVersion: v1
      kind: Pod
      metadata:
        name: hello
        namespace: default
      spec:
        containers:
        - name: hello
          image: busybox
          command: ['sh', '-c', 'echo "Hello, Kubernetes!" && sleep 3600']
        restartPolicy: OnFailure
EOF

wait_until "pod_up_and_running ${MANAGEDCONTEXT} default hello" 10 120
kubectl --context=${MANAGEDCONTEXT} -n default logs hello
