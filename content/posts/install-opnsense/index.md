---
date: 2021-09-09T17:06:40+08:00
title: "安裝 Opnsense 並設定 OpenVPN"
description: ""
author: "Yuan"
draft: false
tags: ["vpn","openvpn","pfsense","opnsense"]
keywords: []
categories: ["mis"]
---

## 前言

目前有了在外面存取 NAS 資料的需求，直接裸奔實在不是個明智的想法。還是放在防火牆後面，架個 VPN 服務好了。
想說既然要架 VPN 伺服器。趁這次機會也一併換套防火牆軟體試試。
<!--more-->

## 主要內容

### 下載映像檔

選擇好想使用的映像檔後就可以直接下載下來，準備製作安裝隨身碟。

{{< figure src="images/download-page.png" caption="下載頁面" >}}

```bash
# Image Type: vga
# Mirror: Nantou County Education Network center

wget https://mirror.ntct.edu.tw/opnsense/releases/21.7/OPNsense-21.7.1-OpenSSL-vga-amd64.img.bz2
```

### 製作安裝隨身碟

在這裡我們使用 `dd` 來製作安裝隨身碟。如果是使用 Windows 系統的同學則嘗試使用 [Rufs](https://rufus.ie/en/) 來製作。

```bash
bzcat OPNsense-21.7.1-OpenSSL-vga-amd64.img.bz2|sudo dd of=/dev/${DISK} bs=10m
```

### 安裝 Opnsense (參考影片)

使用我們剛製作完成的 Opnsense 安裝隨身碟開機後使用 installer/opnsense 帳戶登入，便可以開使進行安裝。
下列整理了安裝的步驟

1. 安裝 Opnsense 系統
2. 配置 WAN
3. 配置 LAN
4. 配置我們所需要的防火牆規則

{{< youtube doFZiJrBnek >}}

### 設定 OpenVPN (參考影片)

下列整理了要架設 OpenVPN 的步驟
1. 建立 Root CA
2. 建立 VPN 伺服器所要使用的憑證 ( Server-Cert )
3. 建立本機用戶所要使用的憑證 ( User-Cert )
4. 建立 OpenVPN Server，並添加防火牆規則
5. 匯出 OpenVPN 使用者端的設定檔
6. 最後，在終端設備安裝 OpenVPN 使用者程式並匯入設定檔(*.ovpn)。

{{< youtube ocGAcZD8qYo >}}

## 小結

原本筆者是使用 pfSense 這套防火牆，所以在配置上其實 Opnsense 與 pfSense 差異沒有很大。
不過外觀確實變得比較漂亮了🤣。


## 參考連結

- [官方網站][1]
- [官方文件][2]

[1]:https://opnsense.org
[2]:https://docs.opnsense.org/setup.html
