---
date: 2021-09-13T11:38:39+08:00
title: "在 i.MX 8QuadXPlus 上使用 Yocto 建置 Linux 系統 4"
subtitle: "從 NFS 載入根檔案系統 (rootfs) "
description: ""
author: "Yuan"
draft: false
tags: ["i.mx8qxp","u-boot","yocto","linux","nfs","tftp"]
keywords: []
categories: ["embedded system"]
---

## 前言

為了在之後開發過程中不用反覆燒寫 eMMC 與 SD 卡，本篇會設定 U-Boot 載入 Rootfs 以達到我們的目的。

<!--more-->

## 主要內容

### 寫在前面

我們這次的目標是從 NFS 伺服器中載入 Rootfs。所以我們在開機時，U-Boot 載入的 Kernel 與裝置樹 ( Devicetree ) 仍是 eMMC/SD 卡內的。

在開機的過程中，首先會要把要執行的東西載入到記憶體中執行。
所以我們可以預期，待會我們會需要載入 Kernel 與 裝置樹。
最後才把主控權交給 Kernel。

我們要做的就是在執行時期，修改 U-Boot 傳給 Kernel 的開機參數。

### 配置 NFS 伺服器

這一個部份先前有筆記過了，如果還沒有看過的同學請參考[這裡]({{< ref "stm32mp-with-yocto/#建置-nfs-環境" >}})。

### 分析 Kernel 與 Devicetree 的載入命令

U-Boot 預設開機在基本的初始化完成後，並且在指定的秒數內沒有都收到使用者的輸入，便會開始執行 **bootcmd** 中的內容。
我們可以藉由分析它，來初步的知道系統的開機流程。

```bash
print bootcmd

# Output:
bootcmd=mmc dev ${mmcdev}; if mmc rescan; then if run loadbootscript; then run bootscript; else if test ${sec_boot} = yes; then if run loadcntr; then run mmcboot; else run netboot; fi; else if run loadimage; then run mmcboot; else run netboot; fi; fi; fi; else booti ${loadaddr} - ${fdt_addr}; fi
```

整理過後, 我們可以觀察到它真正會執行到的指令為 `run loadimage `，接著會是 `run mmcboot `

```bash
bootcmd=
	mmc dev ${mmcdev};
	if mmc rescan; then 
		if run loadbootscript; then 
			run bootscript; 
		else 
			if test ${sec_boot} = yes; then 
				if run loadcntr; then 
					run mmcboot; 
				else
					run netboot; 
				fi;
			else
				if run loadimage; then 
					run mmcboot; 
				else
					run netboot; 
				fi; 
			fi; 
		fi; 
	else
		booti ${loadaddr} - ${fdt_addr}; 
	fi
```

從 eMMC 中把 Kernel 載到記憶體裡面 

```txt
loadimage=fatload mmc ${mmcdev}:${mmcpart} ${loadaddr} ${image}
```

繼續展開 `mmcboot`

```txt
mmcboot=
	echo Booting from mmc ...; 
	run mmcargs;
	if test ${sec_boot} = yes; then
		if run auth_os; then 
			run boot_os; 
		else
			echo ERR: failed to authenticate; 
		fi;
	else
		if test ${boot_fdt} = yes || test ${boot_fdt} = try; then 
			if run loadfdt; then 
				run boot_os; 
			else
				echo WARN: Cannot load the DT; 
			fi; 
		else
			echo wait for boot; 
		fi;
	fi;
```

從 eMMC 中把 裝置樹 ( Devicetree ) 載到記憶體裡面 

```txt
loadfdt=fatload mmc ${mmcdev}:${mmcpart} ${fdt_addr} ${fdt_file}
```

開始載入 Kernel ，之後就會把控制權交給 Kernel 了。

```txt
boot_os=booti ${loadaddr} - ${fdt_addr};
```

{{< notice info "小提示" >}}
我們可以使用 `echo $?` 來看返回值。
{{< /notice >}}

### 設定 U-Boot 環境變數

從先前的分析來看，比較重要的指令有:

- loadfdt
- loadimage
- boot_os

所以我們只要進行下列修改，即可。

```txt
setenv serverip "NFS_SERVER_IP"
setenv rootfs_dir "/srv/rootfs"
setenv ethaddr "01:02:03:04:05:06"
setenv image Image
setenv fdt_file imx8qxp-mek-rpmsg.dtb

setenv rootfsinfo 'setenv bootargs ${bootargs} root=/dev/nfs ip=dhcp nfsroot=${serverip}:${rootfs_dir},v3,tcp'
setenv bootcmd 'run rootfsinfo; run loadfdt; run loadimage; run boot_os'

saveenv
```

{{< notice info "還原回預設值" >}}

如我們想還原回預設值，可以使用下列指令

```txt
env default -a
saveenv
```
{{< /notice >}}

### 結果

我們可以重新啟動系統，或是直接執行 `boot` 就可以看到 U-Boot 正在開始執行我們剛才所撰寫的指令了。
會發現，開機的時候有稍微變長了，並且在過程中可以看到 `NFS` 相關的字樣。

開機完成後，我們可以在 `/proc/cmdline` 看到我們先前指定的開機參數(bootarg)。

{{< figure src="images/result.png" caption="從 NFS 伺服器中載入 rootfs" >}}

### 寫在最後
在 U-Boot 中看到的參數，在本篇並沒有多去探究。不過也別太過傷心，以後我們會專門製作一篇為大家講解。

```txt
loadaddr=0x80280000
fdt_addr=0x83000000
image=Image
fdt_file=imx8qxp-mek-rpmsg.dtb
```

## 小結

這次在撰寫本篇時，其實是想把 Kernel 與裝置樹都從網路載下來的。
但礙於筆者的網路環境比較複雜，一直無法成功的藉由 TFTP 傳輸資料。
所以也就暫時作罷。
未來如果有完成這個部份再來更新吧。

( 附上當時的筆記 )

### 配置 TFTP 伺服器

#### 安裝 TFTP

```bash
sudo aptitude install -y tftpd-hpa
```

#### 配置分享路徑

```bash
sudo cp /etc/default/tftpd-hpa{,.bk} 
sudo sed -i 's#TFTP_DIRECTORY.*#TFTP_DIRECTORY="/srv/tftp_shared"#g' /etc/default/tftpd-hpa
sudo sed -i 's#TFTP_ADDRESS.*#TFTP_ADDRESS=":69"#g' /etc/default/tftpd-hpa
sudo sed -i 's#TFTP_OPTIONS.*#TFTP_OPTIONS="--secure --create"#g' /etc/default/tftpd-hpa

sudo systemctl enable tftpd-hpa
sudo systemctl restart tftpd-hpa
```

/etc/default/tftpd-hpa:

```txt
# /etc/default/tftpd-hpa
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp_shared/"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure --create"
```

#### 配置防火牆

```bash
sudo firewall-cmd \
	--add-rich-rule="rule family='ipv4' source address='192.168.1.2' service name='tftp' accept" \
	--permanent
sudo firewall-cmd --reload
```

#### 除錯

```bash
sudo netstat -nlp
sudo journalctl -fu  tftpd-hpa.service
```

#### 用戶端測試

在伺服器中建立測試用的資料

```base
echo "Hello word" > /srv/tftp_shared/hello
```

在用戶端進行上、下載測試

```bash
echo "I am Groot~~~~~" > groot.txt

tftp SERVER_IP
tftp get hello
tftp put groot.txt
```

## 參考連結

- [i.MX Linux® User's Guide][1]

[1]:https://www.nxp.com/docs/en/user-guide/IMX_LINUX_USERS_GUIDE.pdf
