# 创建configmap
## 命令方式创建
```shell
kubectl create configmap my-config   --from-literal=APP_COLOR=blue   --from-literal=APP_MODE=prod --dry-run=client -o yaml
apiVersion: v1
data:
  APP_COLOR: blue
  APP_MODE: prod
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: my-config
```
## 从文件创建
```shell
创建临时 YAML 文件头
/root/os.sh是要引用的文件
cat <<EOF > configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: test
data:
  nginx.conf: |
$(sed 's/^/    /' /root/os.sh)   
EOF

# 应用 ConfigMap
kubectl apply -f configmap.yaml
```
##  通过 YAML 文件声明式创建​
```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: game-config
data:
  # 键值对形式
  PLAYER_INITIAL_LIVES: "3"
  UI_PROPERTIES_FILE_NAME: "user-interface.properties"
  
  # 文件内容形式
  game.properties: |
    enemy.types=aliens,monsters
    player.maximum-lives=5    
```
# 使用 ConfigMap
## 作为环境变量注入容器​
```yaml
创建configmap

apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  APP_COLOR: "123456"
  bbb: "2222"

创建pod

apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
    - name: my-container
      image: nginx
      envFrom:  # 全部键值对注入
        - configMapRef:
            name: my-config
      env:      # 选择性注入
        - name: APP_COLOR
          valueFrom:
            configMapKeyRef:
              name: my-config
              key: APP_COLOR

```

```shell
root@master:~# kubectl exec my-pod -- env | grep APP_
APP_COLOR=123456
root@master:~# kubectl exec my-pod -- env | grep bbb
bbb=2222
```
## **挂载为容器内的文件​**
ConfigMap 中的每个键会生成一个文件，内容为对应值
```yaml
configmap引用上面的
pod创建如下
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
    - name: my-container
      image: nginx
      imagePullPolicy: IfNotPresent
      volumeMounts:
        - name: config-volume
          mountPath: /etc/config
  volumes:
    - name: config-volume
      configMap:
        name: my-config  # 使用之前创建的 ConfigMap
```
## **作为命令行参数传递​**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
    - name: my-container
      image: nginx
      command: ["/bin/sh", "-c", "echo $(APP_COLOR)"]
      env:
        - name: APP_COLOR
          valueFrom:
            configMapKeyRef:
              name: my-config
              key: APP_COLOR
```

# secret
## Secret 类型
Kubernetes 提供多种 Secret 类型：
- ​**​Opaque​**​ (默认类型)：任意用户定义的数据
- ​**​kubernetes.io/service-account-token​**​：服务账号令牌
- ​**​kubernetes.io/dockercfg​**​：`~/.dockercfg` 文件的序列化形式
- ​**​kubernetes.io/dockerconfigjson​**​：`~/.docker/config.json` 文件的序列化形式
- ​**​kubernetes.io/basic-auth​**​：用于基本身份认证的凭据
- ​**​kubernetes.io/ssh-auth​**​：用于 SSH 身份认证的凭据
- ​**​kubernetes.io/tls​**​：用于 TLS 客户端或服务器端的数据
## 命令创建secret
### generic格式
```shell
kubectl create secret generic my-secret --from-literal=password='123456' --dry-run=client -o yaml
```
### tls格式
####  使用 kubectl 命令创建

```shell
kubectl create secret tls my-tls-secret --cert=/root/ca/nginx.pem --key=/root/ca/nginx-key.pem
```
#### pod挂载tls的方法
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: my-container
    image: nginx
    volumeMounts:
    - name: tls-secret
      mountPath: "/etc/ssl/certs"
      readOnly: true
  volumes:
  - name: tls-secret
    secret:
      secretName: my-tls-secret
```
#### Ingress挂载方法
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  tls:
  - hosts:
    - mydomain.com
    secretName: my-tls-secret
  rules:
  - host: mydomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```
## docker-registry类型
### 使用命令行创建
```shell
kubectl create secret docker-registry my-registry-secret \
  --docker-server=registry.example.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=myuser@example.com
```
###  在 Pod 中指定 imagePullSecrets
```shell
apiVersion: v1
kind: Pod
metadata:
  name: private-reg-pod
spec:
  containers:
  - name: private-reg-container
    image: registry.example.com/private/image:tag
  imagePullSecrets:
  - name: my-registry-secret
```
### 在 Deployment 中使用
```shell
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        image: registry.example.com/private/image:tag
      imagePullSecrets:
      - name: my-registry-secret
```
