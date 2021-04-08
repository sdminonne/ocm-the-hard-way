Inspired to Kelsey's [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way), this tutorial should help you to set up `Open Cluster Manager` (`OCM`). At the same time, going through this repository, one should learn `Open Cluster Manager`  internals and how all the components fit together.



- Pre-requirements and how obtain needed tools

### What we're going to do

1. Install the OCM hub on a local cluster (`minikube` for the moment but it should work with `kind` as well) 
2. Install OCM klusterlet to register cluster(s) as a managed cluster(s) on the hub
3. Manage an application via subscription and deploying on managed cluster(s)

At the moment only registration of existant cluster and application subscription is shown but in the future we should add `placement rules` or `security policies`.

All what is going to be described in [Docs/the_very_hard_way.md](./Docs/the_very_hard_way.md) could be run in a fully automatic way through scripts.


```shell
$  ./hack/deploy_hub.sh
```
will deploy the `hub`, while

```shell
$ ./hack/deploy_managed.sh
```

will deploy the managed cluster and it will register the application (a trivial `Hello Kubernetes!`) Pod.

What is supplied by this repo follows the excellent [www.open-cluster-management.io](https://open-cluster-management.io/) but instead of installing everything trhough `operator-sdk` (the preferred way) it compiles and install everything manually. Currently we deploy only ... in these repositories.
So 


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

All the f you find any issue feel free to open an issue but I can only support RHEL 8 and Fedora 33 'cause I don't have a MAC.