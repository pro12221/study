在 Kubernetes 中，创建 Deployment 的底层流程涉及多个组件的协同工作，包括 ​**​API Server、Controller Manager、Scheduler、kubelet​**​ 等。以下是详细的底层原理和流程：

---

## ​**​1. 用户提交 Deployment 配置​**​

当用户执行 `kubectl apply -f deployment.yaml` 时：

1. ​**​kubectl​**​ 将 YAML 转换为 JSON 格式的请求。
2. 请求发送到 ​**​Kubernetes API Server​**​（kube-apiserver）。

---

## ​**​2. API Server 处理请求​**​

1. ​**​认证（Authentication）​**​
    - 检查用户身份（如 kubeconfig 中的证书、Token 或 OAuth）。
2. ​**​鉴权（Authorization）​**​
    - 检查用户是否有权限创建 Deployment（如 RBAC 规则）。
3. ​**​准入控制（Admission Control）​**​
    - 执行默认值注入（如 `MutatingAdmissionWebhook`）。
    - 验证资源合法性（如 `ValidatingAdmissionWebhook`）。
4. ​**​持久化存储​**​
    - 将 Deployment 对象存入 ​**​etcd​**​（Kubernetes 的分布式键值存储）。

---

## ​**​3. Deployment Controller 监听并处理​**​

1. ​**​Deployment Controller​**​（在 `kube-controller-manager` 中运行）通过 ​**​Informer​**​ 监听 API Server 的 Deployment 变更事件。
2. 检测到新 Deployment 后，执行以下逻辑：
    - ​**​计算期望状态（Desired State）​**​  
        根据 `replicas` 和 `template` 确定需要多少 Pod。
    - ​**​创建 ReplicaSet​**​
        - 生成一个唯一的 ReplicaSet（名称包含哈希，如 `my-app-deployment-59d8c5f96b`）。
        - 该 ReplicaSet 的 `spec` 继承自 Deployment 的 `template`。
        - 将 ReplicaSet 写入 etcd（通过 API Server）。

---

## ​**​4. ReplicaSet Controller 接管​**​

1. ​**​ReplicaSet Controller​**​（也在 `kube-controller-manager` 中）监听 ReplicaSet 变更。
2. 发现新 ReplicaSet 后：
    - ​**​比较当前 Pod 数量 vs 期望数量​**​  
        如果当前 Pod 数 < `replicas`，则调用 API Server 创建 Pod。
    - ​**​创建 Pod 对象​**​
        - Pod 的 `spec` 来自 ReplicaSet 的 `template`。
        - Pod 的 `metadata.ownerReferences` 指向 ReplicaSet（表明归属关系）。

---

## ​**​5. Scheduler 分配节点​**​

1. ​**​Pod 进入 Pending 状态​**​，等待调度。
2. ​**​kube-scheduler​**​ 监听未调度的 Pod，执行调度决策：
    - ​**​过滤（Filtering）​**​  
        排除不符合条件的节点（如资源不足、节点亲和性不匹配）。
    - ​**​打分（Scoring）​**​  
        选择最优节点（如资源利用率最低的节点）。
3. ​**​绑定 Pod 到节点​**​
    - 更新 Pod 的 `spec.nodeName` 为目标节点。
    - 写入 etcd。

---

## ​**​6. kubelet 运行 Pod​**​

1. 目标节点的 ​**​kubelet​**​ 监听 API Server，发现分配给它的 Pod。
2. ​**​拉取镜像​**​
    - 通过容器运行时（如 containerd、Docker）拉取镜像。
    - 如果使用私有仓库，需凭据（`imagePullSecrets`）。
3. ​**​创建容器​**​
    - 调用 CRI（Container Runtime Interface）创建容器。
    - 设置网络（CNI 插件）和存储（CSI 插件）。
4. ​**​更新 Pod 状态​**​
    - 将 Pod 状态改为 `Running`，并上报给 API Server。

---

## ​**​7. 持续监控与调和（Reconciliation）​**​

- ​**​Deployment Controller​**​ 持续检查当前状态是否匹配期望状态：
    - 如果 Pod 崩溃，ReplicaSet Controller 会重新创建。
    - 如果用户更新 Deployment（如修改镜像），会触发滚动更新（新建 ReplicaSet，逐步替换旧 Pod）。
- ​**​kubelet​**​ 定期上报 Pod 健康状态，确保高可用。