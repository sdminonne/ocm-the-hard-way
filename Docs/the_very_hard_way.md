Disclaimer: In order to simplify ... For example multiple `clusterroles` and `clusterrolebindings` have been consolidated in only `clusterrole` and `clusterrolebinding`.



## Installing The Hub

Using `minikube` or `kind`:

```shell
# using 'minikube'
HUBNAME=hub
HUBCONTEXT=hub
#minikube start -p ${HUBNAME} --driver=kvm2  
```

```shell
# using 'kind'
HUBNAME=hub
HUBCONTEXT=kind-hub
#kind create cluster --name ${HUBNAME} 
```

Here we define the Custom Resources (source is github.com/open-cluster-management/api/)

```shell
kubectl --context ${HUBCONTEXT} apply -f https://raw.githubusercontent.com/open-cluster-management/api/main/cluster/v1/0000_00_clusters.open-cluster-management.io_managedclusters.crd.yaml
kubectl --context ${HUBCONTEXT} apply -f https://raw.githubusercontent.com/open-cluster-management/api/main/operator/v1/0000_01_operator.open-cluster-management.io_clustermanagers.crd.yaml
kubectl --context ${HUBCONTEXT} apply -f https://raw.githubusercontent.com/open-cluster-management/api/581cab55c7971e2f8428c1062ba7012885114e34/cluster/v1alpha1/0000_01_clusters.open-cluster-management.io_managedclustersetbindings.crd.yaml
kubectl --context ${HUBCONTEXT} apply -f https://raw.githubusercontent.com/open-cluster-management/api/581cab55c7971e2f8428c1062ba7012885114e34/cluster/v1alpha1/0000_00_clusters.open-cluster-management.io_managedclustersets.crd.yaml
kubectl --context ${HUBCONTEXT} apply -f https://raw.githubusercontent.com/open-cluster-management/api/main/work/v1/0000_00_work.open-cluster-management.io_manifestworks.crd.yaml
kubectl --context ${HUBCONTEXT} apply -f https://raw.githubusercontent.com/open-cluster-management/api/main/work/v1/0000_01_work.open-cluster-management.io_appliedmanifestworks.crd.yaml
```


OCM Hub sub-components resides in two namespaces: 
1. open-cluster-management-hub
2. open-cluster-management


### open-cluster-management namespace

```shell
kubectl --context ${HUBCONTEXT} create namespace open-cluster-management
```

```shell
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/open-cluster-management/cluster-manager-sa.yaml
```

```shell
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/clusterroles/cluster-manager-clusterrole.yaml
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/clusterrolebindings//cluster-manager-clusterrolebinding.yaml
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/open-cluster-management/cluster-manager-deployment.yaml
```


After this we should have the `cluster-manager` deployed
```shell
kubectl  --context ${HUBCONTEXT} get all -n open-cluster-management
NAME                                   READY   STATUS    RESTARTS   AGE
pod/cluster-manager-56975c957d-wpdbv   1/1     Running   0          18s

NAME                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cluster-manager   1/1     1            1           18s

NAME                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/cluster-manager-56975c957d   1         1         1       18s
```

### open-cluster-management-hub namespace

```shell
kubectl --context ${HUBCONTEXT} create namespace open-cluster-management-hub
```

```shell
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/open-cluster-management-hub/cluster-manager-registration-controller-sa.yaml
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/open-cluster-management-hub/cluster-manager-work-webhook-sa.yaml
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/open-cluster-management-hub/cluster-manager-registration-webhook-sa.yaml
```

```shell
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/clusterroles/cluster-manager-registration-controller-clusterrole.yaml 
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/clusterrolebindings/cluster-manager-registration-controller-clusterrolebinding.yaml 
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/open-cluster-management-hub/cluster-manager-registration-controller-deployment.yaml
```

and now the `cluster-manager-registration-controller` should be deployed:

```shell
kubectl --context ${HUBCONTEXT} get all -n open-cluster-management-hub
NAME                                                         READY   STATUS    RESTARTS   AGE
pod/clustermanager-registration-controller-6fd688757-ncfs6   1/1     Running   0          21s

NAME                                                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/clustermanager-registration-controller   1/1     1            1           21s

NAME                                                               DESIRED   CURRENT   READY   AGE
replicaset.apps/clustermanager-registration-controller-6fd688757   1         1         1       21s
```

Now the webhooks

```shell
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/clusterroles/cluster-manager-work-webhook-clusterrole.yaml
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/clusterrolebindings/cluster-manager-work-webhook-clusterrolebinding.yaml
```


```shell
source ./hack/common.sh
certsdir=$(mktemp -d)

kube::util::create_signing_certkey "" "${certsdir}" serving '"server auth"'

kube::util::create_serving_certkey "" "${certsdir}" "serving-ca" cluster-manager-work-webhook.open-cluster-management-hub.svc "cluster-manager-work-webhook.open-cluster-management-hub.svc" "cluster-manager-work-webhook.open-cluster-management-hub.svc"

KUBE_CA=$(kubectl config view --minify=true --flatten -o json | jq '.clusters[0].cluster."certificate-authority-data"' -r)
cat artifacts/hub/open-cluster-management-hub/cluster-manager-work-webhook-list-template.yaml | \
    sed "s/TLS_SERVING_CERT/$(base64 ${certsdir}/serving-cluster-manager-work-webhook.open-cluster-management-hub.svc.crt | tr -d '\n')/g" | \
    sed "s/TLS_SERVING_KEY/$(base64 ${certsdir}/serving-cluster-manager-work-webhook.open-cluster-management-hub.svc.key | tr -d '\n')/g" | \
    sed "s/SERVICE_SERVING_CERT_CA/$(base64 ${certsdir}/serving-ca.crt | tr -d '\n')/g" | \
    sed "s/KUBE_CA/${KUBE_CA}/g" | \
    kubectl  --context ${HUBCONTEXT}  apply -f -
```


One may want to test the work webhook...


```shell
kubectl create ns tmp-cluster
cat <<EOF | kubectl --context ${HUBCONTEXT} apply -f -
apiVersion: work.open-cluster-management.io/v1
kind: ManifestWork
metadata:
  name: mw-01
  namespace: tmp-cluster
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
```


We already creted the service account so... clusterrole and clusterrolebinding are enough
```shell
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/clusterroles/cluster-manager-registration-webhook-clusterrole.yaml 
kubectl --context ${HUBCONTEXT} apply -f artifacts/hub/clusterrolebindings/cluster-manager-registration-webhook-clusterrolebinding.yaml 
```


```shell
source ./hack/common.sh
certsdir=$(mktemp -d)

kube::util::create_signing_certkey "" "${certsdir}" serving '"server auth"'

kube::util::create_serving_certkey "" "${certsdir}" "serving-ca" cluster-manager-registration-webhook.open-cluster-management-hub.svc "cluster-manager-registration-webhook.open-cluster-management-hub.svc" "cluster-manager-registration-webhook.open-cluster-management-hub.svc"

KUBE_CA=$(kubectl config view --minify=true --flatten -o json | jq '.clusters[0].cluster."certificate-authority-data"' -r)
cat artifacts/hub/open-cluster-management-hub/cluster-manager-registration-webhook-list.template.yaml | \
    sed "s/TLS_SERVING_CERT/$(base64 ${certsdir}/serving-cluster-manager-registration-webhook.open-cluster-management-hub.svc.crt | tr -d '\n')/g" | \
    sed "s/TLS_SERVING_KEY/$(base64 ${certsdir}/serving-cluster-manager-registration-webhook.open-cluster-management-hub.svc.key | tr -d '\n')/g" | \
    sed "s/SERVICE_SERVING_CERT_CA/$(base64 ${certsdir}/serving-ca.crt | tr -d '\n')/g" | \
    sed "s/KUBE_CA/${KUBE_CA}/g" | \
    kubectl  --context ${HUBCONTEXT}  apply -f -
```

Now the `hub` or whatever you've named it in ${HUBNAME} is ready to handle managed clusters registration and workload

## Installing the managed cluster(s)

Using `minikube` or `kind`:

```shell
# using 'minikube'
MANAGEDNAME=cluster1
MANAGEDCONTEXT=cluster1
#minikube start -p ${MANAGEDNAME} --driver=kvm2  
```

```shell
# using 'kind'
MANAGEDNAME=cluster1
MANAGEDCONTEXT=kind-cluster1
#kind create cluster --name ${MANAGEDNAME}
```

The container images are shared among all the minikube clusters, no need to re-run `minikube cache` commands.


```shell
kubectl --context ${MANAGEDCONTEXT} apply -f  ./artifacts/managed/crds/
```

### Namespace open-cluster-management

The namespace `open-cluster-management` in managed clusters contains... 


```shell
kubectl --context ${MANAGEDCONTEXT} create ns open-cluster-management
```

```shell
kubectl --context ${MANAGEDCONTEXT} apply -f artifacts/managed/open-cluster-management/klusterlet-sa.yaml

kubectl --context ${MANAGEDCONTEXT} apply -f artifacts/managed/clusterroles/open-cluster-management-klusterlet.yaml 

kubectl --context ${MANAGEDCONTEXT} apply -f artifacts/managed/clusterrolebindings/open-cluster-management-klusterlet.yaml

kubectl --context ${MANAGEDCONTEXT} apply -f artifacts/managed/open-cluster-management/klusterlet-deployment.yaml
```

and now the `klusterlet` should be deployed:

```shell
kubectl --context ${MANAGEDCONTEXT} get all -n open-cluster-management
NAME                              READY   STATUS    RESTARTS   AGE
pod/klusterlet-768fbd59d6-69ndb   1/1     Running   0          25s

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/klusterlet   1/1     1            1           25s

NAME                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/klusterlet-768fbd59d6   1         1         1       25s
```

### Namespace open-cluster-management-agent


```shell
kubectl --context ${MANAGEDCONTEXT} create ns open-cluster-management-agent
```

Creating the secrets for the klusterlet work and registration.

```shell
tmpkubeconfig=$(mktemp)
```

For `minikube`

```shell
kubectl --context ${HUBCONTEXT} config view --flatten --minify > ${tmpkubeconfig}
kubectl --context ${MANAGEDCONTEXT} create secret generic bootstrap-hub-kubeconfig --from-file=kubeconfig="${tmpkubeconfig}" -n open-cluster-management-agent
```

For `kind`

```shell
kind get kubeconfig --name hub --internal > ${tmpkubeconfig}
kubectl --context ${MANAGEDCONTEXT} create secret generic bootstrap-hub-kubeconfig --from-file=kubeconfig="${tmpkubeconfig}" -n open-cluster-management-agent
```

Now we deploy `klusterlet-registration` which automate the cluster registration until the final approval which should be performed manually.

Let's start with service account, clusterroles and clusterrolebindings

```shell
kubectl --context ${MANAGEDCONTEXT} apply -f  artifacts/managed/open-cluster-management-agent/klusterlet-registration-sa.yaml

kubectl --context ${MANAGEDCONTEXT} apply -f  artifacts/managed/clusterroles/open-cluster-management-agent-klusterlet-registration.yaml

kubectl --context ${MANAGEDCONTEXT} apply -f artifacts/managed/clusterrolebindings/open-cluster-management-agent-klusterlet-registration.yaml


#TODO change "cluster1" in the file to ${MANAGEDNAME} value
kubectl --context ${MANAGEDCONTEXT} apply -f  artifacts/managed/open-cluster-management-agent/klusterlet-registration-agent-deployment.yaml
```

and now the `klusterlet-registration-agent` should be deployed:

```shell
kubectl --context ${MANAGEDCONTEXT} get all -n open-cluster-management-agent
NAME                                                 READY   STATUS    RESTARTS   AGE
pod/klusterlet-registration-agent-688b99d559-pfl2k   1/1     Running   0          14m

NAME                                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/klusterlet-registration-agent   1/1     1            1           14m

NAME                                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/klusterlet-registration-agent-688b99d559   1         1         1       14m
```


Now if you list the  clusters managed by `hub`

```shell
kubectl --context ${HUBCONTEXT} get managedclusters
NAME       HUB ACCEPTED   MANAGED CLUSTER URLS   JOINED   AVAILABLE   AGE
cluster1   false          https://localhost
```



```shell
cat <<EOF | kubectl --context ${MANAGEDCONTEXT} apply -f -
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
```


```shell 
csrname=$(kubectl --context ${HUBCONTEXT} get csr -o=jsonpath="{.items[?(@.metadata.generateName=='$MANAGEDNAME-')].metadata.name}")
kubectl --context ${HUBCONTEXT} certificate approve  $csrname 
kubectl --context ${HUBCONTEXT} patch managedcluster ${MANAGEDNAME} -p='{"spec":{"hubAcceptsClient":true}}' --type=merge
```



```shell
kubectl --context ${HUBCONTEXT} get managedclusters
NAME       HUB ACCEPTED   MANAGED CLUSTER URLS   JOINED   AVAILABLE   AGE
cluster1   true           https://localhost      True     True        31m
```


Now we deploy `klusterlet-work` Pods which handle the workload declared in the `hub` through the `ManifestWork` Custom Resource.


```shell
kubectl --context ${MANAGEDCONTEXT} apply -f  artifacts/managed/open-cluster-management-agent/klusterlet-work-sa.yaml

kubectl --context ${MANAGEDCONTEXT} apply -f artifacts/managed/clusterroles/open-cluster-management-agent-klusterlet-work.yaml

kubectl --context ${MANAGEDCONTEXT} apply -f artifacts/managed/clusterrolebindings/open-cluster-management-agent-klusterlet-work.yaml 


#TODO change "cluster1" in the file to ${MANAGEDNAME} value
kubectl  --context ${MANAGEDCONTEXT} apply -f artifacts/managed/open-cluster-management-agent/klusterlet-work-agent-deployment.yaml
```

and now the `klusterlet-work-agent` should be deployed:

```shell
kubectl --context ${MANAGEDCONTEXT} get all -n open-cluster-management-agent
NAME                                                 READY   STATUS    RESTARTS   AGE
pod/klusterlet-registration-agent-688b99d559-pfl2k   1/1     Running   0          14m
pod/klusterlet-work-agent-5cc776b4d6-nhtz2           1/1     Running   0          101s

NAME                                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/klusterlet-registration-agent   1/1     1            1           14m
deployment.apps/klusterlet-work-agent           1/1     1            1           101s

NAME                                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/klusterlet-registration-agent-688b99d559   1         1         1       14m
replicaset.apps/klusterlet-work-agent-5cc776b4d6           1         1         1       101s
```

and now to test if work can be propagate from the hub cluster to the managed cluster:

```shell
cat <<EOF | kubectl --context ${HUBCONTEXT} apply -f -
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
```

check if the work is done in the managed cluster:

```shell
kubectl --context ${MANAGEDCONTEXT} -n default logs hello
Hello, Kubernetes!
```
