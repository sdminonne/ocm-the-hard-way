#!/usr/bin/env bash

source ./hack/common.sh

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
 echo "-b <hub name> Specify the name of the cluster, Default: ${DEFAULT_HUBNAME}"
 echo "-e <docker> Specify the container engine. Default : ${DEFAULT_CONTAINER_ENGINE}"
 echo "-h Print this help."
 echo "-n <cluster name> Specify the name of the cluster, Default: ${DEFAULT_MANAGEDNAME}"
 echo "-p <kind|minikube> Specify the cluster provider: kind or minikube. Default ${DEFAULT_CLUSTER_PROVIDER}"
 echo
 echo "Exmples:"
 echo "./hack/deploy_managed.sh -b hub -n cluster-foo -p minikube"
}


LOCAL_CONTAINER_ENGINE=${DEFAULT_CONTAINER_ENGINE}
LOCAL_CLUSTER_PROVIDER=${DEFAULT_CLUSTER_PROVIDER}
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
     e) LOCAL_CONTAINER_ENGINE=${OPTARG}
	;;
     h)	 Help
	 exit
	 ;;
     n) MANAGEDNAME=${OPTARG}
	;;
     p) LOCAL_CLUSTER_PROVIDER=${OPTARG}
	;;
     *)  Help
	 exit
         ;;
 esac
done
shift $((OPTIND-1))

echo_green "Managed cluster name -> ${MANAGEDNAME}"
echo_green "Hub cluster name     -> ${HUBNAME}"
echo_green "Container engine     -> ${LOCAL_CONTAINER_ENGINE}"
echo_green "Cluster provider     -> ${LOCAL_CLUSTER_PROVIDER=}"

#TODO: we should check hubname is a real working cluster

create_cluster ${MANAGEDNAME}

deploy_images_to_cluster ${MANAGEDNAME}

MANAGEDCONTEXT=$(get_client_context_from_cluster_name ${MANAGEDNAME})
HUBCONTEXT=$(get_client_context_from_cluster_name ${HUBNAME})

kubectl --context=${MANAGEDCONTEXT} apply -f  ./artifacts/managed/crds/

#TODO checks CRDs
#appliedmanifestworks.work.open-cluster-management.io
#klusterlets.operator.open-cluster-management.io


kubectl --context=${MANAGEDCONTEXT} create ns open-cluster-management
wait_until "namespace_active ${MANAGEDCONTEXT} open-cluster-management" 5 60

kubectl --context=${MANAGEDCONTEXT} apply -f artifacts/managed/open-cluster-management/klusterlet-sa.yaml
kubectl --context=${MANAGEDCONTEXT} apply -f artifacts/managed/clusterroles/open-cluster-management-klusterlet.yaml 
kubectl --context=${MANAGEDCONTEXT} apply -f artifacts/managed/clusterrolebindings/open-cluster-management-klusterlet.yaml
kubectl --context=${MANAGEDCONTEXT} apply -f artifacts/managed/open-cluster-management/klusterlet-deployment.yaml
wait_until "deployment_up_and_running ${MANAGEDCONTEXT} open-cluster-management klusterlet" 10 60



kubectl --context=${MANAGEDCONTEXT} create ns open-cluster-management-agent
wait_until "namespace_active ${MANAGEDCONTEXT} open-cluster-management-agent" 5 60

#tmpkubeconfig=$(mktemp)
#kubectl --context=${HUBCONTEXT} config view --flatten --minify > ${tmpkubeconfig}
tmpkubeconfig=$(generate_kubeconfig_for_cluster ${HUBNAME})
echo_green "Generated kubeconfig for secret ${tmpkubeconfig}"
kubectl --context=${MANAGEDCONTEXT} create secret generic bootstrap-hub-kubeconfig --from-file=kubeconfig="${tmpkubeconfig}" -n open-cluster-management-agent


kubectl --context=${MANAGEDCONTEXT} apply -f  artifacts/managed/open-cluster-management-agent/klusterlet-registration-sa.yaml
kubectl --context=${MANAGEDCONTEXT} apply -f  artifacts/managed/clusterroles/open-cluster-management-agent-klusterlet-registration.yaml
kubectl --context=${MANAGEDCONTEXT} apply -f artifacts/managed/clusterrolebindings/open-cluster-management-agent-klusterlet-registration.yaml


cat artifacts/managed/open-cluster-management-agent/klusterlet-registration-agent-deployment-template.yaml | \
    sed "s/MANAGEDCLUSTERNAME/${MANAGEDNAME}/g" | \
    kubectl  --context=${MANAGEDCONTEXT} apply -f -
wait_until "deployment_up_and_running ${MANAGEDCONTEXT} open-cluster-management-agent klusterlet-registration-agent" 10 60


kubectl --context=${HUBCONTEXT} get managedclusters


cat <<EOF | kubectl --context=${MANAGEDCONTEXT} apply -f -
apiVersion: operator.open-cluster-management.io/v1
kind: Klusterlet
metadata:
  name: klusterlet
spec:
  registrationImagePullSpec: localhost:5000/open-cluster-management/registration:latest
  workImagePullSpec: localhost:5000/open-cluster-management/work:latest
  clusterName: ${MANAGEDNAME}
  namespace: open-cluster-management-agent
  externalServerURLs:
  - url: https://localhost
EOF


wait_until "csr_submitted ${HUBCONTEXT} ${MANAGEDNAME}" 5 60

csrname=$(kubectl --context=${HUBCONTEXT} get csr -o=jsonpath="{.items[?(@.metadata.generateName=='${MANAGEDNAME}-')].metadata.name}")
kubectl --context=${HUBCONTEXT} certificate approve  $csrname

# TOO replace with wait_until


kubectl --context=${HUBCONTEXT} get managedclusters


kubectl --context=${HUBCONTEXT} patch managedcluster  ${MANAGEDNAME} -p='{"spec":{"hubAcceptsClient":true}}' --type=merge

kubectl --context=${HUBCONTEXT} get managedclusters

kubectl --context=${MANAGEDCONTEXT} apply -f  artifacts/managed/open-cluster-management-agent/klusterlet-work-sa.yaml
kubectl --context=${MANAGEDCONTEXT} apply -f artifacts/managed/clusterroles/open-cluster-management-agent-klusterlet-work.yaml
kubectl --context=${MANAGEDCONTEXT} apply -f artifacts/managed/clusterrolebindings/open-cluster-management-agent-klusterlet-work.yaml


cat artifacts/managed/open-cluster-management-agent/klusterlet-work-agent-deployment-template.yaml | \
    sed "s/MANAGEDCLUSTERNAME/${MANAGEDNAME}/g" | \
    kubectl  --context=${MANAGEDCONTEXT} apply -f -

wait_until "deployment_up_and_running ${MANAGEDCONTEXT} open-cluster-management-agent klusterlet-work-agent" 5 30

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
