#!/bin/bash

# 获取所有 OSD 的 ID
OSD_IDS=$(ceph osd ls)

# 遍历每个 OSD
for OSD_ID in $OSD_IDS; do
    # 获取 OSD 的 metadata
    METADATA=$(ceph osd metadata $OSD_ID)

    # 提取 hostname
    HOSTNAME=$(echo "$METADATA" | grep -oP '"hostname":\s*"\K[^"]+')

    # 提取 device_paths
    DEVICE_PATHS=$(echo "$METADATA" | grep -oP '"device_paths":\s*"\K[^"]+')

    # 输出结果
    echo "OSD ID: $OSD_ID, Host: $HOSTNAME, Device Paths: $DEVICE_PATHS"
done