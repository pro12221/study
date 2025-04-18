# 配置多站点容灾
## CS01集群操作:
###开启存储池同步，同步模式为池模式
创建集群秘钥并导出
发送key到cs02的灾备集群
开启目标RBD同步特性
rbd mirror pool  enable cinder_pool pool 
rbd mirror pool peer bootstrap create --site-name cs01 cinder_pool > /opt/cs01.key 
scp /opt/cs01.key  root@192.168.10.47:/opt/ 
rbd -p cinder_pool ls | xargs -I {} rbd feature enable cinder_pool/{} journaling

## CS02集群操作:
###创建存储池和主集群相同
为存储池创建标签
安装rbd-mirror
导入cs01的集群秘钥
查看存储池卷是否同步
ceph osd  pool  create  cinder_pool 
ceph osd  pool  application  enable  cinder_pool rbd 
ceph orch  apply rbd-mirror --placement=1 
rbd mirror pool  peer bootstrap import --site-name cs02 --direction rx-only cinder_pool /opt/cs01.key
rbd -p cinder_pool ls 