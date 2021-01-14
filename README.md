# Highly available IRIS deployment on Kubernetes without mirroring

## TL;DR

Install Longhorn (distributed highly-avaliable storage CSI for K8s) and IRIS deployment
```
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml

kubectl apply -f https://github.com/antonum/ha-iris-k8s/raw/main/tldr.yaml
```
First `kubectl apply` installs Longhorn - open source distributed Kubernetes storage engine that would allow our system to tolerate failure of individual disks, nodes and even entire Availability zone, without involving mirroring. Second would install IRIS deployment, using Longhorn storage for Durable SYS as well as associated volume claim and service, exposing IRIS to the outside world. Deployment would take care of things like failure of the individual IRIS instance. 

Wait for all the pods turn to Running state
```
kubectl get pods -A 
```

Identify pod name for IRIS deployment public IP of the 'iris--csv' service and node,  running IRIS pod.
```
kubectl get pods -o wide
NAME                    READY   STATUS    RESTARTS   AGE     IP            NODE                                NOMINATED NODE   READINESS GATES
iris-6d8896d584-8lzn5   1/1     Running   0          4m23s   10.244.0.35   aks-agentpool-29845772-vmss000001   <none>           <none>

kubectl get svc
NAME         TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)           AGE
iris-svc     LoadBalancer   10.0.219.94   40.88.18.182   52773:30056/TCP   6m3s
kubernetes   ClusterIP      10.0.0.1      <none>         443/TCP           6d9h
```
Access IRIS Management portal at: http://40.88.18.182:52773/csp/sys/%25CSP.Portal.Home.zen 

Now start messing around. But before we do it - try to add some data into the database and make sure it's there when IRIS is back online.

```
kubectl exec -it iris-6d8896d584-8lzn5 -- iris session iris
USER>set ^k8stest($i(^k8stest))=$zdt($h)_" running on "_$system.INetInfo.LocalHostName()

USER>zw ^k8stest
^k8stest=1
^k8stest(1)="01/14/2021 14:13:19 running on iris-6d8896d584-8lzn5"
```
Now let's do what is now called the fancy name "chaos engineering"

```
# Delete the pod
kubectl delete pod iris-6d8896d584-8lzn5

# "force drain" the node, serving the iris pod
kubectl drain aks-agentpool-29845772-vmss000001 --delete-local-data --ignore-daemonsets

# Delete the node
# well... you can't really do it with kubectl. Find that instance or VM and KILL it.
# if you have access to the machine - turn off the power or disconnect the network cable. Seriosly!
```


In all cases IRIS would be back online with all the data fairly soon.