# Github Action发布项目到EKS
## k8s滚动更新
```
kubectl set image deployment/my-nginx-deployment nginx-container=nginx:1.21.6
将名为my-nginx-deployment的deployment中的nginx-container容器更新到nginx:1.21.6
kubectl annotate deployment/nginx-deployment kubernetes.io/change-cause="Set image to nginx:1.22.0"
给这次更新添加注解，history中可以显示
```
### rollout使用方法
```
kubectl rollout status <资源类型>/<资源名称>
监视指定资源的滚动更新状态，直到更新完成或失败。

kubectl rollout history <资源类型>/<资源名称>
查看指定资源的部署历史版本

kubectl rollout undo deployment/my-app-deployment --to-revision=2
回滚到指定版本revision=2

```


## github action 模板
```yml
name: Deploy Frontend to EKS # 工作流名称

on: # 触发工作流的事件
  push:
    branches:
      - main # 当代码推送到 main 分支时触发

  workflow_dispatch: {} # 允许手动触发


env: # 定义环境变量
  AWS_REGION: ap-southeast-1                # 替换为您的 AWS 区域
  EKS_CLUSTER_NAME: eks-test     # 替换为您的 EKS 集群名称
  ECR_REPOSITORY: test/testrepo         # 替换为您的 ECR 仓库名称
  # Kubernetes Deployment 和 Service 的 YAML 文件路径
  K8S_MANIFESTS_DIR: my-frontend-app/k8s
  K8S_DEPLOYMENT_FILE: my-frontend-app/k8s/deployment.yaml
  # 任务定义中容器的名称，用于更新镜像标签
  CONTAINER_NAME_IN_K8S_DEPLOYMENT: frontend-app-container # 必须与 k8s/deployment.yaml 中的容器名称匹配


permissions: # 授予工作流运行所需的权限
  contents: read # 允许读取仓库内容
  id-token: write # 允许使用 OIDC 获取 AWS 临时凭证 (关键)

jobs: # 定义工作流中的 Job
  build-and-deploy: # 构建并部署 Job
    runs-on: ubuntu-latest # 在 Ubuntu 虚拟机上运行


    steps: # Job 中的一系列步骤
      - name: Checkout repository 
      # 检出 GitHub 仓库代码，将 GitHub 仓库中的所有代码克隆到工作流运行器上，以便后续的构建和部署步骤能够访问到文件。
        uses: actions/checkout@v4


      - name: Configure AWS credentials (using AK/SK)# 配置 AWS 凭证，使用 AK/SK 方式
        uses: aws-actions/configure-aws-credentials@v4 # 配置AWS凭证
        with:
          aws-region: ${{ env.AWS_REGION }}
          # 使用 GitHub Secrets 获取 Access Key ID
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          # 使用 GitHub Secrets 获取 Secret Access Key
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

       
      #调试步骤
      - name: Debug - Verify AWS credentials and EKS access # <-- 添加这个步骤
        run: |
          echo "Verifying AWS credentials..."
          aws sts get-caller-identity || { echo "ERROR: Failed to get caller identity. Check AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY."; exit 1; }
          echo "AWS credentials verified successfully."

          echo "Attempting to describe EKS cluster: ${{ env.EKS_CLUSTER_NAME }}"
          aws eks describe-cluster --name ${{ env.EKS_CLUSTER_NAME }} --region ${{ env.AWS_REGION }} || { echo "ERROR: Failed to describe EKS cluster. Check IAM permissions for EKS."; exit 1; }
          echo "EKS cluster described successfully. Permissions should be fine."

      

      - name: Login to Amazon ECR # 登录 ECR
        id: login-ecr # 为此步骤设置 ID，以便后续步骤访问其输出
        uses: aws-actions/amazon-ecr-login@v2  #自动登录到Amazon ECR


      - name: Build and push Docker image to ECR
        id: build-image
        env:
          ECR_REGISTRY: 588738573686.dkr.ecr.ap-southeast-1.amazonaws.com  # 硬编码你的 ECR 注册表地址
          ECR_REPOSITORY: test/testrepo  # 硬编码你的 ECR 仓库路径
          IMAGE_TAG: latest  # 自定义镜像标签
        run: |
          # 构建 Docker 镜像（完整路径）
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG -f my-frontend-app/Dockerfile my-frontend-app/

          # 推送镜像（带自定义标签和 latest）
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
      
          # 输出镜像 URI 供后续步骤使用
          echo "FULL_IMAGE_URI=$ECR_REGISTRY/$ECR_REPOSITORY:latest" >> $GITHUB_ENV

      - name: Set up Kubeconfig for EKS
        run: |
          aws eks update-kubeconfig \
            --region ${{ env.AWS_REGION }} \
            --name ${{ env.EKS_CLUSTER_NAME }}

      - name: Install kubectl # 安装 kubectl 命令行工具
        uses: azure/setup-kubectl@v3  #在工作流运行器上安装 kubectl
        with:
          version: 'latest' # 安装最新版 kubectl

      

      # 调试步骤
      - name: Debug - List Kubeconfig contents
        run: |
          cat ~/.kube/config || true # 打印 kubeconfig 内容 (敏感信息，仅用于调试)
          ls -la ~/.kube/ # 确认 kubeconfig 文件存在

      - name: Debug - Test kubectl connection
        run: |
          kubectl cluster-info # 检查是否能连接到集群
          kubectl auth can-i get pods -n default # 检查是否有权限获取 default 命名空间下的 pods

      - name: Debug - List manifest files
        run: ls -la ${{ env.K8S_MANIFESTS_DIR }} # 确认 YAML 文件在正确的位置




      - name: Apply Kubernetes Manifests to EKS # 应用 Kubernetes 配置到 EKS 集群
        run: |
          # 应用所有 k8s 目录下的 YAML 文件
          kubectl apply -f ${{ env.K8S_MANIFESTS_DIR }}
          echo "Kubernetes manifests applied to EKS."





-----------------------------------------------------------------------
      - name: Get Ingress URL # 获取 Ingress 服务的外部 URL
        run: |
          INGRESS_HOSTNAME=$(kubectl get ingress frontend-app-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
          if [ -z "$INGRESS_HOSTNAME" ]; then
            INGRESS_IP=$(kubectl get ingress frontend-app-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
            echo "Frontend app deployed to: http://$INGRESS_IP"
            echo "Frontend app deployed. External IP: $INGRESS_IP"
          else
            echo "Frontend app deployed to: http://$INGRESS_HOSTNAME"
            echo "Frontend app deployed. External Hostname: $INGRESS_HOSTNAME"
          fi


        #- name: Update Kubernetes Deployment with new image # 更新 Deployment YAML 中的镜像标签
        run: |
          # 这是一个示例，使用 kubectl set image 命令直接更新 Deployment 中的容器镜像
          # 这种方法无需修改本地 YAML 文件，直接作用于集群。
          # kubectl set image deployment/frontend-app-deployment \ # 您的 Deployment 名称
                          ${{ env.CONTAINER_NAME_IN_K8S_DEPLOYMENT }}=${{ env.FULL_IMAGE_URI }} \ # 容器名称=新镜像URI
                          -n default # 您的命名空间

          # 如果您需要修改本地 YAML 文件并 apply，可以使用以下方法
          # cp ${{ env.K8S_DEPLOYMENT_FILE }} deployment.yaml # 复制一份，避免直接修改源文件
          # sed -i "s|image: .*my-frontend-eks-repo:latest|image: ${{ env.FULL_IMAGE_URI }}|g" deployment.yaml
          # 然后在 Apply Kubernetes Manifests 步骤中 apply deployment.yaml


      - name: Verify Deployment Rollout Status # 验证 Deployment 是否成功滚动更新
        run: |
          echo "Waiting for frontend-app-deployment rollout to complete..."
          kubectl rollout status deployment/frontend-app-deployment -n default
          echo "Frontend application deployment successful!"
```
# Ingress 模板
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-app-ingress
  namespace: default
  annotations:
    #kubernetes.io/ingress.class: "alb" # 明确指定使用 AWS Load Balancer Controller 创建 ALB
    #alb.ingress.kubernetes.io/scheme: internet-facing # internet-facing 或 internal
    # 如果您有多个 Ingress Controller，可能需要指定 Ingress Class
    # kubernetes.io/ingress.class: "nginx"
spec:
  ingressClassName: nginx # 指定使用 Nginx Ingress Controller
  rules:
   -
      http:
        paths:
          - path: / # 路由所有根路径流量
            pathType: Prefix # 路径匹配类型
            backend:
              service:
                name: frontend-app-service # 指向您的 Service
                port:
                  number: 80 # Service 的端口
```
在 AWS EKS (Elastic Kubernetes Service) 上使用 Ingress 时，Ingress Controller 会根据 Ingress 资源的定义自动为您创建和配置 AWS 负载均衡器 (Load Balancer)。您可以通过在 Ingress 资源或 Service 资源的 **annotations (注解)** 中指定特定的参数来选择和配置 AWS LB 的类型。
## ALB类型
```
annotations:
    kubernetes.io/ingress.class: "alb" # 明确指定使用 AWS Load Balancer Controller 创建 ALB
    alb.ingress.kubernetes.io/scheme: internet-facing # internet-facing 或 internal
    # ... 其他 ALB 相关注解，例如：
    # alb.ingress.kubernetes.io/target-type: ip # 或 instance
    # alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
    # alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account-id:certificate/certificate-id
    # alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-Ext-2018-06
    # alb.ingress.kubernetes.io/healthcheck-path: /healthz
```
- `ip`: 将流量直接路由到 Pod 的 IP 地址。这是推荐的方式，通常与 VPC CNI 配合使用效果更好，性能也更高。
- `instance`: 将流量路由到 NodePort，然后再由 kube-proxy 路由到 Pod。
## NLB类型
`AWS Load Balancer Controller`

