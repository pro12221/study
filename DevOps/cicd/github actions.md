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
前端页面开发： 准备一个简单的 HTML/CSS/JS 页面。
GitHub 仓库设置： 创建仓库并上传代码。
Docker 化应用程序： 编写 Dockerfile。
AWS ECR 仓库设置： 创建 ECR 仓库来存储 Docker 镜像。
AWS EKS 集群准备： 确保 EKS 集群已运行，并安装 Ingress-Nginx Controller。
Kubernetes Manifests 准备： 编写 Deployment, Service 和 Ingress 定义。
AWS IAM 配置： 为 GitHub Actions 配置 IAM 角色 (通过 OIDC)。
GitHub Actions 工作流设计： 编写 CI/CD YAML，实现构建、推送镜像到 ECR，并部署到 EKS。





name: Deploy Frontend to EKS # 工作流名称

on: # 触发工作流的事件
  push:
    branches:
      - main # 当代码推送到 main 分支时触发

  workflow_dispatch: {} # 允许手动触发


env: # 定义环境变量
  AWS_REGION: ap-southeast-1                   # 替换为您的 AWS 区域
  EKS_CLUSTER_NAME: eks-test    # 替换为您的 EKS 集群名称
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


      - name: Build and push Docker image to ECR # 构建 Docker 镜像并推送到 ECR
        id: build-image # 为此步骤设置 ID
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }} # 从登录步骤获取 ECR 注册表 URI
          IMAGE_TAG: ${{ github.sha }} # 使用 commit SHA 作为镜像标签，确保唯一性
        run: |
          # 构建 Docker 镜像
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG -f my-frontend-app/Dockerfile my-frontend-app/
          # 为方便起见，也打一个 latest 标签 (如果 ECR 仓库设置为 mutable 且您需要 latest)
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest

          # 推送 Docker 镜像
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest # 如果需要

          # 将完整的镜像 URI 输出，供后续步骤使用
          echo "FULL_IMAGE_URI=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_ENV

      - name: Set up Kubeconfig for EKS # 配置 kubectl 访问 EKS 集群
        uses: aws-actions/configure-aws-credentials@v4 # 再次使用此 Action，用于配置 Kubeconfig
        with:
          aws-region: ${{ env.AWS_REGION }}
          # 使用 GitHub Secrets 获取 Access Key ID
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          # 使用 GitHub Secrets 获取 Secret Access Key
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          cluster-name: ${{ env.EKS_CLUSTER_NAME }} # 自动为集群生成 Kubeconfig

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