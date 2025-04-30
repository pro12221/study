# 私有仓库gitlab
`gitlab-ce` 开源版本
`gitlab-ee` 企业版本
## gitlab的部署
docker部署gitlab：https://developer.aliyun.com/article/922952
```
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh |sudo bash
sudo apt-get install gitlab-ce
```
## 配置gitlab
配置文件位置：/etc/gitlab/gitlab.rb
```
1.配置域名
external_url 'http://192.168.44.20'
2.配置ssh
gitlab_rails['gitlab_ssh_host'] = '192.168.44.20'
gitlab_rails['gitlab_shell_ssh_port'] = 22022
```

## gitlab常用命令
```
sudo gitlab-ctl stop //--停止服务
sudo gitlab-ctl reconfigure //--启动服务
sudo gitlab-ctl restart //--重启所有gitlab组件
sudo gitlab-ctl start //--启动所有gitlab组件
```
## 启动成功后
启动成功后，默认有个管理员账号

登录名：root

登录密码：初始密码在这个文件中/etc/gitlab/initial_root_password (可更改)

## 克隆
```
git clone http://192.168.44.20/root/project.git
输入账号密码....
```

## gitlab账号的权限
```
Maintainer:推送保护分支、管理 CI/CD
Developer:推送非保护分支、创建 MR
Owner:删除项目、管理成员、修改设置
Reporter:只读访问 + 创建 Issue
Guest:仅查看项目
```