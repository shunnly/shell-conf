#!/bin/bash
#Data:2017-03-13
#Version:2.1
#Author:Shunny(1071607787@qq.com)
ip=$(ifconfig eth0|sed -n 2p|awk '{print $2}')
##################
function pand() {
if [ "$ip" == "172.25.0.11" ];then
	return 0
else
	return 1
fi
}
###################
function ins () {
pand
if [ $? -eq 0 ];then
lab smtp-nullclient setup
lab nfskrb5 setup
yum -y install samba httpd mod_ssl mod_wsgi targetcli mariadb-server mariadb expect &> /dev/null
else
lab smtp-nullclient setup
lab nfskrb5 setup
yum -y install samba-client cifs-utils iscsi-initiator-utils expect &> /dev/null
fi
}
###################
function base() {
sed -i '/SELINUX=/s/=.*/=enforcing/' /etc/selinux/config
setenforce 1
sed -i '$a Denyusers *@*.my133t.org *@172.34.0.*' /etc/ssh/sshd_config
systemctl restart sshd
sed -i '$a alias qstat="/bin/ps -Ao pid,tt,user,fname,rsz"' /etc/bashrc
sed -i '$a alias reboot="reboot -f"' /etc/bashrc
systemctl restart firewalld
systemctl enable firewalld
firewall-cmd  --set-default-zone=trusted &>/dev/null
firewall-cmd  --permanent  --add-source=172.34.0.0/24  --zone=block &>/dev/null
wait
firewall-cmd  --permanent --zone=trusted  --add-forward-port=port=5423:proto=tcp:toport=80 &>/dev/null
wait
firewall-cmd  --reload &>/dev/null
wait
nmcli  connection add  con-name  team0  type  team  ifname team0  config  '{ "runner":{ "name":"activebackup" }  }' &>/dev/null
nmcli  connection add  con-name  team0-p1  type  team-slave ifname  eth1  master  team0 &>/dev/null
nmcli  connection add  con-name  team0-p2  type  team-slave ifname  eth2  master  team0 &>/dev/null
pand
if [ $? -eq 0 ];then
	nmcli connection modify team0 ipv4.method manual ipv4.addresses "172.16.3.20/24" connection.autoconnect yes 
else
	nmcli connection modify team0 ipv4.method manual ipv4.addresses "172.16.3.25/24" connection.autoconnect yes
fi
nmcli connection modify team0-p1 connection.autoconnect yes
nmcli connection modify team0-p2 connection.autoconnect yes
nmcli connection up team0 &>/dev/null
pand
if [ $? -eq 0 ];then
	nmcli connection modify "System eth0" ipv6.method manual ipv6.addresses 2003:ac18::305/64
else
	nmcli connection modify "System eth0" ipv6.method manual ipv6.addresses 2003:ac18::306/64
fi
nmcli connection up "System eth0" &>/dev/null
pand
if [ $? -eq 0 ];then
	hostnamectl  set-hostname  server0.example.com
else
	hostnamectl  set-hostname  desktop0.example.com
fi
}
##################
function mail1() {
sed -in '98c myorigin = desktop0.example.com' /etc/postfix/main.cf
sed -in '116s/localhost/loopback-only/' /etc/postfix/main.cf
sed -in '164s/=.*/=/' /etc/postfix/main.cf
sed -in '264c mynetworks = 127.0.0.0/8  [::1]/128' /etc/postfix/main.cf
sed -in '313c relayhost = [smtp0.example.com]' /etc/postfix/main.cf
sed -in '$a local_transport = error:local delivery disabled' /etc/postfix/main.cf
systemctl restart postfix
systemctl enable postfix
}
##################
function smb() {
pand
if [ $? -eq 0 ];then
mkdir  /common
useradd harry
expect <<EOF
spawn pdbedit -a harry	
expect "password" {send "migwhisk\r"}
expect "password" {send "migwhisk\r"}
expect "#" {send " "/r}
EOF
setsebool -P samba_export_all_rw=on
sed -i '89s/MYGROUP/STAFF/' /etc/samba/smb.conf
echo '
[common]
path = /common
hosts allow = 172.25.0.0/24'>>/etc/samba/smb.conf
mkdir /devops
useradd kenji &>/dev/null;useradd chihiro &>/dev/null 
expect <<EOF
spawn pdbedit -a kenji
expect "password" {send "atenorth\r"}
expect "password" {send "atenorth\r"}
expect "#" {send " "/r}
EOF
expect <<EOF
spawn pdbedit -a chihiro
expect "password" {send "atenorth\r"}
expect "password" {send "atenorth\r"}
expect "#" {send " "/r}
EOF
setfacl -m u:chihiro:rwx /devops/
echo '
[devops]
path = /devops
hosts allow = 172.25.0.0/24
write list = chihiro'>>/etc/samba/smb.conf
systemctl enable smb &>/dev/null
systemctl restart smb
else
mkdir /mnt/dev
sed -i '$a \/\/server0.example.com\/devops \/mnt\/dev cifs username=kenji,password=atenorth,multiuser,sec=ntlmssp,_netdev 0 0' /etc/fstab
mount -a
fi
}
##################
function nfs() {
pand
if [ $? -eq 0 ];then
	mkdir -p /public /protected/project
	chown ldapuser0 /protected/project/
	wget -O /etc/krb5.keytab http://classroom/pub/keytabs/server0.keytab &>/dev/null
	echo "/public 172.25.0.0/24(ro)" > /etc/exports
	sed -i '$a /protected 172.25.0.0/24(rw,sec=krb5p)' /etc/exports
	systemctl start nfs-secure-server nfs-server &>/dev/null
	systemctl enable nfs-secure-server nfs-server &>/dev/null
else 
	mkdir -p /mnt/nfsmount /mnt/nfssecure
	wget -O /etc/krb5.keytab http://classroom.example.com/pub/keytabs/desktop0.keytab  &>/dev/null
	systemctl start nfs-secure
	systemctl enable nfs-secure &>/dev/null
	sed -i '$a server0.example.com:\/public \/mnt\/nfsmount nfs _netdev 0 0' /etc/fstab
	sed -i '$a server0.example.com:\/protected \/mnt\/nfssecure nfs sec=krb5p,_netdev 0 0' /etc/fstab
	mount -a
fi
}
##################
function web() {
#配置WEB网页
echo '<VirtualHost *:80>
 ServerName server0.example.com
 DocumentRoot /var/www/html
</VirtualHost>'>/etc/httpd/conf.d/00-default.conf
wget http://classroom/pub/materials/station.html -O /var/www/html/index.html &>/dev/null
wget http://classroom.example.com/pub/example-ca.crt -0 /etc/pki/tls/certs/ca-bundle.crt &>/dev/null
wget http://classroom.example.com/pub/tls/private/server0.key -O /etc/pki/tls/private/localhost.key &>/dev/null
wget http://classroom.example.com/pub/tls/certs/server0.crt -O /etc/pki/tls/certs/localhost.crt &>/dev/null
sed -i '59s/#//' /etc/httpd/conf.d/ssl.conf
sed -i '60s/#//' /etc/httpd/conf.d/ssl.conf
sed -i '122s/#//' /etc/httpd/conf.d/ssl.conf
systemctl enable httpd &>/dev/null
#虚拟WEB
mkdir /var/www/virtual &>/dev/null
useradd fleyd
setfacl -m u:fleyd:rwx /var/www/virtual/
wget http://classroom.example.com/pub/materials/www.html -O /var/www/virtual/index.html  &>/dev/null
touch /etc/httpd/conf.d/01-www0.conf
echo '<VirtualHost *:80>
 ServerName www0.example.com
 DocumentRoot /var/www/virtual
</VirtualHost>'>/etc/httpd/conf.d/01-www0.conf
#WEN访问限制
mkdir /var/www/html/private
wget http://classroom.example.com/pub/materials/private.html -O /var/www/html/private/index.html &>/dev/null
echo '
<Directory /var/www/html/private>
 Require ip 127.0.0.1 ::1 172.25.0.11 
</Directory>' >>/etc/httpd/conf.d/00-default.conf
systemctl restart httpd
#动态WEB
mkdir /var/www/webapp0
wget http://classroom.example.com/pub/materials/webinfo.wsgi -O /var/www/webapp0/webinfo.wsgi &>/dev/null
echo 'Listen 8909
<VirtualHost *:8909>
 ServerName webapp0.example.com
 DocumentRoot /var/www/webapp0
 WSGIScriptAlias / /var/www/webapp0/webinfo.wsgi
</VirtualHost>'> /etc/httpd/conf.d/02-alt.conf
semanage port -a -t http_port_t -p tcp 8909
systemctl restart httpd
}
##################
function shell() {
echo '#!/bin/bash
if [ "$1" = "redhat" ]; then
echo "fedora"
elif [ "$1" = "fedora" ]; then
echo "redhat"
else
echo "/root/foo.sh redhat|fedora" >&2
fi'>/root/foo.sh
chmod +x /root/foo.sh

echo '#!/bin/bash
if [ $# -eq 0 ]; then
echo "Usage: /root/batchusers <userfile>"
exit 1
fi
if [ ! -f $1 ]; then
echo "Input file not found"
exit 2
fi
for name in $(cat $1)
do
 useradd -s /bin/false $name
done'>/root/batchusers
chmod +x /root/batchusers
}
##################
function isci() {
LANG=en
export $LANG
pand
if [ $? -eq 0 ];then
expect <<EOF
spawn fdisk /dev/vdb
expect "m for help" {send "n\r"}
expect "Select" {send "\r"}
expect "Partition" {send "\r"}
expect "First" {send  "\r"}
expect "size" {send "+3G\r"}
expect "m for help" {send "w\r"}
expect "m" {send "exit \r"}
expect "m" {send "exit \r"}
EOF
partprobe /dev/vdb
expect <<EOF
spawn targetcli
expect "/>" {send "backstores/block create iscsi_store /dev/vdb1\r"}
expect "/>" {send "/iscsi create iqn.2016-02.com.example:server0\r"}
expect "/>" {send "/iscsi/iqn.2016-02.com.example:server0/tpg1/acls create iqn.2016-02.com.example:desktop0\r"}
expect "/>" {send "/iscsi/iqn.2016-02.com.example:server0/tpg1/luns create /backstores/block/iscsi_store\r"}
expect "/>" {send "/iscsi/iqn.2016-02.com.example:server0/tpg1/portals create 172.25.0.11 3260\r"}	
expect "/>" {send "saveconfig\r"}
expect "/>" {send "exit\r"}
EOF
systemctl restart target
systemctl enable target &>/dev/null
else
sed -i 's/=.*/=iqn.2016-02.com.example:desktop0/' /etc/iscsi/initiatorname.iscsi
systemctl restart iscsid 
iscsiadm -m discovery -t st -p server0
iscsiadm -m node -L all
sed -i '50s/manual/automatic/' /var/lib/iscsi/nodes/iqn.2016-02.com.example\:server0/172.25.0.11\,3260\,1/default
systemctl enable iscsid  &>/dev/null
expect <<EOF
spawn fdisk /dev/sda
expect "m for help" {send "n\r"}
expect "Select" {send "\r"}
expect "Partition" {send "\r"}
expect "First" {send  "\r"}
expect "size" {send "+2100M\r"}
expect "m for help" {send "w\r"}
expect "m" {send "exit \r"}
expect "m" {send "exit \r"}
EOF
partprobe /dev/sda
mkfs.ext4 /dev/sda1 &>/dev/null
mkdir /mnt/data &>/dev/null
uuid=$(blkid |awk -F'"'  '{print $2}'|sed -n 2p)
echo "UUID="$uuid" /mnt/data ext4 _netdev 0 0">> /etc/fstab
mount -a 
fi
}
####################
function an() {
pand
if [ $? -eq 0 ];then
	echo "正在配置server0"
	echo "正在配置软件环境"
	ins
	echo "正在配置ISCSI"
	isci
	echo "正在配置BASE"
	base 
	echo "正在配置邮件"
	mail1
	echo "正在配置SMB"
	smb
	echo "正在配置NFS"
	nfs
	echo "正在配置WEB"
	web
	echo "正在配置SHELL"
	shell
else
echo "正在配置desktop0"
	echo "正在配置软件环境"
	ins
	echo "正在配置BASE"
	base 
	echo "正在配置SMB"
	smb
	echo "正在配置NFS"
	nfs
	echo "正在配置ISCSI"
	sleep 30
	isci
fi
}
####################	
if [ "$ip" == "172.25.0.11" ]||[ "$ip" == "172.25.0.10" ]
then
an
else
scp ./ces.sh 172.25.0.11:/root &> /dev/null
scp ./ces.sh 172.25.0.10:/root &> /dev/null
expect <<EOF
spawn ssh 172.25.0.11
expect "#" {send "bash ces.sh &\r"}
expect "#" {send "exit\r"}
expect "#" {send "exit\r"}
EOF
expect <<EOF
spawn ssh 172.25.0.10
expect "#" {send "bash ces.sh &\r"}
expect "#" {send "exit\r"}
expect "#" {send "exit\r"}
EOF
fi

