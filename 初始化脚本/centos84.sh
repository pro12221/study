#!/bin/bash

# 确保脚本以 root 用户身份运行
if [ "$(id -u)" -ne 0 ]; then
    echo "请以 root 用户身份运行此脚本"
    exit 1
fi

echo "初始化 CentOS 8.4 系统配置..."

# 步骤1: 确保系统已连接互联网
echo "检查网络连接..."
curl -s https://www.baidu.com > /dev/null
if [ $? -ne 0 ]; then
    echo "网络连接失败，请检查网络配置！"
    exit 1
fi

# 步骤3: 配置 CentOS 8 Vault 仓库
echo "配置 CentOS 8 Vault 仓库..."

# 备份原有的 CentOS-Base.repo 文件
rm-rf /etc/yum.repos.d/*

# 下载并配置 CentOS 8 Vault 仓库
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-8.repo
sed -i 's/mirrors.cloud.aliyuncs.com/mirrors.aliyun.com/g' /etc/yum.repos.d/CentOS-Base.repo
sed -i 's/\$releasever/\$releasever-stream/g' /etc/yum.repos.d/CentOS-Base.repo
yum install -y https://mirrors.aliyun.com/epel/epel-release-latest-8.noarch.rpm
sed -i 's|^#baseurl=https://download.example/pub|baseurl=https://mirrors.aliyun.com|' /etc/yum.repos.d/epel*
sed -i 's|^metalink|#metalink|' /etc/yum.repos.d/epel*


# 步骤4: 清除缓存并生成新的缓存
echo "清除 YUM 缓存并生成新的缓存..."
dnf clean all
if [ $? -ne 0 ]; then
    echo "清除 YUM 缓存失败！"
    exit 1
fi

dnf makecache
if [ $? -ne 0 ]; then
    echo "生成新的 YUM 缓存失败！"
    exit 1
fi

# 步骤6: 关闭 SELinux（如果没有禁用）
echo "检查 SELinux 状态..."
selinux_status=$(sestatus | grep "SELinux status" | awk '{print $3}')

if [ "$selinux_status" != "disabled" ]; then
    echo "关闭 SELinux..."
    setenforce 0
    if [ $? -ne 0 ]; then
        echo "关闭 SELinux 失败！"
        exit 1
    fi

    sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    if [ $? -ne 0 ]; then
        echo "修改 SELinux 配置失败！"
        exit 1
    fi
else
    echo "SELinux 已禁用，跳过禁用操作。"
fi

# 步骤7: 关闭防火墙
echo "关闭防火墙..."
systemctl stop firewalld
if [ $? -ne 0 ]; then
    echo "停止防火墙失败！"
    exit 1
fi

systemctl disable firewalld
if [ $? -ne 0 ]; then
    echo "禁用防火墙失败！"
    exit 1
fi

# 步骤8: 安装一些常用包
echo "安装常用工具包..."
dnf install -y \
    vim                \
    net-tools          \
    wget               \
    curl               \
    git                \
    unzip              \
    telnet             \
    bind-utils         \
    lsof               \
    epel-release       \
    rsync              \
    bash-completion    \
    nc                 \

if [ $? -ne 0 ]; then
    echo "安装常用工具包失败！"
    exit 1
fi

# 步骤9: 配置 NTP 时间同步
echo "配置 NTP 时间同步..."
dnf install -y chrony
if [ $? -ne 0 ]; then
    echo "安装 chrony 失败！"
    exit 1
fi

systemctl enable --now chronyd
if [ $? -ne 0 ]; then
    echo "启用 chronyd 服务失败！"
    exit 1
fi

systemctl start chronyd
if [ $? -ne 0 ]; then
    echo "启动 chronyd 服务失败！"
    exit 1
fi

dnf upgrade libmodulemd

# 步骤10: 重启系统，应用所有更新
echo "系统初始化完成，重启系统以应用所有更新..."

# 提示用户确认重启
read -p "系统配置已完成，是否立即重启系统？(y/n): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    reboot
else
    echo "系统重启已取消。请手动重启以应用所有更新。"
fi

