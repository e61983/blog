---
date: 2021-08-12T13:23:59+08:00
title: "在 STM32MP1 上使用 Yocto 建置 Linux 系統 3"
description: ""
author: "Yuan"
draft: false
tags: ["stm32mp1","yocto","linux"]
keywords: []
categories: ["embedded system"]
---

## 前言

繼先前建立好基楚的系統後，我們已經加入了 meta-bootlinlabs Layer。
本文會接續之前建立的環境，開始加入自訂的 Machine。

<!--more-->

## 主要內容

### BSP Layer

BSP Layer 是 Layer 的一種，它通常會包含目標機器的硬體配置、Bootloader、Kernel、Display Support。常以 `meta-<bsp-name>` 命名，裡面會有 machnes 資料夾。

如果我們想知道該 BSP Layer 它支援了哪些機器，我們可以在該 Layer 中，觀察它的 conf/machine/*.conf。
目標機器的配置檔會以 `MACHINE.conf` 命名。

但更好的方式是，該 BSP Layer 有完善的 README，讓我們可以直接參考。

### Machine 常見的配置項

- TARGET_ARCH
	該機器的硬體架構，例: arm, aarch64
- PREFERRED_PROVIDER_virtual/kernel
	預設使用的 Kernel
- MACHINE_FEATURES
	提供的硬體特性清單，例: usbgadget, usbhost, screen, wifi, bluetooth
- SERIAL_CONSOLES
	要使用的序列埠與通訊速度，它會被傳給Kernel 做為 console 的參數。例: 115200;ttyS0
- KERNEL_IMAGETYPE
	要編譯的映像檔種類，例: zImage, uImage

### Bootloader 常見的配置項

- SPL_BINARY
	如果有 SPL (Secondary Program Loader)，指定此 SPL 的名稱。預設是空字串。 
- UBOOT_SUFFIX
	UBOOT的後綴，例: img。預設是 bin。
- UBOOT_MACHINE
	目前機器所使用的配置檔。
- UBOOT_ENTRYPOINT
	Bootloader 的進入點。例: 0xC0800000
- UBOOT_LOADADDRESS
	Bootloader 載入位置。
- UBOOT_MAKE_TARGET
	Makefile 的目標，預設是 all

### Kernel 常見的配置項

Kernel 的配置也會撰寫在 `<machine>.conf` 中

- PREFERRED_PROVIDER_virtual/kernel
	指定要使用的 Kerenl Package
- PREFERRED_VERSION_linux-yocto = "5.10\%"
	指定要使用的版本
- SRC_URL
	必須提供 Kernel 配置檔，並命名為 defconfig。
	```
	SRC_URL += "file://defconfig		\
				file://nand-support.cfg	\
				file://ethernet-support.cfg \
				" 	
### Kernel Metadata 常見的配置項

- LINUX_KERNEL_TYPE
	- standard (預設)
	- tiny
	- preempt-rt
- KERNEL_FEATURES
	提供的 Kernel 特性清單

資料夾結構

- bsp/
- cfg/
- features/
	例: features/smp.scc
	KERNEL_FEATURES += "features/smp.scc" 
	```txt
	 define KFEATURE_DESCRIPTION "Enable SMP"
	 kconf hardware smp.cfg
	 patch smp-support.patch
- ktypes/
- patches/
	
#### 調整 Kernel 配置

調整 Kernel 配置時，我們可以以提供 defconfig 的方式進行。或是提供 Configure Fragments 進行調整。

- 提供 defconfig
	```bash
	# 配置 Kernel
	bitbake -c kernel_configme linux-yocto
	
	# 手動調整 Kernel 選項
	bitbake -c menuconfig linux-yocto
	
	# 產生 .config
	bitbake -c savedefconfig  linux-yocto
	
	# 我們再自行將 .confg 存為 defconfig
- 提供 Configure Fragments
	```bash
	# 配置 Kernel
	bitbake -c kernel_configme linux-yocto
	
	# 手動調整 Kernel 選項
	bitbake -c menuconfig linux-yocto
	
	# 產生 Configure Fragments
	bitbake -c diffconfig linux-yocto
	
	# 確認 Configure Fragments 是否有正確被套用
	bitbake -c kernel_configcheck -f linux-yocto
### 建立 bootlinlabs Machine

我們可以參考 meta-st-stm32mp/conf/machine 的配置進行 bootlinlabs Machine 的建立。

```bash
pushd ../meta-bootlinlabs

# 建立 machine 資料夾
mkdir conf/machine

# 建立 bootlinlabs 配置檔
echo 'require conf/machine/include/st-machine-common-stm32mp.inc' >> conf/machine/bootlinlabs.conf
echo 'require conf/machine/include/st-machine-providers-stm32mp.inc' >> conf/machine/bootlinlabs.conf
echo '' >> conf/machine/bootlinlabs.conf
echo 'DEFAULTTUNE = "cortexa7thf-neon-vfpv4"' >> conf/machine/bootlinlabs.conf
echo 'require conf/machine/include/tune-cortexa7.inc' >> conf/machine/bootlinlabs.conf
echo '' >> conf/machine/bootlinlabs.conf
echo 'BOOTSCHEME_LABELS += "trusted"' >> conf/machine/bootlinlabs.conf
echo 'STM32MP_DT_FILES_DK += "stm32mp157f-dk2"' >> conf/machine/bootlinlabs.conf
echo 'FLASHLAYOUT_CONFIG_LABELS += "sdcard"' >> conf/machine/bootlinlabs.conf
popd
```

修改 conf/local.conf 內的 MACHINE，並重新編譯。

```bash
sed -i 's/^MACHINE.*/MACHINE ?= "bootlinlabs"/g' conf/local.conf
bitbake core-image-minimal
```

我們可以在 `${BUILDDIR}/tmp/deploy/images/**bootlinlabs**/` 看到我們所建立的新 Machine。

```txt
$ ls tmp/deploy/images/bootlinlabs/
arm-trusted-firmware
bootloader
core-image-minimal-bootlinlabs-20210812144202_nand_4_256_multivolume.rootfs.ubi
core-image-minimal-bootlinlabs-20210812144202_nand_4_256_multivolume.ubinize.cfg.ubi
core-image-minimal-bootlinlabs-20210812144202_nand_4_256.rootfs.ubi
core-image-minimal-bootlinlabs-20210812144202_nand_4_256.rootfs.ubifs
core-image-minimal-bootlinlabs-20210812144202_nand_4_256.ubinize.cfg.ubi
core-image-minimal-bootlinlabs-20210812144202.rootfs.ext4
core-image-minimal-bootlinlabs-20210812144202.rootfs.manifest
core-image-minimal-bootlinlabs-20210812144202.rootfs.tar.xz
core-image-minimal-bootlinlabs-20210812144202.testdata.json
core-image-minimal-bootlinlabs.ext4
core-image-minimal-bootlinlabs.manifest
core-image-minimal-bootlinlabs_nand_4_256_multivolume.ubi
core-image-minimal-bootlinlabs_nand_4_256_multivolume.ubinize.cfg.ubi
core-image-minimal-bootlinlabs_nand_4_256.ubi
core-image-minimal-bootlinlabs_nand_4_256.ubifs
core-image-minimal-bootlinlabs_nand_4_256.ubinize.cfg.ubi
core-image-minimal-bootlinlabs.tar.xz
core-image-minimal-bootlinlabs.testdata.json
flashlayout_core-image-minimal
kernel
scripts
```

### Distro Layer

通常 Distro Layer 會包含 Libc，initialization script, splash screen, ... 等, 相關的配置會記錄在 `conf/distro/<distro>.conf` 中。

在 `<distro>.conf` 中必須包含 `DISTRO` 變數。例:
 
```txt
require conf/distro/poky.conf

DISTRO = "distro"
DISTRO_NAME = "distro description"
DISTRO_VERSTION = "1.0"

MAINTAINER = "..."

# 提供的特性清單
DISTRO_FEATURES = "..."

# 提供的特性清單，它同時會作用在 MACHINE_FEATURES 
COMBINED_FEATURES = "..."

# Toolchain
TCMODE = "..."
```

## 小結

本次實做的部份比較少，重心主要放在瞭解 machine，distro 的配置。

## 參考連結
- [Bootlin/Yocto with STM32][slide]
- [Bootlin/Yocto with STM32 Lab][lab]

[slide]:https://bootlin.com/doc/training/yocto-stm32/yocto-stm32-slides.pdf
[lab]:https://bootlin.com/doc/training/yocto-stm32/yocto-stm32-labs.pdf