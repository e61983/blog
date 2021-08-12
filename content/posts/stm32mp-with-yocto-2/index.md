---
date: 2021-08-12T09:22:34+08:00
title: "在 STM32MP1 上使用 Yocto 建置 Linux 系統 2"
description: ""
author: "Yuan"
draft: false
tags: ["stm32mp1","yocto","linux"]
keywords: []
categories: ["embedded system"]
---

## 前言

繼先前建立好基楚的系統後，我們已經可以順利開機，並從 NFS 載入 rootf filesystem。
本文會接續之前建立的環境，開始加入自製的程式以及自訂的 Layer。

<!--more-->

## 主要內容

### Recipe

Recipe 是以 `<APPLICATION_NAME>_<VERSION>.bb` 的方式命名。裡面會包含這個 Package 該如何「穫取源始碼、Patch、編譯、安裝」的方法、它的授權方式以及它的相依套件/Package。

為了簡化 Recipe  以及避免過多的重複，我們可以將共同的部份撰寫在 `<APPLICATION>.inc` 並在 Recipe 中引用。

#### 常見的配置項

- DESCRIPTION
	說明、介紹此 Package
- HOMEPAGE
	如果此 Package 的專案有介紹網站的話，可以寫在此
- PRIORITY
	預設是: optional
- SECTION
	這個 Package 的分類。例: console/utils
- LICENSE
	這個 Package 的授權方式
- SRC_URL
	這個 Package 源始碼位置
	它的格式為: `scheme://<ur>l;param1;param2`
	scheme 可以是 https, git, svn, hg, ftp, file, ...
- SRC_URL[md5sum], SRC_URL[sha256sum]
	源始碼的檢查碼設置。
	例:
	- SRC_URI = "http://example.com/src.tar.bz2;name=tarball"
		SRC_URI[tarball.md5sum] = "97b2c3fb082241ab5c56..."
		- git  scheme:
			git:`<url>`;protocol=`<protocol>`;branch=`<branch>`
		- http,https,ftp:
			https://`<url>`
			也可以使用一些變數來設置位置，例: ${SOURCEFORGE_MIRROR}/`<project-name>`/${PN}-${PV}.tar.gz
			詳細資訊可以參考 [meta/conf/bitbake.conf](https://raw.githubusercontent.com/openembedded/openembedded-core/master/meta/conf/bitbake.conf)
			
- S
	獲取後、解壓縮後的源始碼路目錄。通常會配置為 `${WORKDIR}`
	**如果是使用 git 來獲取程式碼，則一定要設置成** `${WORKDIR}/git`

- FILESPATH
	本機檔案的搜尋路徑。
	```txt
	FILESPATH = "${@base_set_filespath(["${FILE_DIRNAME}/${BP}",
				"${FILE_DIRNAME}/${BPN}","${FILE_DIRNAME}/files"], d)}"
- FILESOVERRIDES
	本機檔案的搜尋路徑。
	```txt
	FILESOVERRIDES = "${TRANSLATED_TARGET_ARCH}:${MACHINEOVERRIDES}:${DISTROOVERRIDES}"
- LIC_FILES_CHKSUM
	```txt
	LIC_FILES_CHKSUM = "file://gpl.txt;md5=393a5ca..."
	LIC_FILES_CHKSUM =  "file://main.c;beginline=3;endline=21;md5=58e..."
	LIC_FILES_CHKSUM =  "file://${COMMON_LICENSE_DIR}/MIT;md5=083..."
- DEPENDS
	在編譯時期的相依套件/Package。
	```txt
	DEPENDS = "recipe-b"
	DEPENDS = "recipe-b (>= 1.2)"
- RDEPENDS	
	在執行時期的相依套件/Package。
	```txt
	RDEPENDS_${PN} = "recipe-b"
	RDEPENDS_${PN} = "recipe-b (> 1.2)"

#### 常見的變數

- PN
	表示 Package Name 
- BPN
	移除 PN 的前綴與後綴。例: nativesdk- 或是 -native。
- PV
	表示 Package Version 
- PR
	表示 Package Revision。預設是: r0 
- BP
	表示 ${BPN}-${PV} 
- WORKDIR
	表示 Recipe 工作時期的目錄
- D
	表示安裝時的目標目錄
	```txt
	do_install() {
		install -d ${D}${bindir}
		install -m 0755 hello ${D}${bindir}
	}

#### Task

在 Recipe 中有許的預設的 task，我們可以自訂、修改它們來滿足我們的需求。

- do_fetch
- do_unpack
- do_patch
- do_configure
- do_compile
- do_install
- do_package
- do_rootfs

{{< notice info >}}
我們可以使用下列指令來顯示該 Recipe 有哪些 Task
bitbake `<recipe>` -c listtasks
{{< /notice >}}
	
##### 加入自訂的 Task

```txt
do_mkimage() {
	uboot-mkimage ...
}
addtask do_mkimage after do_compile before do_install
```

#### Example Recipe

下列是一個 Recipe 的範例

```txt
DESCRIPTION = "Hello world program"
HOMEPAGE = "http://example.net/hello/"
PRIORITY = "optional"
SECTION = "examples"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""
FILESOVERRIDES_prepend := "${THISDIR}/${PN}_${PV}:"
SRC_URI = " \
           file://main.c \
           file://Makefile \
           "
           
S = "${WORKDIR}"

do_configure () {
}
do_compile () {
	oe_runmake
}
do_install () {
    oe_runmake install 'DESTDIR=${D}'
}
```

{{< notice info "如何除錯" >}}
我們可以透過下列指令來看到編譯時期 pacakge 的配置。

```bash
bitbake -e `<package>` 
```

我們也可以使用下列指令來喚出編譯環境進行操作。 
```bash
	bitbake -c devshell `<package>`
```
{{< /notice >}}

#### 擴展 Recipe

通常不建議直接修改上游的配置，但常常我們又會遇到需要調整程式的需求。這時候我們可以使用 Recipe Extension (.bbappend)。
它的命名方式為 `<appliction>_<version>`.bbappend

recipe-b_%.bbappend:
> 這要的 % 為萬用字元，在此代表任意版本。

```txt 
FILESEXTRAPATHS_prepend := "${THISDIR}/files:"
SRC_URI += "file://custom-modification-0.patch \
            file://custom-modification-1.patch \
"
```

#### 自訂 Virtual Packages

我們可以透過 `PROVIDES = "virtual/<package>"` 來表示。

#### Class

我們可以提出共同的配置，撰寫成 `.bbclass` 。在不同的 Recipe 要使用時，就可以以 `inherit <class>` 來使用它。
常見到地方有 Build System。例: cmake, make, autotools, ...。更多我們可以在 `meta/classes` 中找到

##### Base Class

已包含了 fetch, unpack, compile, ... 等 Task。可以使用 `oe_runmake` 並透過 `EXTRA_OEMAKE` 來指定參數。

##### Kernel Class

用來建置 Linux Kernel 的 Class。它已配置了 PROVIDE，並且可以使用下列幾個變數:
- KERNEL_IMAGETYPE
- KERNEL_EXTRA_ARGS
- INITRAMFS_IMAGE

##### Useradd Class

用來新增系統的使用者。在使用的時候必須指定 **USERADD_PACKAGES**，詳情可參考 [useradd-example.bb](https://git.yoctoproject.org/cgit.cgi/poky/tree/meta-skeleton/recipes-skeleton/useradd/useradd-example.bb)。

我們可以透過 `USERADD_PARAM` 與 `GROUPADD_PARAM` 來傳遞參數給 useradd 及 groupadd

例:

```txt
DESCRIPTION = "useradd class usage example"
PRIORITY = "optional"
SECTION = "examples"
LICENSE = "MIT"
SRC_URI = "file://file0"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bc..."
inherit useradd 
USERADD_PACKAGES = "${PN}"
USERADD_PARAM = "-u 1000 -d /home/user0 -s /bin/bash user0"
do_install() {
install -m 644 file0 ${D}/home/user0/ chown user0:user0 ${D}/home/user0/file0
}
```

### Layer

Layer 是以 `meta-<LAYER_NAME>` 的方式命名。裡面會包含這個一個或數個 Recipe。
Bitbake 會獲取 `${BUILDDIR}/conf/bblayers.conf` 中每個 Layer 的配置，進而開始建置系統。
所以，如果我們想要加入 Layer 時，必須將其加入至 `BBLAYERS` 變數中。

#### meta-bootlinlabs

建立 meta-bootlinlabs 並加入 `BBLAYERS` 中。

```bash
cd ${BUILDDIR}
bitbake-layers create-layer -p 7 ../meta-bootlinlabs
bitbake-layers add-layer ../meta-bootlinlabs/
```

#### 加入 recipe-ninvaders

```bash
pushd ../meta-bootlinlabs
mkdir -p recipes-ninvaders/ninvaders
recipetool create -o recipes-ninvaders/ninvaders/ninvaders_git.bb https://github.com/TheZ3ro/ninvaders
popd
bitbake ninvaders
```
{{< notice error "make: *** No rule to make target 'globals.o', needed by 'nInvaders'.  Stop." >}}
筆者在編譯時遇到了下列錯誤，如果有同學也遇到相同的問題，可以進行下列提到的修改。

**ERROR**: ninvaders-1.0+gitAUTOINC+c6ab4117ba-r0 do_compile: oe_runmake failed
**ERROR**: ninvaders-1.0+gitAUTOINC+c6ab4117ba-r0 do_compile: Execution of '/home/yuan/workspace/yocto-stm32-labs/build/tmp/work/cortexa7t2hf-neon-vfpv4-poky-linux-gnueabi/ninvaders/1.0+gitAUTOINC+c6ab4117ba-r0/temp/run.do_compile.2732811' failed with exit code 1:
make: *** No rule to make target 'globals.o', needed by 'nInvaders'.  Stop.
**WARNING**: exit code 1 from a shell command.

ninvaders_git.bb:
```diff
- inherit autotools
+ inherit autotools-brokensep
```
> The problem is most likely that you're not using automake but the
> generated recipe (would have been useful to include that) is using the
> autotools class, which assumes correct use of both autoconf and
> automake.  Specifically, your hand-written Makefile doesn't handle
> out-of-tree builds.
> 
> Source: [[yocto] Adding nInvaders game package recipe](https://www.yoctoproject.org/pipermail/yocto/2018-September/042600.html)

{{< /notice >}}

#### 將 ninvaders 加入 root filesystem 中

重新編譯後，記得要更新 NFS 分享目錄 

```bash
echo 'IMAGE_INSTALL_append = " ninvaders"'
bitbake core-image-miminal
```

接著重新啟動 STM32MP1 之後，執行 nInvaders

{{< figure src="images/result-nInvaders.png" caption="nInvaders 執行結果">}}

## 小結

因為筆者手邊沒有 Nunchuk ，所以也就沒有進行 Lab 5 了。
有興趣的同學，再自己玩玩看囉!

## 參考連結
- [OpenEmbedded Layer Index][1]
- [TheZ3ro/ninvaders][ninvaders]
- [Bootlin/Yocto with STM32][slide]
- [Bootlin/Yocto with STM32 Lab][lab]

[1]:https://layers.openembedded.org/layerindex/branch/master/layers/
[ninvaders]:https://github.com/TheZ3ro/ninvaders
[slide]:https://bootlin.com/doc/training/yocto-stm32/yocto-stm32-slides.pdf
[lab]:https://bootlin.com/doc/training/yocto-stm32/yocto-stm32-labs.pdf
