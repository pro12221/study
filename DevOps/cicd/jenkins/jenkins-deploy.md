# 部署和使用jenkins
Jenkins 全知道：https://jenkins.xfoss.com/Ch00_Overview.html
## jenkins架构
```
master节点：核心节点，用来下发任务和检查任务的执行状态，以及提供web界面
slave节点：工作节点，用来负责运行master下发的任务
   静态Slave节点：长期运行的固定节点（物理机、虚拟机或容器）
   动态Slave节点：按需自动创建，任务完成后销毁（如云实例、容器）
```
## 安装jenkins
```
安装jenkins
软件包下载地址：https://pkg.jenkins.io/debian-stable/

wget -O /usr/share/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null
  sudo apt-get update
  sudo apt-get install fontconfig  openjdk-17-jre
  sudo apt-get install jenkins
```
### 安装遇到的问题
```
安装遇到的问题
一直卡在setup wizard，查看下面的链接替换插件源：/var/lib/jenkins/hudson.model.UpdateCenter.xml
https://www.jenkins-zh.cn/tutorial/management/plugin/update-center/
关掉梯子
```
