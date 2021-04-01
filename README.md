Inspired to Kelsey's [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way), this tutorial should help you to set up `Open Cluster Manager` (`OCM`). At the same time, going through this repository, one should learn `Open Cluster Manager`  internals and how all the components fit together.



- Pre-requirements and how obtain needed tools

### What we're going to do

- Deploying the hub cluter 
- Deploying the managed cluster(s)
- Manage an application across multiple clusters


## Via scripts (the easy peasy way)

Goal of this section
```shell
./hack/deploy_hub.sh

./hack/deploy_hub.sh
```


Now you can obtain the CRDs for the hub cluster...

for item in $(kubectl get crds | grep open-cluster-management.io | awk '{print $1}'); do kubectl get crd $item -o yaml > exported/crds/$item.yaml; done


## Manually (the hard way)

Using command line and OLM: goal of this section is to give more details about OCM internals, how different pieces fits together





## Aeroplane mode (the very hard) way

Using command line but compiling everything locally and storing in local registry, think developer in 'Airplane Mode', as soon She already pulled source code and the local registry artefacts.
TODO





```shell
git clone https://github.com/open-cluster-management/registration.git
cd registration
buildah bud -t localhost:5000/open-cluster-management/registration .
```

```shelll
git clone https://github.com/open-cluster-management/work.git
cd work
buildah bud -t localhost:5000/open-cluster-management/work
```


```shell
git clone https://github.com/open-cluster-management/registration-operator.git
cd registration-operator
buildah bud -t localhost:5000/open-cluster-management/registration-operator .
```




kubectl create rolebinding -n kube-system open-cluster-manager-list-pods-rolebinding  --role=extension-apiserver-authentication-reader --serviceaccount=open-cluster-management:cluster-manager


kubectl --context=hub create -f ./exported/hub/open-cluster-management/cluster-manager.yaml  -n open-cluster-management

