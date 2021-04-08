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
    found=$(kubectl --context=hub get csr -o=jsonpath="{.items[?(@.metadata.generateName=='$clustername-')].metadata.name}")
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



function generate_certificates() {
#Refer to documentation (for example https://www.openssl.org/docs/manmaster/man5/x509v3_config.html or https://www.phildev.net/ssl/opensslconf.html )

CN=ocm-the-hard-way
ROOT_CA_KEY=ca.key
ROOT_CA_CERT=ca.crt

cat > ca.cfg<<EOF
[ req ]
default_bits       = 4096
default_md         = sha256
default_keyfile    = domain.com.key
prompt             = no
encrypt_key        = no
distinguished_name = req_distinguished_name
x509_extensions		= v3_ca
[ req_distinguished_name ]
commonName             = ${CN}
[ v3_ca ]
basicConstraints = critical, CA:true
keyUsage = critical, keyCertSign, digitalSignature, keyEncipherment
[ v3_req ]
# PKIX complaint
subjectAltName=email:move
EOF

echo "Generate ${ROOT_CA_KEY} and ${ROOT_CA_CERT}"
openssl req -config ca.cfg -newkey rsa:2048 -nodes -keyout ${ROOT_CA_KEY} -x509 -days 36500 -out ${ROOT_CA_CERT}

openssl genrsa -out tls.key 2048

cat > tls.cfg <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = kubernetes.default.svc
[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage=serverAuth
#subjectAltName = @alt_names
EOF

SERVER_CRT=tls.crt
SERVER_KEY=tls.key

openssl req -new -key ${SERVER_KEY} -out tls.csr -config tls.cfg -batch -sha256

openssl x509 -req -days 36500 -in tls.csr -sha256 -CA ${ROOT_CA_CERT} -CAkey ${ROOT_CA_KEY} -CAcreateserial -out ${SERVER_CRT} -extensions v3_req -extfile tls.cfg

rm -rf *.cfg *.csr *.srl
}

