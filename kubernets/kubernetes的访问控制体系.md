[]()Kubernetes 的访问控制体系是一个多层次的安全机制，用于确保只有经过授权的用户、服务或系统组件能够访问或操作集群资源。其核心由 ​**​认证（Authentication）、授权（Authorization）、准入控制（Admission Control）​**​ 三大部分组成，并辅以其他安全特性（如网络策略、Secret 管理等）
# kubernetes的三套ca
```shell
ls
apiserver-etcd-client.crt  apiserver-kubelet-client.crt  apiserver.crt  ca.crt  etcd                front-proxy-ca.key      front-proxy-client.key  sa.pub
apiserver-etcd-client.key  apiserver-kubelet-client.key  apiserver.key  ca.key  front-proxy-ca.crt  front-proxy-client.crt  sa.key


ca.crt和ca.key 是kubernetes的ca
front-proxy-ca.key和 front-proxy-ca.crt是前端代理的ca
etcd目录内是etcd的ca
```
 # kubelet的身份认证
```shell
node节点
/var/lib/kubelet/config.yaml 
address: 0.0.0.0
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 2m0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 5m0s
    cacheUnauthorizedTTL: 30s
```

# 静态token认证
静态令牌文件是一个 CSV 文件

```csv
token,username,useruid,group1,group2
```
- ​**​token​**​（必填）：Bearer Token 字符串（如随机生成的密钥）。
- ​**​username​**​（必填）：认证后关联的用户名。
- ​**​useruid​**​（可选）：用户的 UID（字符串形式）。
- ​**​groups​**​（可选）：用户所属的组（多个组用逗号分隔）。
## 创建静态令牌
```
abcdef123456,dev-user,1002,"dev-team,testers"
```
##  **配置 API Server 使用静态令牌文件​**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-apiserver
    - --token-auth-file=/etc/kubernetes/tokens.csv  # 指定令牌文件路径
    # 其他参数...
    volumeMounts:
    - name: token-auth
      mountPath: /etc/kubernetes/tokens.csv
      readOnly: true
  volumes:
	- hostPath:
	   path: /etc/kubernetes/tokens.csv
	   type: File
	  name: token-auth
```
## 使用静态令牌的方法
```shell
kubectl --server=https://192.168.44.31:6443 --insecure-skip-tls-verify=true --token=abcdef123456 get pods Error from server (Forbidden): pods is forbidden: User "dev-user" cannot list resource "pods" in API group "" in the namespace "default" (没有权限)
```
# ​**​X.509 客户端证书**
## **生成客户端证书​、**
```
# 生成私钥
openssl genrsa -out dev-user.key 2048

# 生成证书签名请求（CSR）
openssl req -new -key dev-user.key -out dev-user.csr -subj "/CN=dev-user/O=dev-team"

# 使用 Kubernetes CA 签发证书
openssl x509 -req -in dev-user.csr \
  -CA /etc/kubernetes/pki/ca.crt \
  -CAkey /etc/kubernetes/pki/ca.key \
  -CAcreateserial -out dev-user.crt -days 365
```
## **验证证书内容​**
```
openssl x509 -in dev-user.crt -text -noout
# 输出应包含：
# Subject: CN=dev-user, O=dev-team
# Issuer: CN=kubernetes-ca  # 签发者为 Kubernetes CA
```
# kubeconfig
默认路径：`~/.kube/config`（可通过 `KUBECONFIG` 环境变量修改）
## 基本格式
```
apiVersion: v1
kind: Config
clusters:        # 定义集群信息（如 API Server 地址和 CA 证书）
- name: my-cluster
  cluster: {...}
users:           # 定义用户认证信息（如客户端证书、Token 等）
- name: my-user
  user: {...}
contexts:        # 绑定集群、用户和命名空间
- name: my-context
  context: {...}
current-context: my-context  # 当前使用的上下文
```
## 使用方法
```bash
kubectl get pod --kubeconfig=/etc/kubernetes/admin.conf   使用命令行选项指定config文件
export KUBECONFIG='/etc/kubernetes/admin.conf'  指定环境变量
kubectl config view           显示合并后的配置
kubectl config view --raw     显示原始内容（包括敏感数据）
kubectl config get-clusters --kubeconfig=mycluster.yaml 查看当前kubeconfig中有多少集群
kubectl config get-users --kubeconfig=mycluster.yaml  查看当前kubeconfig中有多少用户
kubectl config current-context 查看当前上下文
kubectl config use-context my-cluster@dev-user 切换当前上下文
```
## 设置kubeconfig文件
```
添加集群
kubectl config set-cluster my-cluster \
  --server=https://192.168.1.100:6443 \
  --certificate-authority=/path/to/ca.crt \
  --embed-certs=true  #隐藏证书敏感信息\
  --kubeconfig=/path/to/your/custom-kubeconfig.yaml
```
```
添加账号
kubectl config set-credentials dev-user --token="abcdef123456"   已token方式认证
```
```
添加上下文
kubectl config set-context my-cluster@dev-user --cluster=my-cluster --user=dev-user  --kubeconfig=mycluster.yaml --namespace=default（namespace是可选项）
```
```shell
删除配置
kubectl config delete-cluster my-cluster
kubectl config delete-user my-user
kubectl config delete-context my-context
```
# Service Account
- ​**​身份标识​**​：为 Pod 提供唯一的身份，用于 API Server 认证。
- ​**​权限控制​**​：通过 RBAC 绑定权限，限制 Pod 能访问的资源。
- ​**​自动化流程​**​：无需手动管理 Token，适合 CI/CD 或控制器等自动化场景。
# RBAC
```
kubectl get pod kube-apiserver-master --namespace kube-system -o yaml
- --authorization-mode=Node,RBAC    这里是apiserver的两种鉴权方式
node 确保每个节点的kubelet仅能访问被调度器绑定到此节点的pod
rbac 基于角色的访问控制
```
## rbac的两个级别
```
名称空间级别:
Role RoleBinding
集群资源级别:
ClusterRole  ClusterRoleBinding
交叉类型：
RoleBinding  ClusterRole
```
## rbac的基本概念
```
实体：在rbac中也称为subject，通常指的是User，Group，或者是ServerAccount
角色：承载资源操作权限的容器
资源：在rbac中称为Object，例如pod，service等
动作：subject可以于object上执行的特定操作
```