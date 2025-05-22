# service
- ClusterIP：用于在集群内部互相访问的场景，通过ClusterIP访问Service。
- NodePort：用于从集群外部访问的场景，通过节点上的端口访问Service，详细介绍请参见[NodePort类型的Service](https://support.huaweicloud.com/basics-cce/kubernetes_0024.html#kubernetes_0024__section1175215413159)。
- LoadBalancer：用于从集群外部访问的场景，其实是NodePort的扩展，通过一个特定的LoadBalancer访问Service，这个LoadBalancer将请求转发到节点的NodePort，而外部只需要访问LoadBalancer，详细介绍请参见[LoadBalancer类型的Service](https://support.huaweicloud.com/basics-cce/kubernetes_0024.html#kubernetes_0024__section7151144411279)。
- Headless Service：用于Pod间的互相发现，该类型的Service并不会分配单独的ClusterIP， 而且集群也不会为它们进行负载均衡和路由。您可通过指定spec.clusterIP字段的值为“None”来创建Headless Service，详细介绍请参见[Headless Service](https://support.huaweicloud.com/basics-cce/kubernetes_0024.html#kubernetes_0024__section10301171915541)。

# 公有云创建ingress
EKS在k8s集群中创建ingress-nginx并对接后端svc
## AWS负载均衡类型
- **Classic Load Balancer (CLB) - 传统负载均衡器**  **第 4 层 (TCP) 和 第 7 层 (HTTP/HTTPS)**。
- **Application Load Balancer (ALB) - 应用负载均衡器**  **第 7 层 (HTTP/HTTPS)**
- **Network Load Balancer (NLB) - 网络负载均衡器**   第 4 层 (TCP/UDP/TLS)
- **Gateway Load Balancer (GWLB) - 网关负载均衡器**  第 3 层/第 4 层 (IP)


## 部署一个示例后端应用
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 2 # 可以根据需要调整副本数
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest # 使用最新的 Nginx 镜像
        ports:
        - containerPort: 80 # Nginx 默认监听 80 端口

---

apiVersion: v1
kind: Service
metadata:
  name: my-nginx-service # Service 的名称
  labels:
    app: nginx
spec:
  selector:
    app: nginx # 选择带有 app=nginx 标签的 Pod
  ports:
  - protocol: TCP
    port: 80 # Service 监听的端口
    targetPort: 80 # 流量转发到 Pod 的哪个端口
  type: ClusterIP # 使用 ClusterIP 类型，Ingress Controller 会直接访问这个 Service
```
## k8s中部署ingress-nginx
```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
```
查看`ingress-nginx` Service 的状态
```bash
kubectl get svc -n ingress-nginx
NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP                                                                   PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.100.135.238   a8ec8ea373f1241cf9e150659883a225-583513922.ap-southeast-1.elb.amazonaws.com   80:31986/TCP,443:31445/TCP   50m
```
## 创建ingress资源
创建 Ingress 资源来定义路由规则，告诉 `ingress-nginx` 如何把流量从 Load Balancer 转发到你的 `my-nginx-service`。
```yaml
cat ingress.yml 
apiVersion: networking.k8s.io/v1 # Ingress API 版本
kind: Ingress
metadata:
  name: my-app-ingress # Ingress 资源的名称
  # annotations:
    # kubernetes.io/ingress.class: nginx # 旧版本的 Ingress 指定控制器方式
spec:
  ingressClassName: nginx # 新版本指定 Ingress Controller 的方式，对应 Helm Chart 安装时注册的 IngressClass
  rules:
  - # host: myapp.example.com # 可选：如果需要按域名路由，在这里指定域名
    http:
      paths:
      - path: /test # 外部访问路径，例如访问 Load Balancer 的 /test 路径
        pathType: Prefix # 匹配路径的方式：Prefix (前缀匹配), Exact (精确匹配), ImplementationSpecific (实现自定义)
        backend: # 流量转发到的后端服务
          service:
            name: my-nginx-service # 后端 Service 的名称
            port:
              number: 80 # 后端 Service 的端口
```
## 注意事项
Ingress转发策略中的path路径要求后端应用内存在相同的路径，否则转发无法生效。
例如，Nginx应用默认的Web访问路径为“/usr/share/nginx/html”，在为Ingress转发策略添加“/test”路径时，需要应用的Web访问路径下也包含相同路径，即“/usr/share/nginx/html/test”，否则将返回404。
## 在EKS上部署ingress
```yaml
# 示例 values.yaml 文件的结构
controller:
  service:
    # Service 的类型，通常是 LoadBalancer
    type: LoadBalancer
    # Service 的端口配置
    ports:
      http: 80
      https: 443
    # >>> 这是用来控制 AWS ELB 类型的关键部分 <<<
    annotations:
      # AWS 特定的注解，用来控制 ELB 的行为
      # 例如：
      # service.beta.kubernetes.io/aws-load-balancer-type: nlb  # 指定创建 NLB
      # service.beta.kubernetes.io/aws-load-balancer-scheme: internal # 创建内部 ELB
      # service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip # NLB 目标类型为 IP
      # ... 还有很多其他 ALB 或 NLB 的注解
    # 其他 Service 配置，比如 LoadBalancer IP (通常不指定，让 AWS 分配)
    # loadBalancerIP: ""

  # 控制器 Pod 的副本数
  replicaCount: 2

  # 控制器 Pod 的资源限制和请求
  resources:
    requests:
      cpu: 100m
      memory: 100Mi
    limits:
      cpu: 200m
      memory: 200Mi

  # 其他控制器相关的配置，如日志级别、健康检查路径等
  # ...

# 如果需要配置默认后端 (例如一个 404 页面服务)，可以在这里配置
# defaultBackend:
#   enabled: true
#   replicaCount: 1
#   image: ...
```

# 原理
- **入口点：** 外部流量首先到达暴露 `ingress-nginx-controller` Pods 的 Service (通常是 `LoadBalancer` 或 `NodePort` 类型)。这个 Service 将流量负载均衡到多个 `ingress-nginx-controller` Pod 实例上（如果 Controller 本身是多副本部署的话）。
- **第一层负载均衡 (可选，针对 Controller Pods)：** 如果 `ingress-nginx-controller` 通过 `LoadBalancer` Service 暴露，那么云提供商的负载均衡器会对 `ingress-nginx-controller` Pods 进行第一层负载均衡。
- **第二层负载均衡 (Nginx 内部)：** 每个 `ingress-nginx-controller` Pod 内部的 Nginx 实例，根据从 `Endpoints` 获取的后端 Pod IP 列表，对实际的应用 Pod 进行第二层负载均衡。
- **动态性：** 整个过程是动态的。当应用 Pod 扩缩容、上线或下线时，`Endpoints` 对象会更新，`ingress-nginx` Controller 会检测到这些变化，更新 Nginx 配置中的 `upstream` 列表，并热加载 Nginx。
# AWS上ingress-nginx对接NLB
默认ingress对接的是classes类型的负载均衡器
```
修改Helm的value.yaml文件
添加注解
service.annotations下
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-subnets: "subnet-xxxxxxxxxxxxxxxxx,subnet-yyyyyyyyyyyyyyyyy,subnet-zzzzzzzzzzzzzzzzz" #指定子网
```
然后更新helm的value文件