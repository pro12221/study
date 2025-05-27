# 解决 SSH 主机密钥变更警告的方法

## 问题描述
当连接远程服务器时出现以下警告：

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED! @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## 解决方案

### 方法1：删除旧密钥（推荐）
```bash
ssh-keygen -R 192.168.10.146
​​作用​​：从~/.ssh/known_hosts中清除指定IP的旧密钥记录
​​安全等级​​：★★★★★
```
### 方法2：手动编辑known_hosts文件
```bash
sed -i '2d' ~/.ssh/known_hosts
​​说明​​：直接删除报错提示的行号（示例中为第2行）
​​适用场景​​：精确删除特定记录
```
### 方法3：临时跳过验证（仅测试环境）
```bash
ssh -o StrictHostKeyChecking=no root@192.168.10.146
⚠️ ​​警告​​：会禁用主机密钥验证，存在安全风险
```
### 方法4：强制更新密钥
```bash
ssh-keyscan -H 192.168.10.146 >> ~/.ssh/known_hosts
​​作用​​：强制获取新密钥并写入known_hosts
```
### 问题根源
原因	典型场景
服务器重装系统	新系统生成的SSH密钥不同
IP地址被重新分配	该IP现在指向不同服务器
服务器硬件更换	主板/SSD更换导致密钥变更
永久解决方案
​​服务器端配置​​：
```bash
sudo ssh-keygen -A
sudo systemctl restart sshd
```
​​客户端预分发公钥​​：
```bash
ssh-keyscan 192.168.10.146 >> ~/.ssh/known_hosts
```
验证方法
```bash
ssh -v root@192.168.10.146
```

