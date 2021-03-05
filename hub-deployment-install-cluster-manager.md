## Hub Deployment: installing Cluster Manager & Cluster Manager Registry Server


```shell
operator-sdk run packagemanifests deployment/cluster-manager/olm-catalog/cluster-manager/ --namespace open-cluster-management --version 0.3.0 --install-mode OwnNamespace --timeout=10m

```