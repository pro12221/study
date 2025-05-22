# 存储
创建eks后会生成一个StorageClass
```yaml
apiVersion: v1
items:
- apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    annotations:
      kubectl.kubernetes.io/last-applied-configuration: |
        {"apiVersion":"storage.k8s.io/v1","kind":"StorageClass","metadata":{"annotations":{},"name":"gp2"},"parameters":{"fsType":"ext4","type":"gp2"},
"provisioner":"kubernetes.io/aws-ebs","volumeBindingMode":"WaitForFirstConsumer"}
    creationTimestamp: "2025-05-19T03:59:20Z"
    name: gp2
    resourceVersion: "270"
    uid: 17e295ae-4eaa-438c-b881-cd90df935b0a
  parameters:    #是传递给 `provisioner` 的特定参数，用于配置底层存储卷的属性。
    fsType: ext4
    type: gp2
  provisioner: kubernetes.io/aws-ebs   #定了Kubernetes卷插件，负责动态供应这个 `StorageClass` 定义的存储
  reclaimPolicy: Delete  #存储的回收策略 ，另一个可选值是 `Retain`
  volumeBindingMode: WaitForFirstConsumer #卷绑定模式
kind: List
metadata:
  resourceVersion: ""
```
## 卷绑定模式
`volumeBindingMode: WaitForFirstConsumer`:
- 这是卷绑定模式。它定义了 `PersistentVolume (PV)` 的绑定和动态供应在什么时候发生。
- `WaitForFirstConsumer` (等待第一个消费者)：意味着只有当一个 Pod 实际尝试使用引用了此 `StorageClass` 的 `PVC` 时，`PersistentVolume` 才会开始被动态供应并绑定。
- **重要性：** 对于 AWS EBS 这种**可用区 (AZ) 绑定**的存储，这个模式至关重要。它确保了 EBS 卷会**在与 Pod 所在的可用区相同的可用区内创建**，从而避免了跨可用区访问 EBS 导致失败的问题。
- 另一个可选值是 `Immediate` (立即绑定)，表示 `PV` 会在 `PVC` 创建后立即被动态供应和绑定，不考虑 Pod 的调度位置。这不适用于 EBS 等 AZ 绑定的存储类型。
## 对接后端存储
在eks中有默认的sc，此时只需创建pvc(pvc不允许edit)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc01-ebs
spec:
  storageClassName: gp2
  volumeMode: Filesystem  #文件系统类型挂载
  accessModes:
    - ReadWriteOnce  #只允许一个pod读写
  resources:
    requests:
      storage: 5Gi
```
## pod引用pvc
```
apiVersion: v1
kind: Pod # 资源类型为 Pod
metadata:
  name: my-web-server-pod # Pod 的名称
spec:
  containers:
  - name: web-container # 容器的名称
    image: nginx:latest # 使用 Nginx 镜像作为示例
    ports:
    - containerPort: 80
    volumeMounts: # 卷挂载点：将 PVC 提供的存储挂载到容器内部的路径
    - name: my-storage-volume # <-- 这里的名称必须和下面的 spec.volumes[] 中的 name 对应
      mountPath: /usr/share/nginx/html # <-- 存储卷在容器内部的挂载路径，Nginx 会在这里提供文件服务
      readOnly: false # 可选，如果需要只读挂载，设为 true

  volumes: # Pod 级别的卷定义：声明 Pod 将使用哪些卷
  - name: my-storage-volume # <-- 卷的名称，供 volumeMounts 引用
    persistentVolumeClaim: # 指定这是一个 PersistentVolumeClaim 类型的卷
      claimName: pvc01-ebs # <-- 核心：引用你想要使用的 PVC 的名称
```
