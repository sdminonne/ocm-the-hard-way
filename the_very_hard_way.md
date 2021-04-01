## The Hub

minikube start -p hub --driver=kvm2

You should have something like:

Firsts steps

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


```shell
$ podman images | grep open-cluster-management
localhost:5000/open-cluster-management/registration-operator  latest       c001a77699f0  19 hours ago   156 MB
localhost:5000/open-cluster-management/work                   latest       a2c41f98ab52  20 hours ago   211 MB
localhost:5000/open-cluster-management/registration           latest       60dca2e6ef71  23 hours ago   211 MB
```

Now you should push the images into the minikube instances but since the `minikube cache add ...`  works only (at least in my case) for Docker images before 

podman push docker-daemon:localhost:5000/open-cluster-management/registration-operator:latest


for item in $(podman images | grep localhost:5000/open-cluster-management | awk '{printf "%s:%s\n", $1, $2}'); do podman push docker-daemon:$item; done

for profile in $(minikube profile list -o json | jq -r ".valid[] | .Name"); do for item in $(podman images | grep localhost:5000/open-cluster-management | awk '{printf "%s:%s\n", $1, $2}'); do minikube -p $profile cache add $item; done    ; done

#for item in $(podman images | grep localhost:5000/open-cluster-management | awk '{printf "%s:%s\n", $1, $2}'); do minikube -p hub cache add $item; done


#For the HUB


Here we create the two namepspaces

```shell
kubectl create namespace open-cluster-management-hub
kubectl create namespace open-cluster-management
```

Here we define the Custom Resources (source is github.comopen-cluster-management/api/)


```shell
kubectl create -f https://raw.githubusercontent.com/open-cluster-management/api/main/cluster/v1/0000_00_clusters.open-cluster-management.io_managedclusters.crd.yaml
kubectl create -f https://raw.githubusercontent.com/open-cluster-management/api/main/operator/v1/0000_01_operator.open-cluster-management.io_clustermanagers.crd.yaml
kubectl create -f https://raw.githubusercontent.com/open-cluster-management/api/581cab55c7971e2f8428c1062ba7012885114e34/cluster/v1alpha1/0000_01_clusters.open-cluster-management.io_managedclustersetbindings.crd.yaml
kubectl create -f https://raw.githubusercontent.com/open-cluster-management/api/581cab55c7971e2f8428c1062ba7012885114e34/cluster/v1alpha1/0000_00_clusters.open-cluster-management.io_managedclustersets.crd.yaml
kubectl create -f https://raw.githubusercontent.com/open-cluster-management/api/main/work/v1/0000_00_work.open-cluster-management.io_manifestworks.crd.yaml
kubectl create -f https://raw.githubusercontent.com/open-cluster-management/api/main/work/v1/0000_01_work.open-cluster-management.io_appliedmanifestworks.crd.yaml
```



Now let's start running the cluster-manager (aka registration-operator hub)



Let's give the rights to read APIServer to the SA
```shell
kubectl create -f manifests/hub/open-cluster-management/registration-operator-hub-sa.yaml
kubectl create rolebinding -n kube-system apiserver-reader --role=extension-apiserver-authentication-reader --serviceaccount=open-cluster-management:registration-operator-hub-sa
```

``shell
kubectl create -f manifests/hub/roles/registration-operator-hub-clusterrole.yaml 
kubectl create -f manifests/hub/roles/registration-operator-hub-clusterrolebinding.yaml 
kubectl create -f manifests/hub/open-cluster-management/registration-operator-hub-deployment.yaml
```


Now 

```shell
kubectl apply -f manifests/hub/open-cluster-management-hub/registration-controller-sa.yaml 
```

this creates the registration-controller-sa `serviceAccount` in `open-cluster-management-hub` namespace

```shell
kubectl apply -f manifests/hub/clusterroles/registration-controller-clusterrole.yaml 
```

this create registration-controller-clusterrole

and

```shell
kubectl apply -f manifests/hub/clusterroles/registration-controller-clusterrolebinding.yaml 
```
creates the clusterrolebinding





#For the managed clusters


