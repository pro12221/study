#!/bin/bash
#版本说明
#ubuntu22.04,mysql-8.0.39

# 安装依赖
apt update
apt install libncurses5 libnuma1 -y

# 检测并卸载 MariaDB
if dpkg -l | grep -q mariadb; then
    echo "检测到 MariaDB 已安装，正在卸载..."
    apt remove --purge mariadb-* -y
    apt autoremove -y
    rm -rf /var/lib/mysql/
    rm -rf /etc/mysql/
fi

# 下载并解压 MySQL
wget https://downloads.mysql.com/archives/get/p/23/file/mysql-8.0.39-linux-glibc2.28-x86_64.tar.xz
tar -xvf mysql-8.0.39-linux-glibc2.28-x86_64.tar.xz
mv mysql-8.0.39-linux-glibc2.28-x86_64 /usr/local/mysql/

# 创建软链接
ln -sf /usr/local/mysql/bin/mysql /usr/bin/mysql

# 配置 my.cnf
cat > /etc/my.cnf <<EOF
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

[mysql]
default-character-set=utf8mb4

[client]
port=3306
default-character-set=utf8mb4
EOF

# 准备数据目录
groupadd mysql&&useradd -r -g mysql -s /bin/false mysql
mkdir -p /data/mysql
chown -R mysql:mysql /data/mysql
chmod 750 /data/mysql

# 初始化 MySQL
/usr/local/mysql/bin/mysqld --initialize-insecure --basedir=/usr/local/mysql --datadir=/data/mysql --user=mysql

# 设置服务
cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysql.server
chmod +x /etc/init.d/mysql.server

# 重载并启动服务
systemctl daemon-reload
systemctl start mysql.server

# 检查服务状态
sleep 5  # 等待服务启动
if systemctl is-active --quiet mysql.server; then
    echo "MySQL 服务启动成功"
    echo "初始 root 密码为空，请立即执行以下命令设置密码："
    echo "/usr/local/mysql/bin/mysqladmin -u root password '你的密码'"
else
    echo "MySQL 服务启动失败，请检查错误日志："
    echo "tail -n 50 /data/mysql/sre01.err"
    exit 1
fi