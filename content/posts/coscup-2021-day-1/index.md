---
date: 2021-07-31T10:10:29+08:00
title: "COSCUP 2021 Day 1"
description: ""
author: "Yuan"
draft: false
tags: ["gcc", "go","linux","coscup"]
keywords: []
categories: ["note"]
resources:
- src: images/coscup.png
- src: images/pepper.png
- src: images/linux-cip.png
- src: images/kernel-source-comparison-table.png
- src: images/suitable-change-in-log-term-stable-kernel.png
- src: images/raspbootcom.png
---

## 前言

今年的 COSCUP 因應 COVID-19 疫情，所以以線上直播的方式進行。本篇主要是記錄大會第一天有興趣的議程以及關鍵字。

<!--more-->

{{< figure src="images/coscup.png" caption="COSCUP2021" >}}

## 主要內容

### Introduction to Transactional Memory and Its Implementation

GCC Example:

```c
#include <stdio.h>
int main() {
    int i = 0;
    __transaction_atomic {
        i++;
    }
    return 0;
}
```

在編譯的時候要加上 `-fgnu-tm`

```bash
gcc -fgnu-tm
```

#### Reference

- [reborn2266/STM-Toy](https://github.com/reborn2266/STM-Toy)

### Learning go error handling design from open source

> “Values can be programmed, and since errors are values, errors can be programmed.” --Rob Pike

#### References:
- [Don’t just check errors, handle them gracefully](https://dave.cheney.net/2016/04/27/dont-just-check-errors-handle-them-gracefully)
- [Errors are values](https://blog.golang.org/errors-are-values)

### A trip about how I contribute to LLVM - Douglas Chen


### 從 Go 的 runtime 源碼發掘瘋狂的 slice 用法

#### References
- [Slide](https://hackmd.io/@fieliapm/BkdNrol6O#/)


### Select, Manage, and Backport the Long-Term Stable Kernels

{{< figure src="images/linux-cip.png" caption="Linux CIP" >}}
{{< figure src="images/kernel-source-comparison-table.png" >}}
{{< figure src="images/suitable-change-in-log-term-stable-kernel.png" >}}

#### References:
- [共筆](https://hackmd.io/YcRP0uMpQ-iHDKEWoiRDYg)
- [Automotive Linux](https://www.automotivelinux.org)

### Cuju - 虛擬機容錯功能實作

#### References
- [Cuju](https://github.com/Cuju-ft/Cuju/wiki/Cuju-System-Architecture)

### User authentication in Go Web Server

- Rainbow table attack

#### 讓密碼安全性更高的方式
- salt (建議32bit)
- pepper (secret salt)

{{< figure src="images/pepper.png" caption="加鹽的方式" >}}

- password length: 10 ~ 64

#### OTP (Once Time Password)
- Time OTP
- SMS OTP

#### Resources:
- [--have i been pwned?](https://haveibeenpwned.com)

### Let's Publish a Collaborative e-Book for Linux Kernel

#### References:
- [共筆](https://hackmd.io/LXD339QGRbaEBvESooItTg)
- [The Linux Kernel Module Programming Guide](https://github.com/sysprog21/lkmpg)
- [Original Guide](https://tldp.org/LDP/lkmpg/)

### 藉由實作多任務核心來體驗作業系統概念

Raspbootcom:
{{< figure src="images/raspbootcom.png" caption="raspbootcom" >}}

- Enable UART0 FIFO

#### References:
- [Slide](https://docs.google.com/presentation/d/1G42L1TyIIkEqneCwTtenITAL8Sk4H00y7m9nt0JNVpg/edit#slide=id.p)
- [DavidSpickett/ARMMultiTasking](https://github.com/DavidSpickett/ARMMultiTasking)
- [Raspbootcom](https://github.com/mrvn/raspbootin)

## 參考連結

- [TransactionalMemory][TransactionalMemory]

[TransactionalMemory]:https://gcc.gnu.org/wiki/TransactionalMemory
[Orion]: https://github.com/carousell/Orion
[GNS3]: https://www.gns3.com
[Rpi-JTAG](https://pinout.xyz/pinout/jtag)