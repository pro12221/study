# openstack对接ceph
官方文档https://docs.ceph.com/en/latest/rbd/rbd-openstack/#configure-openstack-to-use-ceph

## ceph操作

```bash
yum install ceph-common -y
创建池
ceph osd pool create cinder_pool && ceph osd pool application enable cinder_pool rbd
创建用户
ceph auth get-or-create client.wangshenao mon 'allow rwx' osd 'allow rwx pool=cinder_pool' -o /etc/ceph/ceph.client.wangshenao.keyring
将文件拷贝至控制和计算节点
for i in {48..50}; do  scp /etc/ceph/ceph.conf /etc/ceph/ceph.client.wangshenao.keyring 192.168.10.$i:/etc/ceph/; done
```

## openstack操作

```bash
for i in {48..50}; do ssh root@192.168.10.$i "yum install -y ceph-common"; done
创建 secret 及 key
ceph --id wangshenao auth get-key client.wangshenao > wangshenaokey
uuid=$(uuidgen)
cat > secret.xml <<EOF
<secret ephemeral='no' private='no'>
  <uuid>$uuid</uuid>
  <usage type='ceph'>
    <name>client.wangshenao secret</name>
  </usage>
</secret>
EOF

将控制节点上生成的 secret 和 key 文件拷贝到计算节点
for i in {49..50}; do  scp /root/secret.xml /root/wangshenaokey  root@192.168.10.$i:/root; done

为 secret 设定 key
控制节点和计算节点
for i in {48..50}; do ssh root@192.168.10.$i "secret_uuid=\$(virsh secret-define --file secret.xml | awk '{print \$2}') && virsh secret-set-value --secret \$secret_uuid --base64 \$(cat wangshenaokey)"; done

修改控制节点cinder配置文件
vim /etc/cinder/cinder.conf
[DEFAULT]
enabled_backends = lvm,ceph

***在配置文件末尾添加以下行***

[ceph]
volume_driver = cinder.volume.drivers.rbd.RBDDriver
volume_backend_name = ceph
rbd_pool = pool01
rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_flatten_volume_from_snapshot = false
rbd_max_clone_depth = 5
rbd_store_chunk_size = 4
rados_connect_timeout = -1
rbd_user = wangshenao
rbd_secret_uuid = ff0707c9-a889-4391-84b8-0674407479ae

修改控制节点和计算节点nova配置
vim /etc/nova/nova.conf
***在 libvirt 标签下配置用户及 uuid***
[libvirt]
rbd_user = cloudcs
rbd_secret_uuid = 0db874a3-70fb-4deb-a98f-9e32baea5a74

控制
chown cinder.cinder /etc/ceph/*
systemctl restart openstack-cinder*
计算
systemctl restart openstack-nova-compute.service 
```

## openstack创建存储类型

```bash
openstack volume type create ceph
cinder --os-username admin --os-tenant-name admin type-key ceph set volume_backend_name=ceph
openstack volume type list
systemctl restart openstack-cinder-scheduler.service openstack-cinder-volume.service
```