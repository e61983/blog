---
date: 2022-08-02T01:59:04+08:00
title: "在 Synology NAS 開啟 iperf 伺服器"
description: ""
author: "Yuan"
draft: false
tags: ["synology","nas","iperf"]
keywords: []
categories: ["note","mis"]
---

## 前言

最近發現家中的 NAS 速度 "好像" 沒有達到筆者的預期。所以想來實際測看看可以目前的網路環境可以跑到什麼程度。於似乎這一篇就誕生了。
<!--more-->

## 主要內容

測試的 NAS 型號為: DS214。

### 在 Synology NAS 運行 iperf 服務

- 安裝 iperf3

```bash
ssh synology-nas
sudo -i
synogear install
synogear list # 檢視 iperf
```
- 執行

```bash
iperf3 -s
```
- 輸出

```txt
(synogear) root@synology-nas:~# iperf3 -s
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
```

### 在目標機器上執行 iperf 用戶端程式

由於筆者要測的機器是 Macbook ，所以下面就是以它為主！

- 安裝

```bash
brew install iperf3
```

- 執行

```bash
iperf3 -c synology-nas
```

- 輸出
	
```txt
 iperf3  -c synology-nas                                                    1 ↵
Connecting to host synology-nas, port 5201
[  7] local 192.168.0.100 port 59650 connected to 192.168.0.101 port 5201
[ ID] Interval           Transfer     Bitrate
[  7]   0.00-1.00   sec  19.9 MBytes   167 Mbits/sec
[  7]   1.00-2.00   sec  29.1 MBytes   244 Mbits/sec
[  7]   2.00-3.00   sec  29.1 MBytes   244 Mbits/sec
[  7]   3.00-4.00   sec  28.3 MBytes   238 Mbits/sec
[  7]   4.00-5.00   sec  19.9 MBytes   167 Mbits/sec
[  7]   5.00-6.00   sec  22.0 MBytes   184 Mbits/sec
[  7]   6.00-7.00   sec  22.6 MBytes   189 Mbits/sec
[  7]   7.00-8.00   sec  20.0 MBytes   168 Mbits/sec
[  7]   8.00-9.00   sec  20.3 MBytes   171 Mbits/sec
[  7]   9.00-10.00  sec  20.8 MBytes   174 Mbits/sec
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate
[  7]   0.00-10.00  sec   232 MBytes   195 Mbits/sec                  sender
[  7]   0.00-10.00  sec   232 MBytes   195 Mbits/sec                  receiver
	
iperf Done.
```
	
## 小結

好的。果然沒有達到預期的速度。

つづく

## 參考連結

- [Synology synogear 工具箱][1]


[1]:https://www.mobile01.com/topicdetail.php?f=494&t=5951357
