#!/bin/env bash

################################################################################
# Check static prerequisites
################################################################################
command -v kubectl >/dev/null 2>&1 || { echo >&2 "can't find kubectl.  Aborting."; exit 1; }
command -v cfssl >/dev/null 2>&1 || { echo >&2 "can't find cfssl. Aborting. You can download from https://pkg.cfssl.org/ (Mac OS: brew install cfssl)"; exit 1; }
command -v cfssljson >/dev/null 2>&1 || { echo >&2 "can't find cfssljson. Aborting. You can download from https://pkg.cfssl.org/ (Mac OS: brew install cfssljson)"; exit 1; }

################################################################################
# Default setting
################################################################################
readonly DEFAULT_HUBNAME=hub
readonly DEFAULT_MANAGEDNAME=cluster1
readonly DEFAULT_CONTAINER_ENGINE=podman
case  $(uname -s) in
    Linux*)
        readonly DEFAULT_CLUSTER_PROVIDER=minikube
	    ;;
	Darwin*)
        readonly DEFAULT_CLUSTER_PROVIDER=kind
        ;;
	*)
	    echo_red "Unsupported platform ${unameOut}"
	    exit 1
	    ;;
esac




################################################################################
# Checks prerequisites after option selection
################################################################################
check_prerequisites() {
   if [ "${CLUSTER_PROVIDER}" == "minikube" ]; then
    command -v minikube >/dev/null 2>&1 || { echo >&2 "can't find minikube. Aborting."; exit 1; }
    command -v virsh > /dev/null 2>&1 || { echo >&2 "can't find virsh.  Aborting."; exit 1; }
fi

if [ "${CLUSTER_PROVIDER}" == "kind" ]; then
    command -v kind >/dev/null 2>&1 || { echo >&2 "can't find kind. Aborting."; exit 1; }
fi
}


validate_config() {
    unameOut="$(uname -s)"
    case "${unameOut}" in
	Linux*) # We should support all the combinations
	;;
	Darwin*)
		echo_red "On Mac only kind is supported. Try with '-p kind -e docker' or '-p kind -e podman'"
		exit 1
	    ;;
	*)
	    echo_red "Unsupported platform ${unameOut}"
	    exit 1
	    ;;
    esac
}


get_client_context_from_cluster_name()  {
    local clustername=$1
     case "${CLUSTER_PROVIDER}" in
	'minikube')
	    echo ${clustername}
	    ;;
	'kind')
	    echo kind-${clustername}
	    ;;
    esac
}


deploy_image_to_cluster() {
    local image=$1
    local clustername=$2
    echo_green "Deploying $image to $clustername"
    case "${CLUSTER_PROVIDER}" in
	'minikube')
        tmpfile=$(mktemp --suffix .tar)
        podman save "$image" > "$tmpfile"
	    minikube -p $clustername image load "$tmpfile"
        rm -f "$tmpfile"
	    ;;
	'kind')
        if [[ "${CONTAINER_ENGINE}" == "podman" ]];
        then
            echo_green "Workaround for kind on podman, see https://github.com/kubernetes-sigs/kind/issues/2027"
            tmpfile=$(mktemp --suffix .tar)
            podman save "$image" > "$tmpfile"
            kind load image-archive "$tmpfile" --name "$clustername"
            rm -f "$tmpfile"
        else
	        kind load docker-image "$image" --name "$clustername"
        fi
	    ;;
    esac
}

generate_kubeconfig_for_cluster() {
    local clustername=$1
    local kubeconfig=$(mktemp)
    case "${CLUSTER_PROVIDER}" in
    'minikube')
        kubectl --context=${clustername} config view --flatten --minify > ${kubeconfig}
        ;;
    'kind')
	    kind get kubeconfig --name ${clustername} --internal > ${kubeconfig}
	    ;;
    esac
    echo ${kubeconfig}
}


get_all_clusters() {
    case "${CLUSTER_PROVIDER}" in
	'minikube')
	    echo $(minikube profile list -o json | jq -r .valid[].Name)
	    ;;
	'kind')
	    echo $(kind get clusters)
	    ;;
    esac
}


deploy_images_to_cluster() {
   local clustername=$1
   images=$(${CONTAINER_ENGINE} images | grep localhost:5000/open-cluster-management | awk '{printf "%s:%s\n", $1, $2}')
   for image in ${images}
    do deploy_image_to_cluster ${image} ${clustername}
   done
}

echo_red() {
  printf "\033[0;31m%s\033[0m" "$1"
}

echo_yellow() {
  printf "\033[1;33m%s\033[0m\n" "$1"
}

echo_green() {
  printf "\033[0;32m%s\033[0m\n" "$1"
}



ROOTDIR=$(git rev-parse --show-toplevel)




build_images() {
    mkdir -p ${ROOTDIR}/repos
    # registration
    cd ${ROOTDIR}/repos
    git clone https://github.com/open-cluster-management-io/registration.git
    cd registration
    buildah build -t localhost:5000/open-cluster-management/registration
    # placement
    cd ${ROOTDIR}/repos
    git clone https://github.com/open-cluster-management-io/placement.git
    buildah build -t localhost:5000/open-cluster-management/placement
    # work
    cd ${ROOTDIR}/repos
    git clone https://github.com/open-cluster-management-io/work.git
    cd work
    buildah build -t localhost:5000/open-cluster-management/work
    # registration-operator
    cd ${ROOTDIR}/repos
    git clone https://github.com/open-cluster-management-io/registration-operator.git
    cd ${ROOTDIR}/repos/registration-operator
    buildah build -t localhost:5000/open-cluster-management/registration-operator
    cd ${ROOTDIR}/repos/registration-operator/deploy/cluster-manager/config/operator
    kustomize edit set image localhost:5000/open-cluster-management/registration-operator:latest
    cd ${ROOTDIR}/repos/registration-operator/deploy/cluster-manager/config/klusterlet
    kustomize edit set image localhost:5000/open-cluster-management/registration-operator:latest
    cd ${ROOTDIR}
}

export HUB_KUBECONFIG=${ROOTDIR}/hub-kubeconfig


wait_until() {
  local script=$1
  local wait=${2:-1}
  local timeout=${3:-10}
  local i

  script_pretty_name=${script//_/ }
  times=$(echo "($(bc <<< "scale=2;$timeout/$wait")+0.5)/1" | bc)
  for i in $(seq 1 "${times}"); do
      local out=$($script)
      if [ "$out" == "0" ]; then
	  echo_green "${script_pretty_name}: OK"
      return 0
      fi
      echo_yellow "${script_pretty_name}: Waiting...$wait second(s)"
      sleep $wait
  done
  echo_red "${script_pretty_name}: ERROR"
  return 1
}


cluster_provider_is_up() {
    return 1
}


namespace_active() {
  kubecontext=$1
  namespace=$2

  rv="1"
  phase=$(kubectl --context "${kubecontext}" get ns "$namespace" -o jsonpath='{.status.phase}' 2> /dev/null)
  if [ "$phase" == "Active" ]; then
      rv="0"
  fi

  echo ${rv}

}


csr_submitted() {
    kubecontext=$1
    clustername=$2

    rv="0"
    found=$(kubectl --context=${kubecontext} get csr -o=jsonpath="{.items[?(@.metadata.generateName=='${clustername}-')].metadata.name}")
    if [  -z "$found" ]; then
	    rv="1"
    fi

    echo ${rv}
}


pod_up_and_running() {
  kubecontext=$1
  namespace=$2
  pod=$3

  rv="1"
  phase=$(kubectl --context "${kubecontext}" get pod  $pod  -n "$namespace" -o jsonpath='{.status.phase}' 2> /dev/null)
  if [ "$phase" == "Running" ] || [ "$phase" == "Succeeded" ]; then
    rv="0"
  fi

  echo ${rv}
}

deployment_up_and_running() {
    kubecontext=$1
    namespace=$2
    deployment=$3


    rv="1"
    zero=0
    #TODO troubleshoot --ignore-not-found
    desiredReplicas=$(kubectl --context ${kubecontext}  get deployment ${deployment} -n ${namespace} -ojsonpath="{.spec.replicas}" --ignore-not-found)
    readyReplicas=$(kubectl --context ${kubecontext}  get deployment ${deployment} -n ${namespace} -ojsonpath="{.status.readyReplicas}" --ignore-not-found)
    if [ "${desiredReplicas}" == "${readyReplicas}" ] && [ "${desiredReplicas}" != "${zero}" ]; then
	    rv="0"
    fi

    echo ${rv}
}

minikube_up_and_running() {
    local profile=$1
    apiStatus=$(minikube -p $profile status --format='{{ .APIServer }}')
  hostStatus=$(minikube -p $profile status --format='{{ .Host }}')
  if [[ "${apiStatus}" == "Running" && "${hostStatus}" == "Running" ]]
  then
    echo "0"
    return
  fi
  echo "1"
}


minikube_stopped() {
  local profile=$1
  apiStatus=$(minikube -p $profile status --format='{{ .APIServer }}')
  hostStatus=$(minikube -p $profile status --format='{{ .Host }}')
  if [[ "${apiStatus}" == "Stopped" && "${hostStatus}" == "Stopped" ]]
  then
    echo "0"
    return
  fi
  echo "1"
}


create_cluster() {
    local clustername=$1
    case "${CLUSTER_PROVIDER}" in
	'minikube')
	    minikube start --container-runtime=cri-o --driver=kvm2 -p ${clustername} #For the moment only cri-o and kvm2 is supported
        wait_until "minikube_up_and_running ${clustername}"
        virnet=$(mktemp -t "${clustername}XXX-net.xml")
        virsh net-dumpxml "mk-${clustername}"  >"${virnet}";
        minikube stop  -p "${clustername}"
        wait_until "minikube_stopped ${clustername}"
        virsh net-destroy "mk-${clustername}";
        sed -i  "/uuid/a \  <forward mode='route'/\>" ${virnet}
        virsh net-define "${virnet}";
        virsh net-start "mk-${clustername}";
        echo "Waiting 10 seconds..."
        sleep 10 #TODO replace with wait-until
        minikube start -p "${clustername}";
        wait_until "minikube_up_and_running ${clustername}"
      ;;
	'kind')
	    kind create cluster --name  ${clustername} 
	    ;;
    esac
}

delete_cluster() {
    local clustername=$1
    case "${CLUSTER_PROVIDER}" in
	'minikube')
	    minikube delete -p  ${clustername}
	    ;;
	'kind')
	    kind delete cluster --name  ${clustername}
	    ;;
    esac
}


# creates a client CA, args are sudo, dest-dir, ca-id, purpose
# purpose is dropped in after "key encipherment", you usually want
# '"client auth"'
# '"server auth"'
# '"client auth","server auth"'
function kube::util::create_signing_certkey {
    local sudo=$1
    local dest_dir=$2
    local id=$3
    local purpose=$4
    # Create client ca
    ${sudo} /bin/bash -e <<EOF
    rm -f "${dest_dir}/${id}-ca.crt" "${dest_dir}/${id}-ca.key"
    openssl req -x509 -sha256 -new -nodes -days 365 -newkey rsa:2048 -keyout "${dest_dir}/${id}-ca.key" -out "${dest_dir}/${id}-ca.crt" -subj "/C=xx/ST=x/L=x/O=x/OU=x/CN=ca/emailAddress=x/"
    echo '{"signing":{"default":{"expiry":"43800h","usages":["signing","key encipherment",${purpose}]}}}' > "${dest_dir}/${id}-ca-config.json"
EOF
}

# signs a serving certificate: args are sudo, dest-dir, ca, filename (roughly), subject, hosts...
function kube::util::create_serving_certkey {
    local sudo=$1
    local dest_dir=$2
    local ca=$3
    local id=$4
    local cn=${5:-$4}
    local hosts=""
    local SEP=""
    shift 5
    while [ -n "${1:-}" ]; do
        hosts+="${SEP}\"$1\""
        SEP=","
        shift 1
    done
    ${sudo} /bin/bash -e <<EOF
    cd ${dest_dir}
    echo '{"CN":"${cn}","hosts":[${hosts}],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -ca=${ca}.crt -ca-key=${ca}.key -config=${ca}-config.json - | cfssljson -bare serving-${id}
    mv "serving-${id}-key.pem" "serving-${id}.key"
    mv "serving-${id}.pem" "serving-${id}.crt"
    rm -f "serving-${id}.csr"
EOF
}
