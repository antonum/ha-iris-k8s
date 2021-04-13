#!/bin/bash

#change to your own values
namespace=backup-test

#create namespace
echo -e "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: ${namespace}" | kubectl apply -f -
#kubectl create namespace $namespace

kubectl apply -f tldr.yaml -n $namespace
#Wait for pod to be ready
while [[ $(kubectl get pods -n $namespace -l app=iris -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pod" && sleep 1; done
pod_name=$(kubectl get pods -n $namespace -l app=iris  -o 'jsonpath={.items..metadata.name}')
#Wait for IRIS to start. 
until kubectl exec -it -n $namespace $pod_name -- iris qlist | grep running; do echo "waiting IRIS to start" && sleep 1; done
echo "In another terminal run the following command and add some data:"
echo "  kubectl exec -it -n $namespace $pod_name -- iris session iris"
echo "  USER>set ^test=\"iris backup test\""
kubectl -n $namespace exec $pod_name -- bash -c 'echo -e "set ^k8stest(\$i(^k8stest))=\$zdt(\$h)_\" running on \"_\$system.INetInfo.LocalHostName() write ^k8stest(^k8stest) \n h" | iris session iris -U USER'

#read -p "Press [Enter] key to start backup..."
#Freeze Write Daemon 
echo "Freezing IRIS Write Daemon"
kubectl exec -it -n $namespace $pod_name -- iris session iris -U%SYS "##Class(Backup.General).ExternalFreeze()"
status=$?
if [[ $status -eq 5 ]]; then
  echo "IRIS WD IS FROZEN, Performing backup"
  kubectl apply -f backup/iris-volume-snapshot.yaml -n $namespace
elif [[ $status -eq 3 ]]; then
  echo "IRIS WD FREEZE FAILED"
fi
#Thaw Write Daemon 
kubectl exec -it -n $namespace $pod_name -- iris session iris -U%SYS "##Class(Backup.General).ExternalThaw()"  
while [[ $(kubectl get volumesnapshot -n $namespace  -o 'jsonpath={.items..status.readyToUse}') != "true" ]]; do echo "waiting for snapshot to be ready" && sleep 1; done
#Create clone
echo Creating clone, based on backup
kubectl apply -f backup/iris-pvc-snapshot-restore.yaml -n $namespace
#read -p "Snapshot created [Enter] key to stop deployment and clone..."
kubectl apply -f backup/iris-deployment-snapshot.yaml -n $namespace
#Wait for pod to be ready
while [[ $(kubectl get pods -n $namespace -l app=irisclone -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pod" && sleep 1; done
pod_name=$(kubectl get pods -n $namespace -l app=irisclone -o 'jsonpath={.items..metadata.name}')
#Wait for IRIS to start
until kubectl exec -it -n $namespace $pod_name -- iris qlist | grep running; do echo "waiting IRIS to start" && sleep 1; done
echo "You can now access restored clone in another terminal"
echo "  kubectl exec -it -n $namespace $pod_name -- iris session iris"
#read -p "Press [Enter] key to stop deployment and clone..."

kubectl -n $namespace exec $pod_name -- bash -c 'echo -e "write \"Previos state: \",^k8stest(^k8stest),!, \"Now running on: \",\$system.INetInfo.LocalHostName() \n h" | iris session iris -U USER'

#Delete clone
kubectl delete -f backup/iris-deployment-snapshot.yaml -n $namespace
kubectl delete -f backup/iris-pvc-snapshot-restore.yaml -n $namespace

#Delete original deployment
kubectl delete -f tldr.yaml -n $namespace

#Delete backup
kubectl delete -f backup/iris-volume-snapshot.yaml -n $namespace

#Delete namespace
kubectl delete namespace $namespace