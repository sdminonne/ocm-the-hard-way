Inspired to Kelsey's [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way), this tutorial should help you to set up `Open Cluster Manager` (`OCM`). At the same time, going through this repository, one should learn `Open Cluster Manager`  internals and how all the components fit together.

The environment has been put together to work on a laptop and it's based on `minikube` (the default) or on `kind`. The container images have to be present on the laptop and can be compiled locally or tagged after pull from somewhere else.

### Prerequirements

Most of the needed tools should be available on a laptop, the scripts perform prerequirement checks and everything relies only on pretty standard tools except maybe cloudflare ssl tools (`cfssl` and `cfssljson`) which can be downloaded from  https://pkg.cfssl.org. Obviously you should have `kubectl`.


### What we're going to do

1. Install the OCM hub on a local cluster (`minikube` for the moment but it should work with `kind` as well) 
2. Install OCM klusterlet to register cluster(s) as a managed cluster(s) on the hub
3. Manage an application via subscription and deploy the application on managed cluster(s)

At the moment only registration of existant cluster and application subscription is shown. In the future we should add `placement rules` or `security policies`.
All what is going to be described in [Docs/the_very_hard_way.md](./Docs/the_very_hard_way.md) can be run in a fully automatic way through scripts.


```shell
# Linux / Deploy with minikube (Minikube 'kvm2' is not supported on darwin/amd64)
$  ./hack/deploy_hub.sh
```

will deploy the `hub` using `minikube`.

To deploy the `hub` using `kind` you should run. 

```shell
# MAC OS / Deploy with Kind
OCM_THE_HARD_WAY_CLUSTER_PROVIDER=kind HUBNAME=hubcluster ./hack/deploy_hub.sh
```

Similarly

```shell
# Linux / Deploy with minikube (Minikube 'kvm2' is not supported on darwin/amd64)
$ ./hack/deploy_managed.sh
```

or 

```shell
# MAC OS / Deploy with Kind
OCM_THE_HARD_WAY_CLUSTER_PROVIDER=kind HUBNAME=hubcluster ./hack/deploy_managed.sh
```


will deploy the managed cluster and it will register the application (a trivial `Hello Kubernetes!`) Pod.


What is supplied by this repo follows the excellent [www.open-cluster-management.io](https://open-cluster-management.io/) but instead of installing everything trhough `operator-sdk` (the preferred way) it compiles and install everything manually.

The `hub` and the `managed` functionalities will be deployed through code in `https://github.com/open-cluster-management/registration.git` `https://github.com/open-cluster-management/registration-operator.git` and `https://github.com/open-cluster-management/work.git`. The scripts work based on a sort of naming convention which is `localhost:5000/open-cluster-management/<IMAGE NAME>`. The `localhost:5000` prefix could be changed, it has been added originally to use an `in-cluster` containers registry deployed as a `DaemonSet`.


```shell
$ podman images | grep open-cluster-management
localhost:5000/open-cluster-management/registration-operator  latest       c001a77699f0  19 hours ago   156 MB
localhost:5000/open-cluster-management/work                   latest       a2c41f98ab52  20 hours ago   211 MB
localhost:5000/open-cluster-management/registration           latest       60dca2e6ef71  23 hours ago   211 MB
```

otheriwse you might compile the source code directly:


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

Now you should push the images into the minikube instances through `minikube cache add <image name>`. According to the [doc](https://minikube.sigs.k8s.io/docs/handbook/pushing/#2-push-images-using-cache-command)  only docker images are supported so we need to copy images from rootless images store (podman/buildah) to `docket-daemon` via command like `podman push docker-daemon:<image name>`

```shell
# Linux
$ for item in $(podman images | grep localhost:5000/open-cluster-management | awk '{printf "%s:%s\n", $1, $2}'); do podman push docker-daemon:$item; done
# Mac OS
$ for item in $(docker images | grep localhost:5000/open-cluster-management | awk '{printf "%s:%s\n", $1, $2}'); do kind load docker-image $item --name hub; done
```
and now

```shell
for item in $(podman images | grep localhost:5000/open-cluster-management | awk '{printf "%s:%s\n", $1, $2}'); do minikube cache add $item; done 
```



All the f you find any issue feel free to open an issue but I can only support RHEL and Fedora 33 (sorry Fedora34 folks, not yet updated) 'cause I don't have a MAC.