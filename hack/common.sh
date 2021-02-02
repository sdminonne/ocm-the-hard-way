#!/bin/env bash

command -v kubectl >/dev/null 2>&1 || { echo >&2 "can't find kubectl.  Aborting."; exit 1; }

command -v kind >/dev/null 2>&1 || { echo >&2 "can't find kind. Aborting."; exit 1; }

command -v curl >/dev/null 2>&1 || { echo >&2 "can't find curl. Aborting."; exit 1; }

command -v docker >/dev/null 2>&1 || { echo >&2 "can't find docker. Aborting. "; exit 1; }

docker run hello-world >/dev/null || { echo >&2 "cannot run docker. Aborting. "; exit 1; }


echo_red() {
  printf "\033[0;31m%s\033[0m" "$1"
}

echo_yellow() {
  printf "\033[1;33m%s\033[0m\n" "$1"
}

echo_green() {
  printf "\033[0;32m%s\033[0m\n" "$1"
}

id -Gn | grep -q docker  >/dev/null 2>&1  || { echo >&2 "Not in group docker. Aborting."; exit 1; }

ROOTDIR=$(git rev-parse --show-toplevel)

export HUB_KUBECONFIG=${ROOTDIR}/hub-kubeconfig


wait_until() {
  local script=$1
  local wait=${2:-.5}
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
      echo_yellow "${script_pretty_name}: Waiting..."
      sleep $wait
  done
  echo_red "${script_pretty_name}: ERROR"
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
    found=$(kubectl --context=kind-hub get csr -o=jsonpath="{.items[?(@.metadata.generateName=='$clustername-')].metadata.name}")
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
