---
date: 2021-08-31T22:56:03+08:00
title: "使用 Debian 來架設工作站"
description: ""
author: "Yuan"
draft: false
tags: ["linux","debian","server"]
keywords: []
categories: ["note"]
---

## 前言

最近剛好在重新安裝工作站，就順手記錄起來囉!

<!--more-->

## 主要內容

### 下載映像檔

```bash
wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-11.0.0-amd64-netinst.iso
```

### 製作安裝碟

```bash
sudo dd if=debian-11.0.0-amd64-netinst.iso of=/dev/DISK bs=10M
```

### 安裝

安裝步驟可以參考[這邊](https://www.server-world.info/query?os=Debian_11&p=install)。

### 設定 IP

#### 使用 systemd-networkd 設定 IP

透過重新命名 `/etc/network/interfaces` 的方式，來停用原本的網路介面配置。並建立 `systemd-networkd` 的設定檔。
完成後，我們就可以啟用 systemd-networkd 了。

```bash
# 取消 IPv6
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf

mv /etc/network/interfaces{,.save}

cat << EOF >> /etc/systemd/network/lan.network
[Match]
Name=eth0

[Network]
Address=192.168.0.2/24
Gateway=192.168.0.254
DNS=8.8.8.8
EOF

systemctl enable systemd-networkd
systemctl start systemd-networkd
```

#### IP (已改用 systemd-networkd)
修改 /etc/network/interfaces 來設定主機的 IP

```txt
allow-hotplug eth0
iface eth0 inet static
        address 192.168.0.2/24
        gateway 192.168.0.254
        # dns-* options are implemented by the resolvconf package, if installed
        dns-nameservers 8.8.8.8
        dns-search happy.internal
```

使用下列指令來重新起動網路

```bash
/etc/init.d/networking restart
```

{{< notice info "動態從 DHCP 取得 IP" >}}

```txt
auto eth0
allow-hotplug eth0
iface eth0 inet dhcp
```

我們可以使用下列指令來進行臨時的設定

```bash
ip addr add 192.168.0.2/24 dev eth0
ip addr del  192.168.0.2/24 dev eth0

dhcp eth0
dhcp -r eth0

ip link set eth0 up
ip link set eth0 down
```

{{< /notice >}}

### 安裝系統更新與常用工具

```bash
apt upgrade
apt update
apt install -y aptitude
aptitude install -y silversearcher-ag vim htop
```

### 設定時間同步

```bash
cat << EOF > /etc/systemd/timesyncd.conf
[Time]
NTP=time.google.com clock.stdtime.gov.tw
EOF

systemctl restart systemd-timesyncd.service
timedatectl status
date
```

### 設定防火牆規則

#### Firewalld

```
aptitude install -y firewalld
firewall-cmd --add-port=22022/tcp --permanent
firewall-cmd --reload
firewall-cmd --list-all
```

{{< notice info >}}

如果想直接操作 nftables 的話，可以使用下列指令

```bash
systemctl enable nftables
systemctl start nftables
nft add rule inet filter input tcp dport 22 accept
nft list ruleset
#nft list table inet filter
```

{{< /notice >}}

#### ufw (已改用 firewalld)

```bash
ufw enable
ufw default deny
ufw allow from XXX.XXX.XXX.XXX to XXX.XXX.XXX.XXX port 2234 proto tcp
```


### 修改 SSH Server 設定並上傳遠端存取公鑰

```bash
sed -i 's/^Port.*$/Port 2234/g' /etc/ssh/sshd_config
systemctl restart ssh
ssh-copy -i ~/.ssh/id_rsa  XXX.XXX.XXX.XXX -p 2234 -l user
```

{{< notice info "產生新的金錀" >}}

如果想要生成新的金鑰，可以輸入下列指令

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/new_key_rsa -C email@example.com
```

{{< /notice >}}

#### 限定只能使用金鑰進行認證 

```bash
sed -i 's/^UsePAM.*$/UsePAM no/g' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*$/PermitRootLogin no/g' /etc/ssh/sshd_config
echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config
systemctl restart ssh
```

{{< notice info >}}

如果是使用 sudo 的話，可以使用 tee 將輸出導向檔案

```bash
echo 'PasswordAuthentication no' | sudo tee -a /etc/ssh/sshd_config
```

查看有誰登入失敗以及有誰登入成功

```bash
cat /var/log/auth.log | ag 'sshd.*Invalid'
cat /var/log/auth.log | ag 'sshd.*opened'
```
{{< /notice >}}


#### 擋掉登入失敗次數過多的連線

```bash
aptitude install -y fail2ban
sed -e 's/^enabled = false$/enabled = true/g' /etc/fail2ban/jail.conf > /etc/fail2ban/jail.local
systemctl enable fail2ban
```

{{< notice info >}}

我們可以使用 fail2ban-client 來查看目前的運行狀況

```bash
fail2ban-client status
```
{{< /notice >}}


### 自動安裝更新

```bash
aptitude install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
systemctl status unattended-upgrades.service
```

### logrotate

```bash
/etc/logrotate.conf
```

## 小結

本文記錄了系統在剛安裝完成時，要先進行的配置。如: IP、時間、防火牆等。
未來若有再新增設定，會再補充說明。

## 參考連結

- [Debian 官方網站][offical]
- [systemd-networkd][1]
- [How to install and configure firewalld on debian][2]

[offical]:https://www.debian.org
[securing-debian-manual]:https://www.debian.org/doc/manuals/securing-debian-manual/index.en.html
[1]:https://wiki.debian.org/SystemdNetworkd
[2]:https://computingforgeeks.com/how-to-install-and-configure-firewalld-on-debian/