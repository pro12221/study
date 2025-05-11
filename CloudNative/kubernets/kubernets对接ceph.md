# ceph创建存储池
```shell
 ceph osd pool create k8s-rbd01  创建存储池
 ceph osd  pool  application  enable  k8s-rbd01 rbd 给存储池打标签
 rbd pool init k8s-rbd01  存储池初始化为rbd池#
 ceph auth get-or-create client.k8s-rbd01 mon 'profile rbd' osd 'profile rbd pool=k8s-rbd01' mgr 'profile rbd pool=k8s-rbd01'  创建一个ceph用户用于访问该存储池
```
# k8s下载ceph-csi插件
```shell
wget https://github.com/ceph/ceph-csi/archive/refs/tags/v3.13.1.tar.gz && tar -xzvf v3.13.1.tar.gz
修改csi-config-map.yaml文件
修改/root/ceph-csi-3.13.1/deploy/rbd/**kubernetes/csi-config-map.yaml
==将fsid替换为“clusterID”，将监视器地址替换为“monitors”==
cat <<EOF > csi-config-map.yaml
---
apiVersion: v1
kind: ConfigMap
data:
  config.json: |-
    [
      {
        "clusterID": "d5a54986-2a7a-11f0-ba91-000c29927be4",
        "monitors": [
          "192.168.44.41:6789"
        ]
      }
    ]
metadata:
  name: ceph-csi-config
EOF
```
# 修改其他文件
```shell
cat <<EOF > csi-kms-config-map.yaml
---
apiVersion: v1
kind: ConfigMap
data:
  config.json: |-
    {}
metadata:
  name: ceph-csi-encryption-kms-config
EOF




cat <<EOF > ceph-config-map.yaml
---
apiVersion: v1
kind: ConfigMap
data:
  ceph.conf: |
    [global]
    auth_cluster_required = cephx
    auth_service_required = cephx
    auth_client_required = cephx
  # keyring is a required key and its value should be empty
  keyring: |
metadata:
  name: ceph-config
EOF





cat <<EOF > csi-rbd-secret.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: csi-rbd-secret
  namespace: ceph-csi
stringData:
  userID: k8s-rbd01
  userKey: AQDsGRpoBu0lGxAAIhTIYQ9rXkpD4xJfdrDLig==      ceph中用户的key 通过ceph auth get client.k8s-rbd01查询
EOF
```
# 配置 ceph-csi 插件
```shell
grep "namespace: default" csi-provisioner-rbac.yaml csi-rbdplugin-provisioner.yaml csi-nodeplugin-rbac.yaml csi-rbdplugin.yaml
csi-provisioner-rbac.yaml:  namespace: default
csi-provisioner-rbac.yaml:    namespace: default
csi-provisioner-rbac.yaml:  namespace: default
csi-provisioner-rbac.yaml:  namespace: default
csi-provisioner-rbac.yaml:    namespace: default
csi-rbdplugin-provisioner.yaml:  namespace: default
csi-rbdplugin-provisioner.yaml:  namespace: default
csi-nodeplugin-rbac.yaml:  namespace: default
csi-nodeplugin-rbac.yaml:    namespace: default
csi-rbdplugin.yaml:  namespace: default
csi-rbdplugin.yaml:  namespace: default

将这些配置文件中的命名空间修改
sed -i 's/namespace: default/namespace: ceph-csi/g' csi-provisioner-rbac.yaml csi-rbdplugin-provisioner.yaml csi-nodeplugin-rbac.yaml csi-rbdplugin.yaml

kubectl create namespace ceph-csi

kubectl apply -f csi-rbd-secret.yaml -n ceph-csi
kubectl apply -f ceph-config-map.yaml -n ceph-csi
kubectl apply -f csi-kms-config-map.yaml -n ceph-csi
kubectl apply -f csi-config-map.yaml -n ceph-csi


kubectl apply -f csi-provisioner-rbac.yaml -n ceph-csi
kubectl apply -f csi-nodeplugin-rbac.yaml  -n ceph-csi
kubectl apply -f csi-rbdplugin-provisioner.yaml -n ceph-csi
kubectl apply -f csi-rbdplugin.yaml -n ceph-csi
```

# 使用ceph块设备
## 创建 StorageClass
```shell
cat <<EOF > csi-rbd-sc.yaml
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: csi-rbd-sc
provisioner: rbd.csi.ceph.com
parameters:
   clusterID: d5a54986-2a7a-11f0-ba91-000c29927be4   #ceph的id
   pool: k8s-rbd01
   imageFeatures: layering
   csi.storage.k8s.io/provisioner-secret-name: csi-rbd-secret
   csi.storage.k8s.io/provisioner-secret-namespace: ceph-csi
   csi.storage.k8s.io/controller-expand-secret-name: csi-rbd-secret
   csi.storage.k8s.io/controller-expand-secret-namespace: ceph-csi
   csi.storage.k8s.io/node-stage-secret-name: csi-rbd-secret
   csi.storage.k8s.io/node-stage-secret-namespace: ceph-csi
reclaimPolicy: Delete
allowVolumeExpansion: true
mountOptions:
   - discard
EOF
kubectl apply -f csi-rbd-sc.yaml
```
## 创建pvc
```shell
cat rbd-pvc.yaml 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rbd-pvc
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 4Gi
  storageClassName: csi-rbd-sc
```
## 创建pod
```shell
cat pod.yaml 
apiVersion: v1
kind: Pod
metadata:
  name: csi-rbd-demo-pod
spec:
  containers:
    - name: web-server
      image: nginx
      volumeMounts:
        - name: mypvc
          mountPath: /tmp
  volumes:
    - name: mypvc
      persistentVolumeClaim:
        claimName: rbd-pvc
        readOnly: false
```
# 问题
```
kubectl get pods -n ceph-csi -o wide
NAME                                         READY   STATUS    RESTARTS   AGE   IP               NODE     NOMINATED NODE   READINESS GATES
csi-rbdplugin-bvz29                          3/3     Running   0          12m   192.168.44.33    node2    <none>           <none>
csi-rbdplugin-gmm8s                          3/3     Running   0          12m   192.168.44.32    node1    <none>           <none>
csi-rbdplugin-provisioner-58564ccb5d-4z6mj   7/7     Running   0          12m   100.66.209.199   node1    <none>           <none>
csi-rbdplugin-provisioner-58564ccb5d-lmrzd   7/7     Running   0          12m   100.108.11.204   node2    <none>           <none>
csi-rbdplugin-provisioner-58564ccb5d-ltwvm   0/7     Pending   0          12m   <none>           <none>   <none>           <none>
```
发现有一个csi-rbdplugin-provisioner-58564ccb5d-ltwvm一直处于pending状态，原因是因为master节点的污点，要么删除这个pending的pod并讲deploy改为2副本，要么容忍控制平面污点
如果确实需要调度到 master 节点，修改 CSI Provisioner 的 Deployment，添加容忍：
在 `spec.template.spec` 部分添加
```
tolerations:
- key: "node-role.kubernetes.io/control-plane"
  operator: "Exists"
  effect: "NoSchedule"
```
