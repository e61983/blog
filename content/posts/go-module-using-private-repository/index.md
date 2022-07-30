---
date: 2022-07-30T14:51:00+08:00
title: "Go 語言使用私有 Git Repository"
description: ""
author: "Yuan"
draft: false
tags: ["go","git","ssh"]
keywords: []
categories: ["note"]
---

## 前言

最近終於有時間整裡筆者家中的 NAS 。先前筆者已經架設好了 Gitea，但一直沒有時間把整個開發環境串起來。這篇文章記錄了如何在 go 中使用自架的 Git Repository。
<!--more-->

## 主要內容

由於筆者所架設的 Gitea 並不是使用 http/https 埠作為網站所使用的埠。所以當執行 `go get` 時會無法正常的動作。

所以本文主要想解決的問題有:

1. 讓 go 可以使用私有的 Git repository
2. 讓 go 可以從非標準的 http/https 埠下載程式碼。

### go get 的運作原理

從 [[1]] 我們可以知道，`go get`  在下載程式碼時有三種匹配方式，來決定要使用什麼工具來抓取程式碼。

1. prefix matching
	
	直接比對網址使用定好的協定。
2. regular expression matching
	
	比對網址結尾是否為已知的版控協定。
3. dynamic matching

	會送出 http/https 請求，並在返回的 http 中的 meta 標簽選定要用的協定。

除此之外

`go get` 它預設會使用 `GOPROXY` 來加快下載的速度。
我們可以透過設定 `GOPRIVATE` 來避免 go 使用 proxy 進行程式碼下載。

```bash
go env -w GOPRIVATE="foo.example.idv/*"
```

#### 策略

在已經知道 `go get` 下載程式碼的方式後，筆者決定從 regular expression matching 下手。 
讓模組名稱以 `.git` 作為結尾。

### git 使用 insteadOf 改寫 url

我們可以對 git 進行設定，使其改寫我們指定的 url。

```bash
git config --global url."http://foo.example.idv:8080".insteadof "http://foo.example.idv"
```

或是

```bash
git config --global url."git@foo.example.idv:".insteadof "http://foo.example.idv"
```

#### 策略

go get 底層也是使用 git 進行來對使用 git 進行版控的程式碼進行懆作。
所以我們就可以對它動點手腳，使它可以抓取非 http/https 埠的程式。

### 指定 ssh 所使用的 key

其實到了上一步我們就已經可以從我們的git repository 抓取程式碼了。
但筆者比較習慣使用 ssh 的協定，所以才會有這一個章節。

git 使用 ssh 協定抓取程式碼，走的是 ssh 協定 (( 廢話 ~~
所以我們可以使用 ssh config 來進行設定。

~/.ssh/config:

```txt
Host foo.example.idv
    Hostname foo.example.idv
    Port 22
    User git
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_rsa.pub
``` 

### 滲在一起做撒尿牛丸

```bash
go env -w GOPRIVATE="foo.example.idv/*"
```

~/.gitconfig

```txt
[url "ssh://foo.example.idv:"]
    insteadOf = https://foo.example.idv
```

~/.ssh/config

```txt
Host foo.example.idv
    Hostname foo.example.idv #192.168.1.100
    Port 2234
    User git
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_rsa.pub
```

開始新專案時

```bash
go mod init foo.example.idv/foo.git
```

## 小結

雖然在專案中都要以 `.git` 作為結尾，但除了這點目前還沒有遇到其它不方便的地方。

如果未來有找到更好的方法，也會跟大家說的！ 

## 參考連結

- [私有化仓库的 GO 模块使用实践][1]
- [Go Module：私有不合规库怎么解决引用问题][2]
- [Go Modules 處理私有 GIT Repository 流程][3]

[1]:https://studygolang.com/articles/35235
[2]:https://developer.51cto.com/article/682237.html
[3]:https://blog.wu-boy.com/2020/03/read-private-module-in-golang/
