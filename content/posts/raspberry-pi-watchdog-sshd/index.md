---
date: 2026-08-26T12:53:34+08:00
title: "讓 Raspberry Pi 學會自救:用 Watchdog 監看 sshd"
description: "在 Raspberry Pi OS Bookworm 上啟用硬體 watchdog,並用 watchdog daemon 監看 sshd:掛掉先嘗試重啟,救不回來才重開機。"
author: "Yuan"
draft: false
tags: ["raspberry-pi", "linux", "watchdog", "ssh"]
keywords: []
categories: ["note"]
---

## 前言

筆者家裡有一台 Raspberry Pi,插在電視櫃後面的插座上,沒接螢幕也沒接鍵盤,全靠 SSH 遠端進去做事。

平常它安安靜靜的,直到某天心血來潮想連上去看看,`ssh` 卻只回給我一片沉默。

於是只好蹲下去、把櫃子拉開、把電源拔掉再插回去——如果那天人不在家,那就更尷尬了。

sshd 一旦掛掉,我們就等於失去了唯一的一道門。所以這篇文章就來做一件事:**讓 Raspberry Pi 學會自救**。用 Watchdog(看門狗)盯著 sshd,發現它不見了先試著把它叫醒;真的叫不醒,就乾脆整台重開,回到乾淨狀態。

<!--more-->

本文會從觀念、安裝、設定一路走到實際驗證,最後附上兩個筆者踩過的坑。

> 本文環境:**Raspberry Pi OS(Bookworm)**、**watchdog 套件 5.16**,不限定機型。
> 內容以官方 man page 與套件原始碼交叉查證,若你的系統版本較舊,部分路徑與行為可能會不同。

## 主要內容

### Watchdog 到底是誰在看誰

動手之前,先把名詞釐清。我們口中的「watchdog」其實是**兩個不同層次的東西**:

* **硬體 watchdog（Hardware Watchdog)**:Raspberry Pi 的 SoC 裡內建一個倒數計時器(`bcm2835_wdt`)。一旦啟動,就必須有人定期「餵狗」——也就是寫入 `/dev/watchdog`;超過時限沒人餵,硬體就強制 reset。就算整個 Linux 已經 hang 到動不了,它照樣會動作。
* **watchdog daemon(使用者空間的服務)**:負責定期餵狗,順便做各種健康檢查。本文的主角就是它的 `pidfile` 檢查,用來監看 sshd。

再把 systemd 本來就會做的事算進來,整套自救機制其實是**三層防線**:

1. **第一層 — systemd**:Debian 的 `ssh.service` 內建 `Restart=on-failure`,sshd 異常退出時,systemd 幾秒內就把它拉起來。
2. **第二層 — watchdog daemon**:如果 sshd 掛到連 systemd 都救不動(例如重啟次數已達上限),watchdog 會發現 pid 消失,改執行我們寫的修復腳本;修不好,就重開機。
3. **第三層 — 硬體 watchdog**:如果整台機器 hang 死,連 watchdog daemon 都沒辦法餵狗,硬體計時器逾時,強制 reset。

{{< mermaid >}}
flowchart TD
    A[watchdog daemon<br>每隔 interval 秒檢查] --> B{sshd 還活著?}
    B -- 是 --> C[餵狗:寫入 /dev/watchdog]
    C --> A
    B -- 否 --> D[執行 repair script<br>systemctl restart ssh]
    D --> E{修好了?}
    E -- 是 --> A
    E -- 否 --> F[重開機]
    G[整台機器 hang 住] -.-> H[沒人餵狗]
    H -.-> I[硬體 watchdog<br>逾時強制 reset]
{{< /mermaid >}}

三層各管一段:**systemd 管秒級的行程重啟,watchdog daemon 管服務層的修復與重開機,硬體 watchdog 管整台機器的死當**。

### 第一步:確認硬體 watchdog 存在

先看看裝置檔在不在:

```bash
ls -l /dev/watchdog*
```

正常會看到 `/dev/watchdog` 跟 `/dev/watchdog0` 兩個檔案。它們其實指向同一顆硬體 watchdog,而且**同一時間只能被一個程式持有**——這點等一下會變成一個坑,先記著。

{{< notice info "舊教學的 dtparam=watchdog=on 已經不需要了" >}}
網路上不少 Buster 時代的文章會要你在 `config.txt` 加上 `dtparam=watchdog=on` 再重開機。在 Bookworm 上,kernel 預設就會載入 `bcm2835_wdt`,`/dev/watchdog` 開機即存在,這一步可以直接省略。順帶一提,Bookworm 的 `config.txt` 也搬家到 `/boot/firmware/config.txt` 了。
{{< /notice >}}

要注意的是,**裝置存在不代表計時器已經在跑**。它現在只是待命,要等到有程式打開 `/dev/watchdog` 才會開始倒數。接下來就讓 watchdog daemon 來當這個持有者。

### 第二步:安裝 watchdog daemon

```bash
sudo apt install watchdog
```

Debian 的慣例是裝完就自動 enable 並啟動。不過先別緊張——預設的 `/etc/watchdog.conf` 幾乎每一項檢查都是註解掉的,現在還不會發生任何事。

這個套件其實裝了**兩個**服務:

* **`watchdog.service`**:主角。做檢查、餵狗。
* **`wd_keepalive.service`**:備援。只餵狗、不做檢查。兩者互斥(`Conflicts=`),當主角異常退出時由它接手餵狗,免得機器莫名其妙被硬體重開。這部分套件都幫我們設好了,不用動。

{{< notice warning "/dev/watchdog 只能有一個持有者" >}}
如果你曾經照其他教學在 `/etc/systemd/system.conf` 設過 `RuntimeWatchdogSec`,請先把它註解掉。systemd 跟 watchdog daemon 會互搶 `/dev/watchdog`,後開的那個會拿到 `EBUSY` 直接失敗。一台機器,一種餵狗方式就好。
{{< /notice >}}

### 第三步:設定 watchdog.conf

編輯 `/etc/watchdog.conf`,加入(或取消註解)以下設定:

```ini
# 硬體 watchdog 裝置與逾時秒數(bcm2835 的硬體上限是 15 秒)
watchdog-device  = /dev/watchdog
watchdog-timeout = 15

# 每隔幾秒做一次檢查,必須遠小於 watchdog-timeout
interval = 4

# 監看 sshd:pid file 打不開、或裡面的 process 不存在,都算故障
pidfile = /run/sshd.pid

# 故障時先執行修復腳本,修不好才重開機
repair-binary  = /usr/local/sbin/repair-sshd.sh
repair-timeout = 10

# 同一個故障最多嘗試修復幾次,超過就直接重開機
repair-maximum = 3

# 把 daemon 鎖進記憶體,避免系統高負載時自己被 swap 出去
realtime = yes
priority = 1
```

有幾個值得單獨拿出來說:

* **`pidfile = /run/sshd.pid`**:watchdog 會讀出檔案裡的 pid,再用 `kill(pid, 0)` 確認這個 process 還在。Bookworm 的 `ssh.service` 雖然是以 `sshd -D` 前景執行,但 sshd 依然會寫出這個 pid file(只有 debug 模式的 `-d` 才不寫),所以放心監看。
* **`watchdog-timeout = 15`**:Raspberry Pi 的 `bcm2835_wdt` 硬體上限就是 **15 秒**。舊 kernel 上設更大的值會得到 `cannot set timeout 60 (errno = 22)` 之類的錯誤;新 kernel(6.1 之後)雖然肯收下更大的值,但硬體真正的 reset 上限仍在 15 秒左右。老實設 15,最不會出意外。
* **`repair-timeout = 10`**:修復腳本執行的期間,daemon 是**不會餵狗**的。所以這個值務必小於 `watchdog-timeout`,否則腳本跑到一半,硬體 watchdog 就先把機器重開了。

### 第四步:撰寫修復腳本

再來是「先救救看」的主角。watchdog 呼叫 repair binary 時會帶兩個參數:`$1` 是錯誤碼,`$2` 是觸發故障的監看對象(以我們的設定來說就是 `/run/sshd.pid`)。

規則很單純:腳本**回傳 0 代表修好了**,watchdog 會繼續監看;**回傳非 0,watchdog 就重開機**。

建立 `/usr/local/sbin/repair-sshd.sh`:

```bash
#!/bin/bash
# $1: 錯誤碼(errno)
# $2: 觸發故障的監看對象

# 1) 只處理 sshd 的故障
if [ "$2" = "/run/sshd.pid" ]; then
    # 2) 嘗試重啟 sshd,成功就回報「修好了」
    if /usr/bin/systemctl restart ssh; then
        exit 0
    fi
fi

# 3) 修不好、或不認識的故障:交給 watchdog 重開機
exit 1
```

別忘了加上執行權限:

```bash
sudo chmod +x /usr/local/sbin/repair-sshd.sh
```

這個設計的精神是:**能在服務層解決,就不要動整台機器;真的救不回來,重開機才是最後手段**——這也正是 `repair-maximum = 3` 的用意,同一個毛病修了三次都沒用,就別再掙扎了。

### 第五步:啟動與驗證

設定完成,重啟服務讓它生效:

```bash
sudo systemctl restart watchdog
systemctl status watchdog
```

看到 `active (running)`、而且沒有跳出裝置相關的錯誤訊息,就代表 watchdog 已經拿到 `/dev/watchdog`,開始餵狗了。

接著來驗證監看有沒有真的生效。開兩個 SSH 視窗,第一個先掛著看 log:

```bash
journalctl -u watchdog -f
```

第二個視窗直接把 sshd 停掉,模擬它掛了:

```bash
sudo systemctl stop ssh
```

> 等一下… 把 sshd 停掉,不就連不上了嗎?

別擔心,**已經建立的連線不會斷**,只是新的連線進不來而已。

幾秒之內(最多一個 `interval`),log 視窗就會看到 watchdog 抱怨 pid 檢查失敗、接著呼叫修復腳本。然後回頭看一眼:

```bash
systemctl status ssh
```

sshd 又活過來了! ✅

{{< notice tip "要維護 sshd,記得先讓狗休息" >}}
從此之後,手動 `systemctl stop ssh` 都會在幾秒內被 watchdog 救回來。哪天真的要停用 sshd 做維護,記得先 `sudo systemctl stop watchdog`,做完再啟動回來,不然你會跟一隻盡忠職守的狗打起來。
{{< /notice >}}

{{< notice caution "測試前先確認修復腳本正常" >}}
如果 `repair-binary` 指到的腳本不存在、沒有執行權限、或執行失敗,watchdog 的下一步就是**直接重開機**。在有重要工作正在跑的機器上操作之前,請務必先確認腳本的路徑與權限無誤。
{{< /notice >}}

## 小結

* Raspberry Pi 的自救機制有三層:**systemd 的 `Restart=on-failure`**、**watchdog daemon 的檢查與修復**、**硬體 watchdog 的強制 reset**,各管一段。
* Bookworm 上 `/dev/watchdog` 開機即存在,舊教學的 `dtparam=watchdog=on` 不用再設。
* 用 `pidfile = /run/sshd.pid` 監看 sshd,搭配 `repair-binary` 先試 `systemctl restart ssh`,修不好才重開機。
* 兩個最容易踩的坑:`watchdog-timeout` 的硬體上限是 **15 秒**;`repair-timeout` 一定要小於它,不然修到一半就被硬體重開。

這套機制上線之後,筆者總算不用再擔心哪天 SSH 不上 Pi、還得跑一趟電視櫃後面了。

除了 `pidfile`,watchdog 還能監看網路連通性(`ping`)、系統負載、檔案更新時間等等,有興趣的同學可以翻翻 `watchdog.conf(5)` 的 man page。未來如果有新的玩法,或許會繼續更新!

## 參考連結

- [Keeping your Raspberry Pi online with watchdogs — dri.es][1]
- [Enabling Watchdog on Raspberry Pi — Medium][2]
- [watchdog(8) — Debian Manpages][3]
- [watchdog.conf(5) — Debian Manpages][4]
- [watchdog on 64 bit bookworm — Raspberry Pi Forums][5]

[1]:https://dri.es/keeping-your-raspberry-pi-online-with-watchdogs
[2]:https://medium.com/@arslion/enabling-watchdog-on-raspberry-pi-b7e574dcba6b
[3]:https://manpages.debian.org/bookworm/watchdog/watchdog.8.en.html
[4]:https://manpages.debian.org/bookworm/watchdog/watchdog.conf.5.en.html
[5]:https://forums.raspberrypi.com/viewtopic.php?t=362755
