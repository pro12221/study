publish Cloud Native packages
https://artifacthub.io/
 
 # 安装helm
下载链接：https://github.com/helm/helm/releases
```shell
wget https://get.helm.sh/helm-v3.17.0-linux-amd64.tar.gz
tar -zxvf helm-v3.17.0-linux-amd64.tar.gz
cd linux-amd64 && mv helm /usr/bin
helm completion bash > ~/.helm
helm completion bash > ~/.helmrc
echo "source ~/.helmrc" >> ~/.bashrc 
source ~/.bashrc
```
# 命令
```
helm list -A # 列出所有命名空间的 Release
helm pull ingress-nginx/ingress-nginx #拉取chat包
helm search repo ingress-nginx --versions #查看可用版本
helm search repo <关键词> #本地仓库查找chat
helm rollback <release名称> -n <命名空间> #回滚
helm rollback <release名称> 0 -n <命名空间> # '0' 代表回滚到前一个版本
helm upgrade <release名称> <chart名称> --description "您的描述信息" [其他参数和标志]
```
# Helm安装ingress后修改
```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm list -A #查看ingress版本
helm pull ingress-nginx/ingress-nginx --version=1.12.2
修改配置文件（省略）
helm upgrade ingress-nginx ./ -f values.yaml --namespace ingress-nginx  --description "您的描述信息"  #更新
```
