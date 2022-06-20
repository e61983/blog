---
date: 2022-05-29T02:18:03+08:00
title: "如何設定 Unifi AP"
description: ""
author: "Yuan"
draft: false
tags: ["unifi"]
keywords: []
categories: ["mis"]
---

## 前言

最近入手了新的 Unifi AP，趁這一次設定就順手記錄起來吧。
<!--more-->

## 主要內容

### 加入 Unifi 控制器

#### 登入 Unifi AP

```
ssh -l ubnt ${UNIFI_AP_ADDRESS}	# password: ubnt
```

{{< notice info "預設 IP 位置" >}}
在 Unifi AP 沒有從 DHCP 取得 IP 之前，它的預設 IP 為 ``192.168.1.20``。

{{< /notice >}}

#### 指定要加入的 Unifi 控制器

```
set-inform http://${UNIFI_CONTROLLER_ADDRESS}:8080/inform
```

在控制器中點擊 [ Adpot ] 即可。


### 變更 Unifi 控制器

在 Unfi 官方的文件中提到，我們可以透過 Unfi Network 來將 AP 重置為出廠設定。
> All UniFi devices can be restored via their respective web or mobile applications. This is located in the “Manage” section of a device’s settings. Depending on the application, this may be referred to as “Forget”(UniFi Network) or “Unmanage” (UniFi Protect).

接著就可以登入並加入 Unifi 控制器 [[3]] 了。

### 補充 - 架設 Unfi Controller

我們可以使用 Docker 跟 docker-compose 來架設 Unfi Controller。

```docker-compose
version: "2.1"
services:
  unifi-controller:
    image: lscr.io/linuxserver/unifi-controller:version-7.1.66
    container_name: unifi-controller
    environment:
      - PUID=1000
      - PGID=1000
      - MEM_LIMIT=1024 #optional
      - MEM_STARTUP=1024 #optional
    volumes:
      - ./config:/config
    ports:
      - 8443:8443 # Unifi web Admin port
      - 3478:3478/udp # Unifi STUN port
      - 10001:10001/udp # AP discovery
      - 8080:8080 # device communication
      - 1900:1900/udp #optional
      - 8843:8843 #optional
      - 8880:8880 #optional
      - 6789:6789 #optional
      - 5514:5514/udp #optional
    restart: unless-stopped
```

## 參考連結

- [UniFi - Problems with Device Adoption][1]
- [UniFi - How to Reset Devices to Factory Defaults][2]
- [linuxserver/unifi-controller][4]

[1]:https://help.ui.com/hc/en-us/articles/360012622613-UniFi-Problems-with-Device-Adoption
[2]:https://help.ui.com/hc/en-us/articles/205143490-UniFi-How-to-Reset-Devices-to-Factory-Defaults
[3]:{{< relref "posts/how-to-setup-unifi-ap/index.md#加入-unifi-控制器" >}}
[4]:https://hub.docker.com/r/linuxserver/unifi-controller
