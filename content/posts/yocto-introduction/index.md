---
date: 2021-07-27T15:19:05+08:00
title: "Yocto 基礎介紹"
author: "Yuan"
draft: false
tags: ["yocto", "linux"]
keywords: []
categories: ["embedded system"]
resources:
- src: images/yocto.png
- src: images/workflow.png
- src: images/reminder.png
---

## 前言

先前有接觸過 buildroot 這類的 Linux Distribution 工具，但一直沒有好好的整理起來。  
最近剛好有機會接觸 Yocto，打算在摸索的過程中一並記錄起來。

<!--more-->

## 主要內容

### Yocto 專案

有關於 Yocto  專案的歴史就不多做介紹了，有興趣的同學可以到它的[官網][1]看看。  
{{< figure src="images/yocto.png" caption="Yocto 官網畫面" >}}

### 基本觀念

{{< figure src="images/workflow.png" caption="Yocto 開發流程" >}}

#### Machine
相關的配置會放在 `conf/machine/` 中。它用來描述與硬體有關的配置。通常包含: Kernel、Devices Tree、Bootloader。

#### Distrobution 
相關的配置會放在 `conf/distro/` 中。它作為整個配置中最底層的部份。接下來的 Layer 都會以此為基礎往上疊加。通常它也訂定了此系統的 ABI 。

#### Image
相關的配置會放在 `recipes-*/images/` 中。它就是 rootfs。

#### Layer
是由 Recipe 所組成，根據不同用途可以定義出BSP Layer, General Layer。  
一般來說我們會以 ` meta-` 開頭作為 Layer 的命名。 

#### Recipe
是由一系列建構 Package 的指令所組成。描述了 Package 該如何取得源始碼、如何進行配置、如何進行編譯以及安裝的步驟。 

#### Package
在 Yocto 中 Package 是代表 Recipe 的執行結果。

{{< figure src="images/reminder.png" >}}


### 建立 Yocto 環境

下載 Poky。

> 等一下... 怎麼突然就冒一個 poky 出來  
> 這個就先請同學自行去 Yocto 的官網看了

```bash
mkdir yocto && cd yocto
git clone git://git.yoctoproject.org/poky.git
```

輸入下列指令初始化環境，它會幫我們建立 `first-build` 資料夾。並設置好相關的環境變數。
 
```bash
source poky/oe-init-build-env first-build
```

### 開始第一個專案

輸入下列指令，就會開始進行編譯了。

```bash
bitbake core-image-miminal
```
{{< admonition type=hnit title="補充說明" open=true >}}  
依照網路環境、編譯主機的不同，執行的時間會有所不同。但第一次都要蠻久的就是了。
{{< /admonition>}}

在編譯完成之後，使用 qemu 來看看成果。

```bash
runqemu qemuarm core-image-miminal nographic slirp
```

使用 root 登入

{{< figure src="images/qemu.png" caption="登入畫面" >}}


## 小結

本文記錄了 Yocto 開發時會需要知道的基楚資訊，未來在開發時，有發現不足的部份會再持續的補充。

## 參考連結

- [Yocto Official][1]
- [Bootlin - Introduction to Yocto project][2]

[1]:https://www.yoctoproject.org
[2]:https://bootlin.com/pub/conferences/2017/embedded-recipes/josserand-introduction-to-yocto-project/josserand-introduction-to-yocto-project.pdf
