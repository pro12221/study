 # 主节点配置文件

```bash
[mysqld]
port=3306
basedir=/usr/local/mysql
datadir=/data/mysql
max_connections=1000
max_connect_errors=100
character-set-server=utf8mb4
default-storage-engine=INNODB
lower_case_table_names = 0
interactive_timeout = 1800
wait_timeout = 1800

server_id=1
gtid_mode=ON
enforce_gtid_consistency=ON
plugin_load_add = 'group_replication.so'
loose-group_replication_group_name="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
loose-group_replication_start_on_boot=OFF
loose-group_replication_local_address="192.168.44.11:24901"
loose-group_replication_group_seeds="192.168.44.11:24901,192.168.44.12:24901,192.168.44.13:24901"
default_authentication_plugin=mysql_native_password
binlog_checksum=NONE
transaction_write_set_extraction=XXHASH64
loose-group_replication_bootstrap_group=OFF

[mysql]
default-character-set=utf8mb4

[client]
port=3306
default-character-set=utf8mb4
```

# 从节点配置文件

```bash
[mysqld]
port=3306
basedir=/usr/local/mysql
datadir=/data/mysql
max_connections=1000
max_connect_errors=100
character-set-server=utf8mb4
default-storage-engine=INNODB
lower_case_table_names=0
interactive_timeout=1800
wait_timeout=1800

server_id=2  #这里每个节点不唯一
gtid_mode=ON
enforce_gtid_consistency=ON
plugin_load_add = 'group_replication.so'
loose-group_replication_group_name="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
loose-group_replication_start_on_boot=OFF
loose-group_replication_local_address="192.168.44.35:24901"  # 这里改为本机节点的IP地址
loose-group_replication_group_seeds="192.168.44.35:24901,192.168.44.36:24901,192.168.44.37:24901"
default_authentication_plugin=mysql_native_password
binlog_checksum=NONE
transaction_write_set_extraction=XXHASH64
loose-group_replication_bootstrap_group=OFF

[mysql]
default-character-set=utf8mb4

[client]
port=3306
default-character-set=utf8mb4
```

# 所有节点执行

```sql
#创建复制用户
SET SQL_LOG_BIN=0;
CREATE USER repluser@'%' IDENTIFIED BY '123456';
GRANT REPLICATION SLAVE ON *.* TO repluser@'%';
FLUSH PRIVILEGES;
SET SQL_LOG_BIN=1;
#所有机器安装插件
INSTALL PLUGIN group_replication SONAME 'group_replication.so';
SELECT * FROM INFORMATION_SCHEMA.PLUGINS WHERE PLUGIN_NAME = 'group_replication'\\G
show plugins;
RESET MASTER;

```

# 主节点执行

```sql
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
SET GLOBAL group_replication_bootstrap_group=OFF; 
```

# 从节点执行

```sql

CHANGE REPLICATION SOURCE TO SOURCE_USER='repluser', SOURCE_PASSWORD='123456' FOR CHANNEL 'group_replication_recovery';
START GROUP_REPLICATION;
```

# 其他操作

## 故障节点恢复

```sql
# 在原主节点执行
STOP GROUP_REPLICATION;
RESET MASTER;
change master to master_user='repluser',master_password='123456' for channel 'group_replication_recovery';
START GROUP_REPLICATION;
```

## 查看mgr状态

```sql
mysql> SELECT * FROM performance_schema.replication_group_members;
+---------------------------+--------------------------------------+-------------+-------------+--------------+
| CHANNEL_NAME              | MEMBER_ID                            | MEMBER_HOST | MEMBER_PORT | MEMBER_STATE |
+---------------------------+--------------------------------------+-------------+-------------+--------------+
| group_replication_applier | 3fa7b9b6-b6dd-11ef-9364-08000726c0a6 | server2     |        3306 | ONLINE       |
| group_replication_applier | a696cf2e-b6ca-11ef-a1ba-000c29c0da00 | server1     |        3306 | ONLINE       |
| group_replication_applier | e76692bc-c065-11ef-b6ac-08000726c0a7 | server3     |        3306 | ONLINE       |
+---------------------------+--------------------------------------+-------------+-------------+--------------+
3 rows in set (0.00 sec)

#查看主节点
mysql> select b.member_host the_master,a.variable_value master_uuid
          from performance_schema.global_status a
          join performance_schema.replication_group_members b
          on a.variable_value = b.member_id
          where variable_name='group_replication_primary_member';
+------------+--------------------------------------+
| the_master | master_uuid                          |
+------------+--------------------------------------+
| server1    | a696cf2e-b6ca-11ef-a1ba-000c29c0da00 |
+------------+--------------------------------------+
1 row in set (0.00 sec)

```


# 使用keepalived做高可用
## keepalived节点配置
优先级：
mgr01： priority 100
mgr02： priority 98
mgr03： priority 96

keepalived配置文件
```shell
! Configuration File for keepalived
###使用说明开始###
#keepalived实现mysql mgr 集群高可用，流程如下
#0.所有keepalived节点配置为backup，非抢占模式，基础权重建议为 70、80、90，脚本权重为30，即最小权重+脚本权重>最大权重
#1.如果mysql服务异常，启动服务
#2.如果mysql为master，则返回成功0，keepalived增加权重
#3.如果mysql为slave，则返回失败100，keepalived不增加权重
#4.如果mysql为slave，且keepalived为master，则keepalived切换
###使用说明结束###
global_defs {
   notification_email {
     
   }   
   router_id mgr01     #keepalived机器标识，无特殊作用，一般为机器名
}

vrrp_script chk_mysql_port {
script "/root/chk_mysql.sh" #脚本路径
interval 2 #脚本检测频率
weight -5 #脚本执行失败权重就-5
fall 2 #如果连续两次检测失败，认为节点服务不可用
rise 1 #如果连续2次检查成功则认为节点正常
}
 
vrrp_script chk_mysql_master {
script "/root/chk_mysql2.sh"
interval 2
weight 10
}
 
vrrp_instance VI_1 {
state MASTER
interface eth0 #节点IP的网卡
virtual_router_id 88 #同一个instance相同
priority 100 # 优先级，数值越大，优先级越高
advert_int 1
authentication { #节点间的认证，所有的必须一致
auth_type PASS
auth_pass 1111
}
virtual_ipaddress { #VIP，自定的，我觉得和外网的IP要一个网段
 192.168.44.40/24 brd 192.168.44.255 dev ens33
 }
 
track_script { #指定前面脚本的名字
chk_mysql_port
chk_mysql_master
}
```

## 脚本文件
检查mysql是否在线
```shell
vim /root/chk_mysql.sh

#!/bin/bash
# 使用systemctl检查MySQL服务状态
systemctl is-active --quiet mysql
status=$?

echo "$(date) - MySQL service check: $status" >> /tmp/mysql_check.log

if [ $status -ne 0 ]; then
    echo "$(date) - MySQL service inactive, stopping keepalived" >> /tmp/mysql_check.log
    systemctl stop keepalived
    exit 1
fi
exit 0
```
检查mysql节点是否为master
```shell
vim /root/chk_mysql2.sh 
#!/bin/bash
host=`/usr/local/mysql/bin/mysql  -e "SELECT * FROM performance_schema.replication_group_members WHERE MEMBER_ID = (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME= 'group_replication_primary_member')" |awk 'NR==2{print}'|awk -F" " '{print $3}'`
host2=`hostname`
if [ $host == $host2 ] ;then
exit 0
else
exit 1
fi
```