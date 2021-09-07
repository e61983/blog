---
date: 2021-09-07T01:21:50+08:00
title: "在 i.MX 8QuadXPlus 上使用 Yocto 建置 Linux 系統 3"
subtitle: "使用 UUU 燒寫 eMMC"
description: ""
author: "Yuan"
draft: false
tags: ["i.mx8qxp","yocto","linux"]
keywords: []
categories: ["embedded system"]
---

## 前言

UUU 全名為 Universal Update Utility。對 NXP i.MX 系列熟悉的使用者對 MFGTools 一定不會感到陌生，UUU 就是從 MFGTools 演進而來的，也稱為 MFGTools v3。它是用來進行 Freescale/NXP 晶片的映像檔燒錄。

本篇將使用 UUU 將[我們先前建立的映像檔]({{< ref "yocto-with-imx8qxp-2/#重新編譯映像檔並燒寫至-sd-卡" >}})燒寫至 eMMC 中。
<!--more-->

## 主要內容

### 寫在前面

為了要燒寫 bootloader 以及我們的系統至 eMMC，我們參考 [IMX_LINUX_USERS_GUIDE.pdf](https://www.nxp.com/docs/en/user-guide/IMX_LINUX_USERS_GUIDE.pdf) 4.2.2 Using UUU
>Follow these instructions to use the UUU for i.MX 6, i.MX 7, i.MX 8:
>1. Connect a USB cable from a computer to the **USB OTG/TYPE C port** on the board.
>2. Connect a USB cable from the **OTG-to-UART port** to the computer for console output.
>3. Open a Terminal emulator program. See Section "Basic Terminal Setup" in this document.
>4. Set the boot pin to serial download mode mode. See Section "Serial download mode for the Manufacturing Tool" in this document.

### 燒寫前的準備

#### 修改主板的 Boot 配置

將 **boot mode**  配置為 **Serial Download Mode (1000)**

{{< figure src="images/serial-mode.png" caption="切換為 Serial Download" >}}

#### 連接 USB Type C  

連接好 USB Type C 線到 Host 上。

{{< figure src="images/usb-type-c.png" caption="USB Type C" >}}

連接好 USB Type C 線之後，我們可以輸入下列指令來確認是否有連接上。

```bash
./uuu_mac -lsusb

# Output

# uuu (Universal Update Utility) for nxp imx chips -- libuuu_1.4.139-0-g1a8f760
#
# Connected Known USB Devices 
#	Path	 Chip	 Pro	 Vid	 Pid	 BcdVersion
#	==================================================
#	20:2	 MX8QXP	 SDPS:	 0x1FC9	0x012F 0x0004
```

### 下載 UUU

筆者是使用 MacOS，所以下載時是下載 mac 的版本。

```bash
wget https://github.com/NXPmicro/mfgtools/releases/download/uuu_1.4.139/uuu_mac
chmod o+x uuu_mac
./uuu_mac
```

{{< notice error "Library not loaded: /usr/local/opt/libzip/lib/libzip.5.dylib" >}}
dyld: Library not loaded: /usr/local/opt/libzip/lib/libzip.5.dylib
  Referenced from: /tmp/uuu_mac
  Reason: image not found
[1]    5351 abort      ./uuu_mac

解決的方式，就是安裝缺少的函式庫 **libzip**

```bash
brew install libzip
```
{{< /notice >}}

### 燒寫 Bootloader

我們將輸入下列指令來使用 UUU 來寫入 U-Boot 到 eMMC 中。

```bash
sudo ./uuu_mac -b emmc imx-boot-imx8qxpc0mek-sd.bin-flash_spl

# Output
# uuu (Universal Update Utility) for nxp imx chips -- libuuu_1.4.139-0-g1a8f760

# Success 1    Failure 0

# 20:433   7/ 7 [Done                                  ] FB: Done
```

{{< notice error "Failure claim interface" >}}

如果同學也遇到了這個問題，可以去使用最新的 libusb 函式庫。

uuu (Universal Update Utility) for nxp imx chips -- libuuu_1.4.139-0-g1a8f760
Success 0    Failure 1
20:2     1/ 2 [Failure claim interface               ] SDPS: boot -f "./u-boot-imx8qxpc0mek.bin-sd"

```bash
# 參考 https://github.com/NXPmicro/mfgtools/issues/246#issuecomment-898894168
brew install --head libusb
brew unlink libusb
brew link --head libusb
```
{{< /notice >}}

### 燒寫整個系統

我們透過下列指令來寫入整個系統。

```bash
sudo ./uuu_mac -b emmc_all imx-boot-imx8qxpc0mek-sd.bin-flash_spl "imx-image-core-imx8qxpc0mek.wic.bz2/*"

# Output:
# uuu (Universal Update Utility) for nxp imx chips -- libuuu_1.4.139-0-g1a8f760

# Success 1    Failure 0

# 20:433   8/ 8 [Done                                  ] FB: done
```

### 在虛擬器中進行燒寫

如果同學們是使用虛擬器的環境，要特別注意 USB 埠的分享設定。記得如果有多個的話都要選到唷! 

{{< figure src="images/usb-filter.png" caption="虛擬器的USB 埠分享設定" >}}

### 結果

將 **boot mode**  配置為 **eMMC Mode (0100)**，並重新開機之後即可看到與先前相同的輸出了。

{{< figure src="images/emmc-mode.png" caption="切換為 eMMC Mode" >}}

## 小結

UUU 有支援 Fastboot 相關的指令，本篇並沒有太多的著墨。有興趣的同學可以自行玩玩看。

## 參考連結

- [NXPmicro/mfgtools][NXPmicro/mfgtools]
- [【ATU Book-i.MX8系列】 UUU（Universal Update Utility）][1]
- [imx8mq - Bootloader 編譯過程][2]
- [i.MX8 uuu][3]

[NXPmicro/mfgtools]:https://github.com/NXPmicro/mfgtools/wiki
[1]:https://www.wpgdadatong.com/tw/blog/detail?BID=B1389
[2]:https://blog.csdn.net/weixin_42264572/article/details/90490362
[3]:https://wowothink.com/2e4a33d4/
