## gitlab上传项目
![[Pasted image 20250503103844.png]]
 ## 修改Jenkins执行用户为root
 ```shell
cat  /lib/systemd/system/jenkins.service
User=root
Group=root
systemctl daemon-reload 
systemctl restart jenkins.service
```
## jenkins 创建凭据
![[Pasted image 20250503155629.png]]
## gitlab上传ansible的playbook和服务配置文件
```shell
cat  playbook.yml 
- hosts: all
  tasks:
    - name: copy file
      copy:
        src: web
        dest: /usr/local/web
        mode: 0777
    - name: configure
      copy: 
       src: web.service
       dest: /lib/systemd/system/web.service
    - name: reload systemd
      shell: systemctl daemon-reload
    - name: start service
      systemd:
        name: web
        state: started
        enabled: yes

cat web.service 
[Unit]
Description=webgo

[Service]
ExecStart=/usr/local/web
Restart=on-failure

[Install]
WantedBy=multi-user.target

git add . 
git commit -m "111"
git push
```
 ## jenkins设置流水线
 ### Jenkins和node节点设置免密
 ```shell
 ssh-keygen -t rsa -b 4096 -N ""
 ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.44.12
```
### 配置流水线
![[Pasted image 20250503165442.png]]
![[Pasted image 20250503165450.png]] 