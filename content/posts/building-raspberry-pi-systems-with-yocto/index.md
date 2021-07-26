---
date: 2021-07-26T17:37:57+08:00
title: "使用 Yocto 打造你的 Raspberry Pi 系統"
description: ""
author: "Yuan"
draft: false
tags: ["linux", "yocto"]
keywords: []
categories: ["embedded system"]
---

## 前言

手邊有一片很久沒有動過的 Raspberry Pi 3 B+。剛好最近工作上需要在 imx8 進行開發。藉此順便先練練手。

<!--more-->

## 主要內容

### 準備 Yocto 環境

1. 建立我們要開發的資料夾 ```my-rpi```，接下來我們都會在這個資料夾中進行操作。
2. 下載 poky 。

```bash
mkdir my-rpi && cd my-rpi
git clone -b hardknott git://git.yoctoproject.org/poky.git
```

準備 meta-raspberrypi 層

```bash
git clone -b hardknott git://git.yoctoproject.org/meta-raspberrypi
```

初始化開發環境

```bash
source poky/oe-init-build-env build-rpi
```

加入 meta-raspibary 層

```bash
bitbake-layers add-layer ../meta-raspberrypi
```

### 修改配置

```bash
sed -i 's/^MACHINE.*/MACHINE ?= "raspberrypi3"/g' conf/local.conf
sed -i '/^#DL_DIR ?= "${TOPDIR}\/downloads"/ a DL_DIR ?= \"${HOME}/yocto/downloads"' conf/local.conf
sed -i 's/^PACKAGE_CLASSES.*/PACKAGE_CLASSES ?= "package_ipk"/g' conf/local.conf

echo 'RPI_USE_U_BOOT = "1"' >> conf/local.conf
echo 'ENABLE_UART = "1"' >> conf/local.conf
```

### 開始編譯

```bash
bitbake core-image-minimal
```

### 寫入 SD Card

```bash
bzip -Dk core-image-minimal-raspberrypi3.wic.bz2
sudo dd if=core-image-minimal-raspberrypi3.wic of=${SD_CARD} bs=40960
```

## 小結

編譯出來的系統已可以開始，並在UART 終端機看到開始時的輸出，以及可以使用root 進入系統。

## 參考連結

- [Yocto official][yocto]
- [meta-raspberrypi][meta-raspberrypi]
- [Building Raspberry Pi Systems with Yocto][yocto-rpi]

[yocto]:https://www.yoctoproject.org
[meta-raspberrypi]:http://git.yoctoproject.org/cgit/cgit.cgi/meta-raspberrypi
[yocto-rpi]:https://jumpnowtek.com/rpi/Raspberry-Pi-Systems-with-Yocto.html
