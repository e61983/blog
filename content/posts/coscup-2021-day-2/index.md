---
date: 2021-08-01T10:12:46+08:00
title: "COSCUP 2021 Day 2"
description: ""
author: "Yuan"
draft: false
tags: ["mysql", "acl", "chatbot", "liff", "coscup"]
keywords: []
categories: ["note"]
resources:
- src: "images/window-function.png"
- src: "images/chatbot-signal-ir.png"
- src: "images/casbin.png"

---

## 前言

今年的 COSCUP 因應 COVID-19 疫情，所以以線上直播的方式進行。本篇主要是記錄大會第二天有興趣的議程以及關鍵字。

<!--more-->

## 主要內容

### 細談 MySQL Replication 強項

#### References:

- [MySQL Replication 主從式架構設定教學](https://blog.toright.com/posts/5062/mysql-replication-主從式架構設定教學.html)
- [MySQL 主從複製原理](https://jaminzhang.github.io/mysql/MySQL-Master-Slave-Replication-Principle/)

### 資料庫也可以全年無休啦! 神奇的MySQL HA架構拯救你的資料庫!

- MySQL Cluster
	- SQL Node  讀資料
	- Data Node 存資料
	- Management Node - 用來管理 NDB Cluster

- MGM:
	- config.ini
	-  ndb_mgm

- Data/ SQL Node
	-  /etc/my.conf
	-  ndbd
- SQL
	- systemd start mysqld

- Node Group
- 一般是異步
- ndb 是同步的
	- Master 會傳 Log 給 Slave ，確認後會執行動作來進行同步。  

#### References

- [MySQL Cluster學習筆記](https://www.cc.ntu.edu.tw/chinese/epaper/0037/20160620_3707.html)	

### SignalR 整合 LINE，在LIFF裡建立一對一聊天管道

{{< figure src="images/chatbot-signal-ir.png" >}}

- LIFF ( Line Front-end Framework )
-  SignalR
	- Group  

#### References:

- [SignalR](https://github.com/SignalR/SignalR)

### MySQL 8 那麼久了，還沒開始用 window function 嗎？

- 什麼是 Wndow Function
	- 保留每一列的 Query 結果，但又有聚合的操作結果。

{{< figure src="images/window-function.png" >}}

- OVER (PARTITION BY contry) 
- { OVER (window_spec) | OVER window_name }

- Query Rewrite  

### 使用 Qemu + Debian Linux 來進行嵌入式系統入門教學

{{< youtube vliriubNSCw >}}

- Den U-Boot
- Linux Kernel
- Root File System

#### References:

- [共筆](https://hackmd.io/@coscup/rymNETD0O/%2F%40coscup%2Frknz4TDRu)

### MySQL究極防禦工事(全自動化MHA機制)
- Proxy SQL
- Orchestrator
- 了解 Master - Slave 架構、同步機制

#### References:

- [Slide](https://drive.google.com/file/d/1zOv6JTVZwFHYkT69_-22Q_BUxZh1TgE6/view)
- [共筆](https://hackmd.io/1GpbuglDREakqxQzBZTS3Q)

### 初試 Casbin - 快速搭建符合 99% 產品都需要的高彈性可維護之授權控制系統

- Authen & Authorization 
	- Authen - 你是誰
	- Authorization - 你可以做什麼

#### 權限管理方式

- ACL (Accuess Control List)
- RBAC (Role-Base Access Control)
- Attribute-based access control

#### Casbin

{{< figure src="images/casbin.png" >}}

- PML
- Policy Storage

#### References:

- [casbin/casbin](https://github.com/casbin/casbin)
- [ory](https://www.ory.sh)
- [ory/oathkeeper](https://github.com/ory/oathkeeper)

### MySQL 8.0的新SQL為開發者開啟一片天

- Window Function

#### History

- 4.1 B-Tree, R-Tree, Subquery, Prepaed Statement
- 5.0 Stored Routines, Views, XTranstion
- 5.1 Event, Row-Based replicatoion, Plugin API
- 5.5 Support Unicode
- 5.6 InnoDB Buffer Pool Instance, Memmcached API, GTID 
- 5.7 JSON data type, CJK 檢索, online DDL, JSON Function
- 8.0 ...

### 帶您製作新潮、實用且開源的 LINE 電子名片與廣告傳單

- Flex Message
-  LIFF

#### References:

- [不用寫程式也能做 LINE 數位版名片
](https://taichunmin.idv.tw/blog/2020-07-21-liff-businesscard.html)
- [taichunmin/liff-businesscard](https://github.com/taichunmin/liff-businesscard)
