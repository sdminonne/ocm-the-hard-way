Inspired to Kelsey's [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way), this tutorial should help you to set up `Open Cluster Manager` (`OCM`). At the same time, going through this repository, one should learn `Open Cluster Manager`  internals and how all the components fit together.



- Pre-requirements and how obtain needed tools

### What we're going to do

1. Install the OCM hub on a local cluster (`minikube` or `kind`) 
2. Install OCM klusterlet to register cluster(s) as a managed cluster(s) on the hub
3. Manage an application via subscription and deploying on managed cluster(s)

At the moment we don't describe placement rules or security policies.

## Via scripts (the easy peasy way)


```shell
./hack/deploy_hub.sh
```

```shell
./hack/deploy_spoke.sh
```


## Aeroplane mode (the very hard) way

Using command line but compiling everything locally and storing in local registry, think developer in 'Airplane Mode' ( as soon She/He  already pulled source code and the local registry artefacts).




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

