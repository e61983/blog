---
date: 2021-08-12T15:34:03+08:00
title: "在 STM32MP1 上使用 Yocto 建置 Linux 系統 4"
description: ""
author: "Yuan"
draft: false
tags: ["stm32mp1","yocto","linux"]
keywords: []
categories: ["embedded system"]
---

## 前言

繼先前建立好基楚的系統後，我們已經加入了 bootlinlabs machine。
本文會接續之前建立的環境，開始加入自訂的 Image。

<!--more-->

## 主要內容

### Image

Image 就是 root filesystem。它會放置於 `meta*/recipes*/images/*.bb` 中。

#### Poky 預設的 Image

- core-image-base
	只提供 Console 的環境，並且支援所有硬體功能。
- core-image-minimal
	只提供 Console 的環境，並且只滿足開機的須求。
- core-image-minimal-dev
	同 core-image-minimal，但又支援額外的開發用工具。
- core-image-x11
	提供 X11 圖形化介面。
- core-iamge-rt
	同 core-image-minimal, 但額外提供 Real Time 相關工具。

#### Image 常見的配置項

- IMAGE_BASENAME
	輸出的映像檔名稱，預設為 ${PN}
- IMAGE_INSTALL
	要安裝於此映像檔的 Package / Package groups
- IMAGE_ROOTFS_SIZE
	最終的 Root filesystem 大小
- IMAGE_FEATURES
	提供的特性清單
- IMAGE_FSTYPES
	要產生的映像檔種類，例: ext2, ext3, squashfs, cpio, jffs2, ubifs, ... 等。
	可參考 [meta/classes/image_types.bbclass](https://github.com/openembedded/openembedded-core/blob/master/meta/classes/image_types.bbclass)
- IMAGE_LINGUAS
	此映像檔所支援的語言
- IMAGE_PKGTYPE
	此映像檔所使用的套件安裝種類，例: deb, rpm, ipk, tar
- IMAGE_POSTPROCESS_COMMAND
	在最後想要執行的 shell 指令

### WIC

wic 是一個用來建置可燒寫的映像檔。它可以透過 .wks 或是 .wks.in 來建立分隔區、指定檔案位置。
相關的配置如:

```txt
WKS_FILE = "imx-uboot-custom.wks.in"
IMAGE_FSTYPES = "wic.bmp wic"
```

imx-uboot-custom.wks.in:

```txt
part u-boot --source rawcopy --sourceparams="file=imx-boot" --ondisk sda --no-table --align ${IMX_BOOT_SEEK}
part /boot --source bootimg-partition --ondisk sda --fstype=vfat --label boot --active --align 8192 --size 64
part / --source rootfs --ondisk sda --fstype=ext4 --label root --exclude-path=home/ --exclude-path=opt/ --align 8192
part /home --source rootfs --rootfs-dir=${IMAGE_ROOTFS}/home --ondisk sda --fstype=ext4 --label home --align 8192
part /opt --source rootfs --rootfs-dir=${IMAGE_ROOTFS}/opt --ondisk sda --fstype=ext4 --label opt --align 8192
bootloader --ptable msdos
```

### Package Groups

用來將 Package 依其功能進行分類。通常我們可以在 `meta*/recipes-core/packagegroups/` 找到，它們會是以 `packagegroup-` 做為前綴來命名。如: packagegroup-core-boot，packagegroup-core-nfs-server。

實際撰寫時，只要繼承 packagegroup 即可。例:

```txt
SUMMARY = "Debugging tools"
LICENSE = "MIT"
inherit packagegroup
RDEPENDS_${PN} = "\
    gdb \
    gdbserver \
    strace"
```

### 建立 bootlinlabs-image-minimal

```bash
pushd ./meta-bootlinlabs
mkdir -p recipes-image/images
echo 'IMAGE_INSTALL = "packagegroup-core-boot"' >> recipes-image/images/bootlinlabs-image-minimal.bb
echo 'inherit core-image' >> recipes-image/images/bootlinlabs-image-minimal.bb
echo '' >> recipes-image/images/bootlinlabs-image-minimal.bb
echo 'IMAGE_INSTALL_append = " dropbear ninvaders"' >> recipes-image/images/bootlinlabs-image-minimal.bb
popd
bitbake bootlinlabs-image-minimal
```

更新 NFS 分享目錄
```
sudo tar xpf tmp/deploy/images/bootlinlabs/bootlinlabs-image-minimal-stm32mp1.tar.xz -C /nfs_shared/
```

重新啟重 STM32MP1

{{< figure src="images/result-image.png" caption="bootlinlabs-image-minimal" >}}

## 小結

## 參考連結
- [Customizing Images using Custom bb Files][1]
- [Bootlin/Yocto with STM32][slide]
- [Bootlin/Yocto with STM32 Lab][lab]

[1]:https://docs.yoctoproject.org/dev-manual/common-tasks.html#customizing-images-using-custom-bb-files
[slide]:https://bootlin.com/doc/training/yocto-stm32/yocto-stm32-slides.pdf
[lab]:https://bootlin.com/doc/training/yocto-stm32/yocto-stm32-labs.pdf
