
```shell
operator-sdk olm install --version 0.16.1
```

Why we do need a version 0.16.1?


$ kubectl get crds -A
NAME                                          CREATED AT
catalogsources.operators.coreos.com           2021-03-02T21:05:57Z
clusterserviceversions.operators.coreos.com   2021-03-02T21:05:57Z
installplans.operators.coreos.com             2021-03-02T21:05:57Z
operatorgroups.operators.coreos.com           2021-03-02T21:05:57Z
operators.operators.coreos.com                2021-03-02T21:05:57Z
subscriptions.operators.coreos.com            2021-03-02T21:05:57Z


NAME                                            NAMESPACE    KIND                        STATUS
catalogsources.operators.coreos.com                          CustomResourceDefinition    Installed
clusterserviceversions.operators.coreos.com                  CustomResourceDefinition    Installed
installplans.operators.coreos.com                            CustomResourceDefinition    Installed
operatorgroups.operators.coreos.com                          CustomResourceDefinition    Installed
operators.operators.coreos.com                               CustomResourceDefinition    Installed
subscriptions.operators.coreos.com                           CustomResourceDefinition    Installed



olm                                                          Namespace                   Installed
operators                                                    Namespace                   Installed

olm-operator-serviceaccount                     olm          ServiceAccount              Installed
system:controller:operator-lifecycle-manager                 ClusterRole                 Installed
olm-operator-binding-olm                                     ClusterRoleBinding          Installed
olm-operator                                    olm          Deployment                  Installed
catalog-operator                                olm          Deployment                  Installed
aggregate-olm-edit                                           ClusterRole                 Installed
aggregate-olm-view                                           ClusterRole                 Installed
global-operators                                operators    OperatorGroup               Installed
olm-operators                                   olm          OperatorGroup               Installed
packageserver                                   olm          ClusterServiceVersion       Installed
operatorhubio-catalog                           olm          CatalogSource               Installed



```shell
 operator-sdk run packagemanifests deployment/cluster-manager/olm-catalog/cluster-manager/ --namespace open-cluster-management --version 0.3.0 --install-mode OwnNamespace --timeout=10m
INFO[0000] Creating cluster-manager registry            
INFO[0000]   Creating ConfigMap "open-cluster-management/cluster-manager-registry-manifests-package" 
INFO[0000]   Creating ConfigMap "open-cluster-management/cluster-manager-registry-manifests-0-1-0" 
INFO[0000]   Creating ConfigMap "open-cluster-management/cluster-manager-registry-manifests-0-2-0" 
INFO[0000]   Creating ConfigMap "open-cluster-management/cluster-manager-registry-manifests-0-3-0" 
INFO[0000]   Creating Deployment "open-cluster-management/cluster-manager-registry-server" 
INFO[0000]   Creating Service "open-cluster-management/cluster-manager-registry-server" 
INFO[0000] Waiting for Deployment "open-cluster-management/cluster-manager-registry-server" rollout to complete 
INFO[0000]   Waiting for Deployment "open-cluster-management/cluster-manager-registry-server" to rollout: 0 out of 1 new replicas have been updated 
INFO[0001]   Waiting for Deployment "open-cluster-management/cluster-manager-registry-server" to rollout: 0 of 1 updated replicas are available 
INFO[0012]   Deployment "open-cluster-management/cluster-manager-registry-server" successfully rolled out 
INFO[0012] Created CatalogSource: cluster-manager-catalog 
INFO[0012] OperatorGroup "operator-sdk-og" created      
INFO[0012] Created Subscription: cluster-manager-v0-3-0-sub 
INFO[0014] Approved InstallPlan install-wwlfv for the Subscription: cluster-manager-v0-3-0-sub 
INFO[0014] Waiting for ClusterServiceVersion "open-cluster-management/cluster-manager.v0.3.0" to reach 'Succeeded' phase 
INFO[0014]   Waiting for ClusterServiceVersion "open-cluster-management/cluster-manager.v0.3.0" to appear 
INFO[0018]   Found ClusterServiceVersion "open-cluster-management/cluster-manager.v0.3.0" phase: Pending 
INFO[0019]   Found ClusterServiceVersion "open-cluster-management/cluster-manager.v0.3.0" phase: Installing 
INFO[0040]   Found ClusterServiceVersion "open-cluster-management/cluster-manager.v0.3.0" phase: Succeeded 
INFO[0040] OLM has successfully installed "cluster-manager.v0.3.0" 
```

which creates:

```shell
deployment open-cluster-management/cluster-manager
```

and

```shell
deployment open-cluster-management/cluster-manager-registry-server
```




```shell
kubectl apply -f deployment/cluster-manager/config/samples/operator_open-cluster-management_clustermanagers.cr.yaml 
clustermanager.operator.open-cluster-management.io/cluster-manager created
```

Which creates
deployment open-cluster-management-hub/cluster-manager-registration-controller
and
deployment open-cluster-management-hub/cluster-manager-work-webhook