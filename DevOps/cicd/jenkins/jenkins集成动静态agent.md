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
