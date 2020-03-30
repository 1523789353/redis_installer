#!/usr/bin/bash
umask 0022
errors=0

zh_CN(){
#normal
lang_download="正在下载安装包..."
lang_extract="正在解压安装包..."
lang_compil="正在编译..."
lang_checksum_pass="校验通过!"
lang_start_service="启动服务"
lang_stop_service="停止服务"
lang_enable_service="开机自启"
lang_check_service="查看状态"
#error
lang_fail="失败"
lang_abort_exit="安装终止,正在退出..."
lang_error="出错"
lang_download_err="下载安装包出错!"
lang_checksum_err="校验失败!"
lang_extract_err="解压出错,请检查tar程序!"
lang_compil_err="编译出错,请检查make程序!"
lang_makedir_err="创建目录出错!"
lang_addgroup_err="创建权限组出错!"
lang_adduser_err="创建用户出错!"
lang_chown_err="修改目录权限组/所有者出错!"
lang_copy_err="复制文件出错!"
lang_add_service_err="注册systemctl服务出错!"
lang_reload_err="重载systemctl出错,请手动输入systemctl daemon-reload指令以重载!"
lang_creat_link_err="创建软连接至/usr/bin出错!"
lang_err_msg="安装过程中遇到了一个或多个错误!"
}
zh_CN

abort(){
echo -e "\033[31m [${lang_error}] \033[0m- $1 ${lang_abort_exit} "
exit 1
}

err(){
echo -e "\033[31m [${lang_error}] \033[0m- $1 "
let errors++
}

yum install -y wget make gcc gcc-c++ automake autoconf libtool

echo "${lang_download}"
if [ ! -f ./redis-5.0.8.tar.gz ]; then
	wget http://download.redis.io/releases/redis-5.0.8.tar.gz || abort "${lang_download_err}"
fi

if [ `md5sum ./redis-5.0.8.tar.gz | grep -o '1885f1c67281d566a1fd126e19cfb25d'` ]; then
	echo "${lang_checksum_pass}"
else
	rm -rf ./redis-5.0.8.tar.gz
	abort "${lang_checksum_err}"
fi

echo "${lang_extract}"
tar -xzvf redis-5.0.8.tar.gz || abort "${lang_extract_err}"
rm -rf redis-5.0.8.tar.gz

cd redis-5.0.8
echo "${lang_compil}"
make all || make MALLOC=libc || abort "${lang_compil_err}"

mkdir -p /usr/local/redis || abort "${lang_makedir_err}"
groupadd redis || err "${lang_addgroup_err}"
useradd -g redis redis --no-create-home || err "${lang_adduser_err}"
chown -R redis:redis /usr/local/redis || err "${lang_chown_err}"
cp src/redis-server /usr/local/redis/ || abort "${lang_copy_err}"
cp src/redis-cli /usr/local/redis/ || abort "${lang_copy_err}"
cp redis.conf /usr/local/redis/ || abort "${lang_copy_err}"
rm -rf ../redis-5.0.8

cat<<DATA>/etc/systemd/system/redis-server.service || err "${lang_add_service_err}"
[Unit]
Description=Redis Server Manager
After=syslog.target
After=network.target
 
[Service]
Type=simple
User=redis
Group=redis
PIDFile=/var/run/redis_6379.pid
ExecStart=/usr/local/redis/redis-server /usr/local/redis/redis.conf
ExecStop=/usr/local/redis/redis-cli shutdown
Restart=always
 
[Install]
WantedBy=multi-user.target
DATA

systemctl daemon-reload || err "${lang_reload_err}"
ln -s /usr/local/redis/redis-cli /usr/bin/redis-cli || err "${lang_creat_link_err}"

[ "$errors" == "0" ] || err "$lang_err_msg"

cat<<TXT
Usage:
${lang_start_service}:systemctl start redis-server
${lang_stop_service}:systemctl stop redis-server
${lang_enable_service}:systemctl enable redis-server
${lang_check_service}:systemctl status redis-server
TXT
