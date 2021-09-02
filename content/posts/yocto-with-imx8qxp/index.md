---
date: 2021-09-01T14:05:41+08:00
title: "在 i.MX 8QuadXPlus 上使用 Yocto 建置 Linux 系統"
description: ""
author: "Yuan"
draft: false
tags: ["i.mx8qxp","yocto","linux"]
keywords: []
categories: ["embedded system"]
---

## 前言

最近剛拿到 NXP 的 i.MAX8 開發板。在測試基本功能之餘，也順手把過程記錄下來。本文僅先建置 Yocto 的開發環境並編譯出可開機的映像檔，最後透過 SD 卡開機。

<!--more-->

## 主要內容

### 開發板配置

下列是來自官方的圖，我們主要會是以 SD Card 開機，所以目前我們要先確認主板的開機配置

{{< figure src="images/IMX8QUADXPLUS-BOARD-TOP.png" caption="https://www.nxp.com/design/development-boards/i-mx-evaluation-and-development-boards/i-mx-8quadxplus-multisensory-enablement-kit-mek:MCIMX8QXP-CPU" >}}

確認 `SW2` 的配置與下圖相同

{{< figure src="images/IMX8QUADXPLUS-BOARD-SWITCH.png" caption="https://www.nxp.com/document/guide/get-started-with-the-mcimx8qxp-cpu:GS-MCIMX8QXP-CPU">}}

連接 `J11` (Micro USB)，我們可以像先前一樣在電腦中看到 tty 裝置。在後續的流程，我們就可以透過它來操作系統。

{{< figure src="images/debug-port.png" caption="micro USB Debug Port" >}}

```bash
screen /dev/tty.XXXXXX 115200
```

### 安裝相依套件

```bash
sudo apt install -y gawk wget git-core diffstat unzip texinfo gcc-multilib \
build-essential chrpath socat cpio python python3 python3-pip python3-pexpect \
xz-utils debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev \
pylint3 xterm rsync curl

mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo  > ~/bin/repo
chmod a+x ~/bin/repo
export PATH=~/bin:$PATH
```

### 建立 Yocto 環境

```bash
mkdir imx-yocto-bsp && cd imx-yocto-bsp
repo init -u https://source.codeaurora.org/external/imx/imx-manifest -b imx-linux-hardknott -m imx-5.10.35-2.0.0.xml

# 這一步會花蠻多時間的，所以就讓子彈飛一會兒吧~~ 
repo sync

DISTRO=fsl-imx-xwayland MACHINE=imx8qxpc0mek source imx-setup-release.sh -b first-build
```

### 第一次編譯
```bash
# 移至專案目錄中
cd first-build

# 開始編譯
bitbake imx-image-core

# 將映像檔寫入 SD 卡中
bzcat <image_name>.wic.bz2 | sudo dd of=/dev/sd<partition> bs=1M conv=fsync
```

### 測試 UART

https://community.nxp.com/t5/i-MX-Processors/How-to-check-rs232-port-in-imx8-8x-baseboard-in-imx8qxp-mek/m-p/1240789


### NFS

#### Host 端

在 Host 上安裝 NFS Server ，並進行分享目錄與防火牆設定。 

```bash
# 安裝 NFS Server
aptitude install -y nfs-kernel-server

# 建立分享目錄
mkdir -p /srv/nfs_shared

# 設定分享目錄
echo "/srv/nfs_shared    *(insecure,rw,sync,no_root_squash,subtree_check)" > /etc/export

# 設定防火牆 (如果有的話)
firewall-cmd --add-rich-rule="rule family='ipv4' source address='192.168.0.10' service name='nfs' accept" --permanent
firewall-cmd --add-rich-rule="rule family='ipv4' source address='192.168.0.10' service name='mountd' accept" --permanent
firewall-cmd --add-rich-rule="rule family='ipv4' source address='192.168.0.10' service name='rpc-bind accept" --permanent
firewall-cmd --reload
```

#### Client 端

在 i.mx8 開機後，後我們可以使用 `ip` 來檢視目前的 IP 配置狀況。

```bash
ip -c addr

# 設置靜態 IP
ip addr add 192.168.0.10/24 dev eth0
``` 

```bash
mkdir -p /tmp/nfs
mount -t nfs 192.168.0.2:/srv/nfs_shared /tmp/nfs
```

我們就可以存取到 Host  所分享的資料了。

## 小結

在板子可以開機之後，接下來就要來試著改改看配置啦!

## 參考連結

- [MCIMX8QXP-CPU][1]
- [防火牆說明介紹][2]

[1]:https://www.nxp.com/design/development-boards/i-mx-evaluation-and-development-boards/i-mx-8quadxplus-multisensory-enablement-kit-mek:MCIMX8QXP-CPU
[2]:https://blog.xuite.net/tolarku/blog/363801991-CentOS+7+Firewalld+防火牆說明介紹

[3]:https://imxdev.gitlab.io/tutorial/How_to_use_UUU_to_flash_the_iMX_boards/
[4]:https://github.com/NXPmicro/mfgtools
[5]:https://www.wpgdadatong.com/tw/blog/detail?BID=B1389