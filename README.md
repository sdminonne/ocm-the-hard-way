# Open Cluster Management the hard way

Inspired to Kelsey's [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way), this tutorial should help you to set up `Open Cluster Manager` (`OCM`). At the same time, going through this repository, one should learn `Open Cluster Manager`  internals and how all the components fit together.

What is supplied by this repo follows the excellent [www.open-cluster-management.io](https://open-cluster-management.io/) but instead of installing everything through `operator-sdk` (the preferred way) it compiles and installs (and configures) everything manually.

The environment has been put together to work on a laptop and it's based on `kind` (the default) or on `minikube`. The container images have to be present on the laptop and can be compiled locally or tagged after pull from somewhere else.

As already mentioned the `hub` and the `managed` functionalities will be deployed through code in `https://github.com/open-cluster-management/registration.git` `https://github.com/open-cluster-management/registration-operator.git` and `https://github.com/open-cluster-management/work.git`. The scripts are based on a sort of naming convention which is `localhost:5000/open-cluster-management/<IMAGE NAME>`. The `localhost:5000` prefix could be modified but it's explicitely used in the scripts; it has been added originally to use an `in-cluster` containers registry deployed as a `DaemonSet`.

So listing the images on your laptop with `podman` or with `docker`, as soon you've something like this (with `podman`)

```shell
$ podman images | grep open-cluster-management
localhost:5000/open-cluster-management/registration-operator  latest       c001a77699f0  19 hours ago   156 MB
localhost:5000/open-cluster-management/work                   latest       a2c41f98ab52  20 hours ago   211 MB
localhost:5000/open-cluster-management/registration           latest       60dca2e6ef71  23 hours ago   211 MB
```

you can start the scripts otheriwse you might compile the source code directly:

```shell
git clone https://github.com/open-cluster-management/registration.git
cd registration

# Linux
buildah bud -t localhost:5000/open-cluster-management/registration .
# Mac OS
docker build -t localhost:5000/open-cluster-management/registration .

cd -
```

```shelll
git clone https://github.com/open-cluster-management/work.git
cd work

# Linux
buildah bud -t localhost:5000/open-cluster-management/work .

# Mac OS
docker build -t localhost:5000/open-cluster-management/work .

cd -
```

```shell
git clone https://github.com/open-cluster-management/registration-operator.git
cd registration-operator

# Linux
buildah bud -t localhost:5000/open-cluster-management/registration-operator .

# Mac OS
docker build -t localhost:5000/open-cluster-management/registration-operator .

cd -
```

As soon you've the images tagged locally with `localhost:5000/open-cluster-management/<IMAGE>:latest` the scripts automatically provision the images on the cluster (for both providers).


### Prerequirements

Most of the needed tools should be available on a laptop, the scripts perform prerequirement checks and everything relies only on pretty standard tools except maybe cloudflare ssl tools (`cfssl` and `cfssljson`) which can be downloaded from  https://pkg.cfssl.org. Obviously you should have `kubectl`.


### What we're going to do

1. Install the OCM hub on a local cluster (`kind` for the moment but it should work with `kind` as well) 
2. Install OCM klusterlet to register cluster(s) as a managed cluster(s) on the hub
3. Manage an application via subscription and deploy the application on managed cluster(s)

At the moment only registration of existant cluster and application subscription is shown. In the future we should add `placement rules` or `security policies`.
All what is going to be described in [Docs/the_very_hard_way.md](./Docs/the_very_hard_way.md) can be run in a fully automatic way through scripts.


```shell
$  ./hack/deploy_hub.sh
Hub name         -> hub
Container engine -> docker
Cluster provider -> kind
Creating cluster "hub" ...
 ✓ Ensuring node image (kindest/node:v1.20.2) 🖼
 ✓ Preparing nodes 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
 Set kubectl context to "kind-hub"
... 
deployment up and running kind-hub open-cluster-management-hub cluster-manager-registration-webhook: OK
Hub deployed
```

will deploy the `hub` using `kind` the default cluster provider, another cluster provider is supported on Linux only: `./hack/deploy_hub -p minikube`.

As soon you've the `hub` you can deploy one managed cluster

```shell
$ ./hack/deploy_managed.sh
Managed cluster name -> cluster1
Hub cluster name     -> hub
Container engine     -> docker
Cluster provider     -> kind
Creating cluster "cluster1" ...
 ✓ Ensuring node image (kindest/node:v1.20.2) 🖼
 ✓ Preparing nodes 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
Set kubectl context to "kind-cluster1"
...
pod up and running kind-cluster1 default hello: OK
Hello, Kubernetes!
```

which deploy the managed cluster and it will register the application (a trivial `Hello Kubernetes!`) Pod.

The `./hack/deploy_managed.sh` script optionally takes as input the name of the `hub` (which must be present). Hence one may have more than one hub. Obviously one managed cluster can be registered only to a single `hub`.
 A limitation of this small infrastructure is that all clusters must run under the same cloud provider (`minikube` or `kind`), the limitation comes directly from the scripts (kubernetes context for `minikube` and `kind` are different) and it could be removed in the future.


As soon you've deployed your micro fleet of clusters you can remove everything via the commands

```shell
./hack/tear_down.sh
Managed cluster name -> 
Hub cluster name     -> hub
Container engine     -> 
Cluster provider     -> kind
Removing all clusters for kind
Deleting cluster "cluster1" ...
Deleting cluster "hub" ...
```
