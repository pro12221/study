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
