#!/bin/bash

#1. 保存环境变量
export PATH=$PATH:/usr/local/bin
workdir=`pwd`

#2. 停止postgres数据库
systemctl stop shuwa_pg_writer
rm /lib/systemd/system/shuwa_pg_writer.service -rf
killall postgres

#3. 准备postgres的安装运行环境
# 网络检查
ping -c2 baidu.com

#关闭防火墙，selinux
systemctl stop firewalld && sudo systemctl disable firewalld
sed -ri s/SELINUX=enforcing/SELINUX=disabled/g /etc/selinux/config
setenforce 0

### 配置阿里云yum源
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo

#echo "isntalling tools"
yum -y install vim net-tools wget ntpdate
yum -y groupinstall "Development Tools"

# 时间同步
echo "*/10 * * * * /usr/sbin/ntpdate ntp.aliyun.com > /dev/null 2>&1" >>/etc/crontab

# 加快ssh连接
sed -ri s/"#UseDNS yes"/"UseDNS no"/g /etc/ssh/sshd_config
systemctl restart sshd

#部署数据库
## 创建目录和用户,以及配置环境变量
userdel postgres
groupadd postgres
useradd -g postgres postgres
## 密码设置在引号内输入自己的密码
echo "CU8GtM6QEMjnSkJnDAaJEztdL_vlmc41" | passwd --stdin postgres

echo "export PATH=/usr/local/pgsql/12/bin:$PATH" >/etc/profile.d/pgsql.sh
source /etc/profile.d/pgsql.sh


## 环境准备，根据自身需要，减少或者增加
yum install -y wget git gcc gcc-c++  epel-release llvm5.0 llvm5.0-devel clang libicu-devel perl-ExtUtils-Embed readline readline-devel zlib zlib-devel openssl openssl-devel pam-devel libxml2-devel libxslt-devel openldap-devel systemd-devel tcl-devel python-devel

if [ ! -f /tmp/postgresql-12.0.tar.gz ]; then
   wget http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot4.0/postgresql-12.0.tar.gz -O /tmp/postgresql-12.0.tar.gz
fi

cd /tmp
tar xf postgresql-12.0.tar.gz
cd postgresql-12.0

randtime=`date +%F_%T`
echo $randtime

if [ -d /data/shuwa_pg_writer ]; then
   mv /data/shuwa_pg_writer/ /data/shuwa_pg_writer_bk_$randtime
fi

mkdir /data/shuwa_pg_writer/data -p
mkdir /data/shuwa_pg_writer/archivedir -p

chown -R postgres.postgres /data/shuwa_pg_writer

./configure --prefix=/usr/local/pgsql/12 --with-pgport=7432 --enable-nls --with-python --with-tcl --with-gssapi --with-icu --with-openssl --with-pam --with-ldap --with-systemd --with-libxml --with-libxslt
make && make install

cd $workdir
rm $workdir/postgresql-12.0 -rf

#3.搭建主库

##初始化
sudo -u postgres /usr/local/pgsql/12/bin/initdb -D /data/shuwa_pg_writer/data/ -U postgres --locale=en_US.UTF8 -E UTF8
cp /data/shuwa_pg_writer/data/{pg_hba.conf,pg_hba.conf.bak}
cp /data/shuwa_pg_writer/data/{postgresql.conf,postgresql.conf.bak}
##配置postgresql.conf
cat  > /data/shuwa_pg_writer/data/postgresql.conf << "EOF"
listen_addresses = '*'
port = 7432
max_connections = 100
superuser_reserved_connections = 10
full_page_writes = on
wal_log_hints = off
max_wal_senders = 50
hot_standby = on
log_destination = 'csvlog'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S'
log_rotation_age = 1d
log_rotation_size = 10MB
log_statement = 'mod'
log_timezone = 'PRC'
timezone = 'PRC'
unix_socket_directories = '/tmp'
shared_buffers = 512MB
temp_buffers = 16MB
work_mem = 32MB
effective_cache_size = 2GB
maintenance_work_mem = 128MB
#max_stack_depth = 2MB
dynamic_shared_memory_type = posix
## PITR
full_page_writes = on
wal_buffers = 16MB
wal_writer_delay = 200ms
commit_delay = 0
commit_siblings = 5
wal_level = replica
archive_mode = off
archive_command = 'test ! -f /data/shuwa_pg_writer/archivedir/%f && cp %p /data/shuwa_pg_writer/archivedir/%f'
archive_timeout = 60s
EOF

cat > /lib/systemd/system/shuwa_pg_writer.service << "EOF"
[Unit]
Description=shuwa_pg_writer database server
After=network.target

[Service]
Type=notify
User=postgres
Group=postgres
Environment=DATA_DIR=/data/shuwa_pg_writer/data
ExecStart=/usr/local/pgsql/12/bin/postgres -D ${DATA_DIR}
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutSec=300
OOMScoreAdjust=-1000
[Install]
WantedBy=multi-user.target
EOF

chown postgres:postgres /data/shuwa_pg_writer -R
systemctl daemon-reload
systemctl enable shuwa_pg_writer
systemctl start shuwa_pg_writer

sleep 10

#4. 安装parse server
if [ ! -f /data/shuwa_parse_server_4.0.tar.gz ]; then
   wget http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot4.0/shuwa_parse_server_4.0.tar.gz -O /data/shuwa_parse_server_4.0.tar.gz
fi
cd /data/
tar xf shuwa_parse_server_4.0.tar.gz

cat > /data/shuwa_parse_server/script/.env << "EOF"
# 基础配置
SERVER_NAME = shuwa_parse_server
SERVER_PORT = 1337
SERVER_DOMAIN = http://{{wlanip}}:1337
SERVER_PUBLIC = http://{{wlanip}}:1337
SERVER_PATH = /parse
GRAPHQL_PATH = http://{{wlanip}}:1337/graphql

# 管理配置
DASHBOARD_PATH = /dashboard
DASHBOARD_USER = shuwa_parse
DASHBOARD_PASS = nDAivfl8Z28czsX4e4n2iFsAs-eqElNV

# 数据配置
DATABASE = postgres://postgres:CU8GtM6QEMjnSkJnDAaJEztdL_vlmc41@127.0.0.1:7432/parse
REDIS_SOCKET = redis://127.0.0.1:16379/0
REDIS_CACHE = redis://127.0.0.1:16379/1

# 邮箱配置
EMAIL_FROM_ADDRESS = noreply@notice.server
EMAIL_FROM_NAME = 系统通知
EMAIL_SENDMAIL = true

# 接口配置
KEY_APPID = 1uqZbbdd_JMyQ45YLsUzYezMRPerMa80
KEY_MASTER = PADbN7p973quWLngikp6XvrDbL97u_vM
KEY_READONLY_MASTER = AahKvb3LQNT1W88mdZIuIzNNYJeyw3u4
KEY_FILE = vKoX6ZiuGr4m6hR1O0g3VlfHgi4vOQLJ
KEY_CLIENT = elLcReJyCcEZo4z6puVey_dB5AXcnL8E
KEY_JAVASCRIPT = gguWXMv0wpKw4P81IeDbhA9kCOeD9FgY
KEY_RESTAPI = vlCXoH6U299cXYirRRFtGi6bJCJIEyLY
KEY_DOTNET = JIC843FLinh0mokSNbdT5mp1ac0TJcRT
KEY_WEBHOOK = pOb64g91WWPtc1AOrf6UN0AFEDDnoA9K

# 会话配置
SESSION_LENGTH = 604800
EOF

sed -i '/^# defaultPass/cdefaultPass           W41S0rnstbnPawdLMhF9clTHjL89tEvQ' /etc/taos/taos.cfg

cd /data/shuwa_parse_server/
cd /data/shuwa_parse_server/script/redis/
make

#部署shuwa_redis服务
systemctl stop shuwa_redis
rm /usr/lib/systemd/system/shuwa_redis.service  -rf

cat > /lib/systemd/system/shuwa_redis.service << "EOF"
[Unit]
Description=shuwa_redis
After=network.target

[Service]
Type=simple
ExecStart=/data/shuwa_parse_server/script/redis/src/redis-server /data/shuwa_parse_server/script/redis.conf
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutSec=300
OOMScoreAdjust=-1000
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable shuwa_redis
systemctl start shuwa_redis

#部署shuwa_parse_server服务
systemctl stop shuwa_parse_server
rm /usr/lib/systemd/system/shuwa_parse_server.service  -rf

cat > /lib/systemd/system/shuwa_parse_server.service << "EOF"
[Unit]
Description=shuwa_parse_server_service
After=network.target shuwa_pg_writer.service
Requires=shuwa_pg_writer.service

[Service]
Type=simple
ExecStart=/data/shuwa_parse_server/script/node/bin/node /data/shuwa_parse_server/server/index.js
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutSec=300
OOMScoreAdjust=-1000
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

wget http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot4.0/parse_4.0.sql.tar.gz -O /home/postgres/parse_4.0.sql.tar.gz
cd /home/postgres/
tar xvf parse_4.0.sql.tar.gz

psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'CU8GtM6QEMjnSkJnDAaJEztdL_vlmc41';"
psql -U postgres -c "CREATE USER  repl WITH PASSWORD 'CU8GtM6QEMjnSkJnDAaJEztdL_vlmc41' REPLICATION;"
psql -U postgres -c "CREATE DATABASE parse;"
psql -U postgres -f ./parse_4.0.sql  parse

systemctl daemon-reload
systemctl enable shuwa_parse_server
systemctl start shuwa_parse_server


#6. 安装erlang/otp环境
yum install -y make gcc gcc-c++ kernel-devel m4 ncurses-devel openssl-devel libstdc++-devel ncurses-devel openssl-devel unixODBC unixODBC-devel libtool-ltdl libtool-ltdl-devel

if [ ! -f /tmp/otp_src_21.3.tar.gz ]; then
  wget http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot4.0/otp_src_21.3.tar.gz -O /tmp/otp_src_21.3.tar.gz
fi

cd /tmp/
tar xf otp_src_21.3.tar.gz

cd /tmp/otp_src_21.3
./configure
make uninstall
make clean
make -j5
make install

cd $workdir
rm /tmp/otp_src_21.3 -rf

#7. 部署shuwa_iot
cd /data
randtime=`date +%F_%T`
echo $randtime

if [ -d /data/shuwa_iot ]; then
   mv /data/shuwa_iot/ /data/shuwa_iot_bk_$randtime
fi

wget http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot_release/{{dgiot}}.tar.gz -O /data/{{dgiot}}.tar.gz
tar xf {{dgiot}}.tar.gz
cd  /data/shuwa_iot

count=`ps -ef |grep beam.smp |grep -v "grep" |wc -l`
if [ 0 == $count ];then
   echo $count
  else
   killall -9 beam.smp
fi

#配置license
sed -i '/^shuwa_auth.license/cshuwa_auth.license = ee7982020f18070e860b6468ec27e2b6' /data/shuwa_iot/etc/plugins/shuwa_license.conf

#parse 连接 配置
sed -i '/^parse.parse_server/cparse.parse_server = http://127.0.0.1:1337' /data/shuwa_iot/etc/plugins/shuwa_parse.conf
sed -i '/^parse.parse_path/cparse.parse_path = /parse/' /data/shuwa_iot/etc/plugins/shuwa_parse.conf
sed -i '/^parse.parse_appid/cparse.parse_appid = 1uqZbbdd_JMyQ45YLsUzYezMRPerMa80' /data/shuwa_iot/etc/plugins/shuwa_parse.conf
sed -i '/^parse.parse_master_key/cparse.parse_master_key = PADbN7p973quWLngikp6XvrDbL97u_vM' /data/shuwa_iot/etc/plugins/shuwa_parse.conf
sed -i '/^parse.parse_js_key/cparse.parse_js_key = gguWXMv0wpKw4P81IeDbhA9kCOeD9FgY' /data/shuwa_iot/etc/plugins/shuwa_parse.conf
sed -i '/^parse.parse_rest_key/cparse.parse_rest_key = vlCXoH6U299cXYirRRFtGi6bJCJIEyLY' /data/shuwa_iot/etc/plugins/shuwa_parse.conf

#修改emq.conf
sed -i '/^node.name/cnode.name = shuwa_iot@{{wlanip}}' /data/shuwa_iot/etc/emqx.conf
mv /data/shuwa_iot/data/loaded_plugins /data/shuwa_iot/data/loaded_plugins_bk
cat > /data/shuwa_iot/data/loaded_plugins << "EOF"
{emqx_management, true}.
{emqx_recon, true}.
{emqx_retainer, true}.
{emqx_dashboard, true}.
{emqx_rule_engine, true}.
{emqx_cube, false}.
{shuwa_statsd, true}.
{shuwa_license, true}.
{shuwa_public, true}.
{shuwa_mqtt, true}.
{shuwa_framework, true}.
{shuwa_device_shadow, true}.
{shuwa_parse, true}.
{shuwa_web_manager,true}.
{shuwa_bridge,true}.
{shuwa_suke,true}.
EOF


systemctl stop dgiot
rm /usr/lib/systemd/system/dgiot.service  -rf
cat > /lib/systemd/system/dgiot.service << "EOF"
[Unit]
Description=shuwa_iot_service
After=network.target shuwa_parse_server.service
Requires=shuwa_parse_server.service

[Service]
Type=forking
Environment=HOME=/data/shuwa_iot/erts-10.3
ExecStart=/bin/sh /data/shuwa_iot/bin/emqx start
LimitNOFILE=1048576
ExecStop=/bin/sh /data/shuwa_iot/bin/emqx stop
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutSec=300
OOMScoreAdjust=-1000
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dgiot
systemctl start dgiot

sleep 15

#4. 安装td server
#setup mosquitto
rm mosquitto* -rf
wget http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot4.0/mosquitto-1.6.7.tar.gz -O /tmp/mosquitto-1.6.7.tar.gz
cd /tmp
tar xvf mosquitto-1.6.7.tar.gz
cd  mosquitto-1.6.7
make uninstall
make clean
make install
sudo ln -s /usr/local/lib/libmosquitto.so.1 /usr/lib/libmosquitto.so.1
ldconfig
cd ..
rm mosquitto*  -rf

#setup tdengine server
cd /tmp
wget http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot4.0/TDengine-server-2.0.16.0-Linux-x64.tar.gz -O /tmp/TDengine-server-2.0.16.0-Linux-x64.tar.gz
tar xf TDengine-server-2.0.16.0-Linux-x64.tar.gz
cd /tmp/TDengine-server-2.0.16.0/
/bin/sh install.sh
ldconfig
rm /tmp/TDengine-server-2.0.16.0 -rf

#下载dgiot_td_server桥接服务
wget http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot4.0/dgiot_td_server  -O /usr/sbin/dgiot_td_server
systemctl stop dgiot_td_server
rm /usr/lib/systemd/system/dgiot_td_server.service  -rf
cat > /lib/systemd/system/dgiot_td_server.service << "EOF"
[Unit]
Description=dgiot_td_server

[Service]
Type=simple
ExecStart=/usr/sbin/dgiot_td_server 127.0.0.1 taosd root
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutSec=300
OOMScoreAdjust=-1000
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dgiot_td_server
systemctl start dgiot_td_server

# 安装python3.8
# 1、依赖包安装
yum install -y wget curl zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel libffi-devel
# 2、下载包
wget http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot4.0/Python-3.8.0.tgz
# 3、解压
tar -xvf Python-3.8.0.tgz
# 4、安装
cd Python-3.8.0
./configure --prefix=/usr/local/python3
make && make install
# 5、建立软连接
/usr/bin/mv python python_bk
/usr/bin/mv pip pip_bk
ln -s /usr/local/python3/bin/python3 /usr/bin/python
ln -s /usr/local/python3/bin/pip3 /usr/bin/pip

# 安装numpy
pip install numpy
# 安装matplotlib
pip install matplotlib
# 安装pylab
pip install pylab
