---
date: 2021-07-28T12:28:09+08:00
title: "Yocto First Layer"
description: ""
author: "Yuan"
draft: false
tags: ["yocto"]
keywords: []
categories: ["embedded system"]
resources:
- src: image/result-example.png
- src: images/result-hello-image.png
---

## 前言

在準備完開發環境之後，接下來就要開始加上我們的設定、服務或是應用了。

<!--more-->

## 主要內容

在進行下列操作前，我們需要先初始化 Yocto 環境，如果還不知道要如何進行的同學，可以參考[這邊][1]。

### 建立我們的 "層"

建議是將我們的 Layer 放在建置資料夾( first-build )的外面。所以我們將在它的上一層目錄建立我們的 Layer `meta-first-layer`。

```bash
cd ..
ls # first-build poky 
bitbake-layers create-layer meta-first-layer
ls # first-build meta-first-layer poky 
```

### 加入我們的 "層"

在建置資料夾( first-build ) 中執行下列指令，它會幫我們更新 `conf/bblayer.bb` 的內容。

```bash
cd first-build
bitbake-layers add-layer ../meta-first-layer
```

### Recipes-example

我們在建立 `meta-first-layer` 時，bitbake-layers 會順便幫我們建立 `recipes-example`。
我們可以透過下列指令，看到它的輸出結果。

```bash
bitbake example
```
執行結果:
{{< figure src="images/result-example.png" caption="執行結果" >}}

### 建立我們的 Recipes-Hello

Yocto 專案提供了許多便捷的工具，其中 recipetool 與 devtool 便是與 Recipes 較為相關。  
接下來我們將會使用 recipetool 來建立我們的 Recipes。

建立 recipes-hello 資料夾，並在 files 中放入我們的源始碼。

```bash
mkdir -p recipes-hello/hello/files
cd recipes-hello/hello
```

main.c:
```c
#include <stdio.h>

int main(int argc, char *argv[]) {
  printf("Hello\n");
  return 0;
}
```

Makefile:
```Makefile
SRCS := main.c
OBJS := $(SRCS:.c=.o)
bindir ?= /usr/bin

TARGET := hello

all: $(TARGET)

%.o : %.c
	$(CC) -c $< -o $@ ${LDFLAGS}

$(TARGET) : $(OBJS)
	$(CC) $^ -o $@ ${LDFLAGS}

install:
	install -d $(DESTDIR)$(bindir)
	install -m 755 $(TARGET) $(DESTDIR)$(bindir)/
```

使用 recipetool 建立 recipe

```bash
recipetool create -o hello_0.1.bb files
``` 

修改產生出的 hello_0.1.bb

```python
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

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

回到 first-build 進行測試

```bash
bitbake hello
```
可以正常的進行編譯，但在最後出現了問題。

{{< notice error "" >}}
__ERROR__: hello-0.1-r0 do_package_qa: QA Issue: File /usr/bin/hello in package hello doesn't have GNU_HASH (didn't pass LDFLAGS?) [ldflags]  
__ERROR__: hello-0.1-r0 do_package_qa: QA run found fatal errors. Please consider fixing them.  
__ERROR__: Logfile of failure stored in: /home/yuan/first-build/tmp/work/cortexa7t2hf-neon-vfpv4-poky-linux-gnueabi/hello/0.1-r0/temp/log.do_package_qa.2726283  
__ERROR__: Task (/home/yuan/meta-first-layer/recipes-hello/hello/hello_0.1.bb:do_package_qa) failed with exit code '1'  
{{< /notice >}}

參考[這篇文章][2]修改 hello_0.1.bb

```diff
do_install () {
    oe_runmake install 'DESTDIR=${D}'
}
+
+ INSANE_SKIP_${PN} = "ldflags"
+ INSANE_SKIP_${PN}-dev = "ldflags"

```

### 建立我們的 image

在 recipes-hello 中建立 images 資料夾。

```bash
mkdir -p recipes-hello/images
cd recipes-hello/images
cp ../../../poky/meta/recipes-core/images/core-image-minimal.bb hello-image.bb
```

hello-image.bb:
```python
SUMMARY = "A hello image that just for testing our layer"

LICENSE = "MIT"

IMAGE_INSTALL = "packagegroup-core-boot ${CORE_IMAGE_EXTRA_INSTALL} hello"

inherit core-image

IMAGE_ROOTFS_SIZE ?= "8192"
IMAGE_ROOTFS_EXTRA_SPACE_append = "${@bb.utils.contains("DISTRO_FEATURES", "systemd", " + 4096", "" ,d)}"
```

回到 first-build 進行測試

```bash
bitbake hello-image
runqemu hello-image nographic slirp
```

{{< figure src="images/result-hello-image.png" >}}

## 小結

我們已經建立了自己的 Layer、Recipe 以及 Image。 接下來我們就可以試著建立屬於我們的 Distribution 和 Machine 了。

## 參考連結

- [Building your own recipes from first principles][3]
- [How to fix : ERROR: do_package_qa: QA Issue: No GNU_HASH in the elf binary][2]

[1]: /2021-07-27-yocto-introduction/#建立-yocto-環境
[2]: https://lynxbee.com/how-to-fix-error-do_package_qa-qa-issue-no-gnu_hash-in-the-elf-binary/
[3]: https://wiki.yoctoproject.org/wiki/Building_your_own_recipes_from_first_principles
