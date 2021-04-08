#!/bin/env bash

source ./hack/common.sh

SPOKENAME=${1:-cluster1}

tmp_deployment=$(mktemp -d -t ${SPOKENAME}-spoke-XXX)
cp -r deployment/klusterlet ${tmp_deployment}

grep -rl managed-cluster ${tmp_deployment}/klusterlet | xargs sed -i "s/managed-cluster/${SPOKENAME}/g"

echo "Going to create managed cluster ${SPOKENAME}"

#kind create cluster --name ${SPOKENAME}
minikube start --driver=kvm2 -p ${SPOKENAME}

#TODO check whether hub exists

#kind get kubeconfig --name ${SPOKENAME} --internal > ${ROOTDIR}/${SPOKENAME}-kubeconfig

operator-sdk olm install 

wait_until "namespace_active ${SPOKENAME} olm"
wait_until "namespace_active ${SPOKENAME} operators"


kubectl --context=${SPOKENAME} create ns open-cluster-management
wait_until "namespace_active ${SPOKENAME} open-cluster-management"


#sed -e "s,quay.io/open-cluster-management/registration-operator:latest,quay.io/open-cluster-management/registration-operator:latest," -i deploy/klusterlet/olm-catalog/klusterlet/manifests/klusterlet.clusterserviceversion.yaml


kubectl --context=${SPOKENAME} create ns open-cluster-management-agent
wait_until "namespace_active ${SPOKENAME} open-cluster-management-agent"



operator-sdk run packagemanifests ${tmp_deployment}/klusterlet/olm-catalog/klusterlet/ --namespace open-cluster-management --version 0.3.0 --install-mode OwnNamespace --timeout=10m

wait_until "deployment_up_and_running ${SPOKENAME} open-cluster-management klusterlet"
wait_until "deployment_up_and_running ${SPOKENAME} open-cluster-management klusterlet-registry-server"



#TODO: checks whether hub-kubeconfig file is present
kubectl --context=${SPOKENAME} create secret generic bootstrap-hub-kubeconfig --from-file=kubeconfig="${HUB_KUBECONFIG}" -n open-cluster-management-agent
#TODO checks secret....


kubectl apply -f ${tmp_deployment}/klusterlet/config/samples/operator_open-cluster-management_klusterlets.cr.yaml
wait_until "deployment_up_and_running ${SPOKENAME} open-cluster-management-agent klusterlet-registration-agent" 5 30


#TODO check $SPOKENAME is not accepted using regex 
accepted=$(kubectl --context=hub get managedclusters  -o=jsonpath="{.items[?(@.metadata.name=='$SPOKENAME')].spec.hubAcceptsClient}")


wait_until "csr_submitted hub $SPOKENAME" 1 60
csrname=$(kubectl --context=hub get csr -o=jsonpath="{.items[?(@.metadata.generateName=='$SPOKENAME-')].metadata.name}")

kubectl --context=hub  certificate approve  $csrname 
#TOTO wait_until certificate approved
sleep 10

kubectl --context=hub  patch managedcluster  ${SPOKENAME} -p='{"spec":{"hubAcceptsClient":true}}' --type=merge

wait_until "deployment_up_and_running ${SPOKENAME} open-cluster-management-agent klusterlet-work-agent"

rm  -rf manifest-work.yaml

(
cat <<EOF
apiVersion: work.open-cluster-management.io/v1
kind: ManifestWork
metadata:
  name: mw-01
  namespace: ${SPOKENAME}
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
) >> manifest-work.yaml

kubectl --context=hub  apply -f manifest-work.yaml
# TODO check manifest-work is created in context hub

wait_until "pod_up_and_running ${SPOKENAME} default hello" 10 120

kubectl --context=${SPOKENAME} -n default logs hello

rm -rf ${tmp_deployment}
