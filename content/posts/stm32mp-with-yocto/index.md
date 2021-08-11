---
date: 2021-08-11T15:22:57+08:00
title: "在 STM32MP1 上使用 Yocto 建置 Linux 系統"
description: ""
author: "Yuan"
draft: false
tags: ["stm32mp1", "yocto", "linux"]
keywords: []
categories: ["embedded system"]
---

## 前言

手邊有一片很久沒有動過的 STM32MP157。剛好最近工作上需要在 imx8 進行開發。本文會照著 Bootlin 的課程進行實作 [[2]],一方面了解 Yocto 要如何使用，另一方面順便藉此先練練手。

<!--more-->

## 主要內容

### 環境

本文的實作環境是使用 Ubuntu 20.04.2 LTS 做為 Host，使用的網段是在 10.1.100.0/24 內。

### 準備 Bootlin 的課程資料

下載 bootlin 課程之 Lab 資料

```bash
cd ${HOME}

# 下載 Lab 資料
wget https://bootlin.com/doc/training/yocto-stm32/yocto-stm32-labs.tar.xz

# 解壓縮
tar xvf yocto-stm32-labs.tar.xz
```

### 安裝 Yocto 的相依套件

```bash
sudo apt install -y bc build-essential chrpath cpio diffstat gawk git python texinfo wget gdisk
```

{{< notice info >}}

筆者在編譯映像檔時，遇到了 `openssl/ssl.h' file not found` 的問題，所以輸入下列指令進行安裝。

```bash
sudo apt install -y libssl-dev
```
{{< /notice >}}

### 建置 Yocto 環境

```bash
pushd ${HOME}/yocto-stm32-labs
git clone -b dunfell-23.0.7 git://git.yoctoproject.org/poky.git
popd
git clone -b dunfell git://git.openembedded.org/meta-openembedded
git clone -b dunfell https://github.com/STMicroelectronics/meta-st-stm32mp.git
# cd meta-st-stm32mp && git checkout a95cc1ec39b60a1dc50d0902c91675935959e6d2
```

初始化 Yocto 環境

```bash
cd ${HOME}/yocto-stm32-labs
source poky/oe-init-build-env
```

加入 STM32MP1 的 BSP

```bash
# pwd 
# ${HOME}/yocto-stm32-labs/poky/oe-init-build-env/build

# 加入 stm32mp 相關的層
bitbake-layers add-layer ../meta-openembedded/meta-oe
bitbake-layers add-layer ../meta-openembedded/meta-python
bitbake-layers add-layer ../meta-st-stm32mp
```

#### 修改 Yocto 的配置檔

```bash
# 修改目標機器
sed -i 's/^MACHINE.*/MACHINE ?= "stm32mp1"/g' conf/local.conf
```

#### 建置映像檔 

```bash
bitbake core-image-minimal
```

{{< notice info >}}

下列是 conf/local.conf 常會配置的幾個配置項

```makefile
# 下載路徑
DL_DIR

# 編譯結果快取
SSTATE_DIR

# Bitbake 同時跑多少個 Task
BB_NUMBER_THREADS

# 編譯時跑多少個執行緒
PARALLEL_MAKE

# 目標機器
MACHINE
```

{{< /notice >}}

#### 建置用於 SD Card 的映像檔

```bash
${BUILDDIR}/tmp/deploy/images/stm32mp1/scripts/create_sdcard_from_flashlayout.sh ../flashlayout_core-image-minimal/trusted/FlashLayout_sdcard_stm32mp157f-dk2-trusted.tsv

# 產生 *.raw 於 ${BUILDDIR}/tmp/deploy/images/stm32mp1
```

#### 將映像檔寫入 SD Card 中
 
```bash
# 插入 SD Card 到電腦中
sudo dd if=FlashLayout_sdcard_stm32mp157f-dk2-trusted.raw of=/dev/mmcblk0 bs=8M status=progress conv=fdatasync
# or 
#sudo dd if=FlashLayout_sdcard_stm32mp157f-dk2-trusted.raw | pv -s ${IMAGE_SIZE} | dd of=/dev/mmcblk0 bs=4096 && sync
```

#### 測試

接上 ST-LINK 之後，在電腦開啟終端機

{{< figure src="images/st-link.jpg" caption="接上 ST-Link" >}}

```bash
# 參考自己電腦實際認到的裝置號
screen /dev/${SERIAL_PORT} 115200

# 使用 root 登入

Poky (Yocto Project Reference Distro) 3.1.7 stm32mp1 /dev/ttySTM0

# 結果
# stm32mp1 login: root
# root@stm32mp1:~# uname -a
# Linux stm32mp1 5.4.56 #1 SMP PREEMPT Wed Aug 5 07:59:52 UTC 2020 armv7l GNU/Linux
# root@stm32mp1:~#

# 使用 C-a C-k 離開
```

{{< figure src="images/result-first.png" caption="在STM32MP1 第一個 Linux 系統" >}}

### 從 NFS 載入 Root Filesystem

為了在後續的開發中，可以不用一直拔拔插插 SD Card。我們要讓系統在開機後，從 NFS Server 下載 root filesystem。

#### 建置 NFS 環境

在我們的工作機上，安裝 NFS Server 

```bash
# 安裝 NFS Server
sudo apt install -y nfs-kernel-server

# 建立 NFS 分享路徑
sudo mkdir /nfs_shared

# 配置 NFS Server 設定檔
echo "/nfs_shared    *(insecure,rw,sync,no_root_squash,subtree_check)" >> /etc/exports

# 啟動 NFS Server
sudo systemctl enable nfs-kernel-server && sudo systemctl restart nfs-kernel-server
```

解壓縮我們先前建立好的 root filesystem 到 NFS 分享目錄中。

```bash
# 將先前我們建置好的 root filesystem 解壓縮至我自建立的 /nfs_shared 中
sudo tar xpf ${BUILDDIR}/tmp/deploy/images/stm32mp1/core-image-minimal-stm32mp1.tar.xz -C /nfs_shared/
```

#### 修改 U-boot 的開機選項

修改 SD Card 內 bootfs 分割區中的 mmc0_extlinux/stm32mp157f-dk2_extlinux.conf，在開機的過程中u-boot 會將參數傳遞給 kernel。有興趣的同學可以參考 [nfs/nfsroot.txt][3]

```text
APPEND root=/dev/nfs rw console=ttySTM0,115200 nfsroot=${serverip}:/nfs_shared,vers=3,tcp ip=dhcp:${serverip}:${gateway}:${netmask}:${hostname}:eth0
```

> 為什麼是 **mmc0_extlinux/stm32mp157f-dk2_extlinux.conf** 這個檔案呢 ?
>  筆者現階段並沒有深究，相信隨著課程的進行。
>  我們會知道的。

重新開機之後，系統就會從 NFS 載入 root filesystem 了。

{{< figure src="images/result-boot-from-nfs.png" caption="從 NFS 載入 rootfilesystem" >}}

### 使用 SSH 登入

#### 加入 SSH Server 至系統中

修改 conf/local.conf ，在裡面加上 **dropbear** Package

```bash
echo 'IMAGE_INSTALL_append = " dropbear"' >> ${BUILDDIR}/conf/local.conf
```

重新編譯

```bash
bitbake core-image-minimal
```

依照先前的步驟，重新解壓縮剛建立好的 root filesystem 到 NFS 分享目錄中。

#### 測試

STM32MP1 重新開機後，在 Host 端使用 ssh 指令進行連接。

```bash
ssh root@${IP}

# 結果
# ssh root@10.1.100.104
# The authenticity of host '10.1.100.104 (10.1.100.104)' can't be established.
# RSA key fingerprint is SHA256:cDpQ47v01ZUkm6GpUG29F+RPOHVV7EzfDA5z/A4bDv4.
# Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
# Warning: Permanently added '10.1.100.104' (RSA) to the list of known hosts.
```

### 更多關於 conf/local.conf
- 通常會是以大寫表示，如: CONF_VERSION
- _append: 
	在原本設定的 **後方** 增加新的設定值，如: IMAGE_INSTALL_append = " dropbear"
- _prepend:
	在原本設定的 **前方** 增加新的設定值，如: FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}"
- _remove:
	用來移除當下設定值中的值，如: IMAGE_INSTALL_remove = "i2c-tools"
- _${MACHINE}:
 	用來表示，如果當時的 MACHINE 與 _${MACHINE} 相符時，使用這個設定值。
 	如: IMAGE_INSTALL_append_beaglebone = " i2c-tools"，當我們的 MACHINE 是 beaglebone 時，才會生效。
 	如: IMAGE_INSTALL_beaglebone = "busybox i2c-tools"，當我們的 MACHINE 是 beaglebone 時，才會生效。
 	
 上述的操作也可以使用符號表示
 
 - =
 	使用這個變數時，會將其展開。
 - :=
 	立即值。
 - += 
 	與 _append 相同 (要加上空白)。 (**盡量避免在 conf/local.conf 中使用**)
 - =+
 	與 _prepend 相同 (要加上空白)。(**盡量避免在 conf/local.conf 中使用**)
 - .=
 	與 _append 相同 (`不用`加上空白)。 (**盡量避免在 conf/local.conf 中使用**)
 - =.
 	與 _prepend 相同 (`不用`加上空白)。 (**盡量避免在 conf/local.conf 中使用**)
 - ?=
 	如果先前給過值的話，使用先前的值。
 - ??=
	與 **?=** 相同，但優先權更低。

#### 虛擬 Package

Virtual Package 會以 vitual/<name>命名，但它是不是真的 Package 。

{{< figure src="images/xd-1.jpg" caption="假的" >}}

常見的 virtual pacakge 有

- virtual/bootloader: u-boot, u-boot-ti-staging, ...
- virtual/kernel: linux-yocto, linux-yocto-tiny, linux-ti-staging, ...
- virtual/libc: glibc, musl, newlib
- virtual/xserver: xserver-xorg

#### 選擇

我們可以使用 `PREFERRED_PROVIDER` 來指定我們想要用的 Package。
如: PREFERRED_PROVIDER_vritual/kernel ?= "linux-ti-staging"

我們可以使用 `PREFERRED_VERSION` 來指定想使用的 Package 版本。
如: PREFERRED_VERSION_python = "2.7.3" 或是 PREFERRED_VERSION_linux-yocto = "5.4.%"

#### Root Filesystem

我們可以使用 `IMAGE_INSTALL` 來指定哪些 Packages 要加入 root filesystem 中，並可以使用 `RDEPENDS` 來指定其相依 Packages. 我們也可以使用 `PACKAGE_EXCLUDE` 來過慮我們不想要的 Packages。 

## 小結

我們已經建立了基本的 STM32MP1 Linux 系統開發環境，接下來就要一邊玩 Yocto 一邊探索 STM32MP1 的週邊了。

## 參考連結

- [STM32MP157F-DK2][1]
- [Bootlin/Yocto with STM32][slide]
- [Bootlin/Yocto with STM32 Lab][lab]
- [Wiki - STM32MP1 Distribution Package][2]
- [Kernel Document - nfsroot][3]

[1]:https://www.st.com/en/evaluation-tools/stm32mp157f-dk2.html
[2]:https://wiki.st.com/stm32mpu/wiki/STM32MP1_Distribution_Package
[3]:https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt
[slide]: https://bootlin.com/doc/training/yocto-stm32/yocto-stm32-slides.pdf
[lab]: https://bootlin.com/doc/training/yocto-stm32/yocto-stm32-labs.pdf
[flashlayout]:https://wiki.st.com/stm32mpu/wiki/STM32CubeProgrammer_flashlayout