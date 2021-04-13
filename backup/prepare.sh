#!/bin/bash

#change to your own values
s3_bucket=longhorn-backup-dev
s3_region=us-east-2
aws_key=AKIA5Q4VZVF55A44564Y
aws_secret=uquEhaT6Pt30g+7rliTIrwewoEoebVww0YqWiqxA


#Install CSI Snapshotter
kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -n kube-system -f https://github.com/kubernetes-csi/external-snapshotter/raw/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
kubectl apply -n kube-system -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml

#configure Longhorn backup target and credentials
cat <<EOF | kubectl apply -f -
apiVersion: longhorn.io/v1beta1
kind: Setting
metadata:
  name: backup-target
  namespace: longhorn-system
value: "s3://$s3_bucket@$s3_region/" # backup target here
---
apiVersion: v1
kind: Secret
metadata:
  name: "aws-secret"
  namespace: "longhorn-system"
  labels:
data:
  # echo -n '<secret>' | base64
  AWS_ACCESS_KEY_ID: $(echo -n $aws_key | base64)
  AWS_SECRET_ACCESS_KEY: $(echo -n $aws_secret | base64)
---
apiVersion: longhorn.io/v1beta1
kind: Setting
metadata:
  name: backup-target-credential-secret
  namespace: longhorn-system
value: "aws-secret" # backup secret name here
EOF
