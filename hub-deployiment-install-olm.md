
```shell
operator-sdk olm install --version 0.16.1
```

OLM installs various CRDs

```shell
$ kubectl get crds -A
```

| NAME      |   Explanations |       
|:---------:|:--------------:|
| catalogsources.operators.coreos.com |           TODO |
| clusterserviceversions.operators.coreos.com |  TODO |
| installplans.operators.coreos.com | TODO |
| operatorgroups.operators.coreos.com | TODO |
| operators.operators.coreos.com | TODO |
| subscriptions.operators.coreos.com | TODO |




and 2 namespaces
| NAME      |   Explanations |       
|:---------:|:--------------:|
| olm  |   TODO |
| operators |    TODO |  


3 deployments in `olm` Namespace

| Deployment       | Explanations |  
|:------------------:|:------:|
| catalog-operator | TODO |
| olm-operator     |  TODO |
| packageserver    | TODO |


and the associated services (`olm` namespaces)

| Deployment             | Explanations |  
|:----------------------:|:------:|
| operatorhubio-catalog  | TODO   |
| packageserver-service  |  TODO  |


For Authn/Authz

https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&uact=8&ved=0ahUKEwiWzure9L7YAhXB16QKHWxSBzQQFggnMAA&url=http%3A%2F%2Fbdmath.com%2Fbooks%2FThe%2520Code%2520Book.pdf&usg=AOvVaw2vBTYUbpSB6aW0sx03TX5B
| Name                                           |    Kind               |     Namespace | Explanations |   
|:----------------------------------------------:|:---------------------:|:-------------:|:------------:|
| olm-operator-serviceaccount                    | ServiceAccount        |     olm       | TODO         |
| system:controller:operator-lifecycle-manager   | ClusterRole           |      -        | TODO         |
| olm-operator-binding-olm                       | ClusterRoleBinding    |      -        | TODO         |
| aggregate-olm-edit                             | ClusterRole           |      -        | TODO         |
| aggregate-olm-view                             | ClusterRole           |      -        | TODO         |
| global-operators                               | OperatorGroup         |   operators   | TODO         |
| olm-operators                                  | OperatorGroup         |      olm      | TODO         |
| packageserver                                  | ClusterServiceVersion |      olm      | TODO         |
| operatorhubio-catalog                          | CatalogSource         |     olm       | TODO         |


Why we do need a version 0.16.1?

