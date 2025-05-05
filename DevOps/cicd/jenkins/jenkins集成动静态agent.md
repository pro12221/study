## Jenkins集成静态agent
### 基于ssh方式
首先在agent上安装java环境
![[Pasted image 20250503222722.png]]
![[Pasted image 20250503222802.png]]
![[Pasted image 20250503222822.png]]
#### 删除节点
![[Pasted image 20250503223030.png]]
![[Pasted image 20250503223046.png]]
### 基于javaweb

![[Pasted image 20250503224532.png]]
配置systemd服务管理agent程序
```shell
cat  /lib/systemd/system/jenkins-agent.service
[Unit]
Description=jenkins-agent
After=network.target auditd.service

[Service]
ExecStart=/opt/agent.sh
Restart=on-failure
StandardOutput=file:/var/log/jenkins-agent.log
StandardError=file:/var/log/jenkins-agent-error.log
[Install]
WantedBy=multi-user.target
cat /opt/agent.sh
#!/bin/bash
java -jar /opt/agent.jar -url http://192.168.44.11:8080/ -secret 20a705780d66c46507c5755031b43da83832b530394821bc7ecd4527f27a0bf4 -name node3 -webSocket -workDir "/opt"
```
## 基于docker的实现
### 创建容器
```shell
docker run -tid jenkins/inbound-agent
```
### jenkins 上创建node
![[Pasted image 20250504102955.png]]
此镜像是已Jenkins用户运行，无法装包和其他操作
### 定制镜像(ansible)
```dockerfile
FROM jenkins/inbound-agent
USER root:root
RUN apt-get update&&apt-get install -y ansible
```
### 使用命令创建agent
```shell
docker run --name did -v /var/lib/jenkins:/home/jenkins -v /etc/localtime:/etc/localtime --init jenkins/inbound-agent -url http://192.168.44.11:8080 -tunnel 192.168.44.11:50000 -workDir=/home/jenkins/agent 0778addef6f227676b4b6921f58ddc89ae13b234dba92a93320acf1a6bc32daf did
```

## 动态agent
###  docker in docker
参考链接：https://cloud.tencent.com/developer/article/1697053
**使用[/var/run/docker.sock]的Docker中运行Docker**
![[Pasted image 20250504190733.png]]
####  定义did的dockerfile
```dockerfile
FROM jenkins/inbound-agent
USER root:root
RUN apt-get update&&apt-get install -y docker.io && apt clean
```
####  创建镜像并测试
```shell
docker run -v /var/run/docker.sock:/var/run/docker.sock -ti did /bin/sh

docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED         STATUS         PORTS     NAMES
91b135863b9d   did       "/usr/local/bin/jenk…"   4 seconds ago   Up 4 seconds             musing_gates
```


### 创建动态agent的步骤
#### docker配置调整
```shell
vim /lib/systemd/system/docker.service ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:4243 -H unix:///var/run/docker.sock
systemctl daemon-reload
systemctl restart docker
```
####  配置jenkins以启动docker
![[Pasted image 20250504201642.png]]
![[Pasted image 20250504201659.png]]

这部分只需要配置docker 的url即可,实际ip端口根据需要替换

![[Pasted image 20250504201730.png]]
然后配置docker agent 模版，如下几个点需要配置，如果你同样使用habor还需要配置仓库的账户密码
![[Pasted image 20250504201744.png]]
## 基于k8s的agent
![[Pasted image 20250505103257.png]]
