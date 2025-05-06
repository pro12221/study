```shell
ceph orch device ls 查看所有设备信息
ceph orch apply osd --all-available-devices 添加所有可用设备为osd
ceph orch daemon add osd ceph01:/dev/sdb  指定节点和磁盘添加
ceph osd tree  查看osd状态
ceph osd pool ls detail 查看存储池详细信息
```