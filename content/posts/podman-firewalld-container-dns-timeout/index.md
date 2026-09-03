---
date: 2026-09-03T12:27:00+08:00
title: "lookup bar: i/o timeout — 追一個 podman 容器 DNS 突然異常的 bug"
description: "在 RHEL 9 上,每次跑完安裝腳本,容器內的 DNS 就會壞掉。這到底是為什麼呢..."
author: "Yuan"
draft: false
tags: ["podman", "netavark", "firewalld", "dns", "rhel", "linux"]
keywords: []
categories: ["note"]
---

## 前言

最近筆者在做一件事:把一套原本跑在 docker compose 上的服務,搬到 RHEL 9 + Podman 上,順便自己寫了一支安裝腳本。

功能都正常,唯獨有一件怪事:**每次升級安裝完,一登入系統就出現異常**。

```json
{
  "code": 400,
  "msg": "failed to set salt: dial tcp: lookup bar: i/o timeout"
}
```

白話翻譯一下這句錯誤:系統裡有個叫 API Gateway 的服務,它想找一台叫 `bar` 的機器。但它連「bar 的地址是什麼」都查不到,等了半天沒人回答,只好放棄。

更怪的是,解法簡單到不可思議——把 bar 這個容器關掉再打開,就全好了:

```bash
docker compose -f compose.yaml stop bar
docker compose -f compose.yaml up -d bar
```

> 等一下⋯⋯壞掉的是 API Gateway 查不到 bar 的地址,為什麼重開「bar」能修好「別人」的問題?

這個違和感就是整篇文章的起點。接下來筆者會把追兇的過程一步步記錄下來。

<!--more-->

本文環境:RHEL 9.8、podman 5.8.2、netavark 1.17.2、aardvark-dns 1.17.1,compose provider 是 docker compose 走 rootful podman.sock。

## 背景知識:容器是怎麼「用名字找到彼此」的

在開始查案之前,先補兩個背景知識。已經熟的同學可以直接跳到下一節。

**DNS 是什麼?**  
可以想成一本電話簿。  
網路世界裡機器真正的地址是一串數字(IP,例如 `10.0.0.2`),但人類喜歡用名字(例如 `bar`)。所以每次要用名字連線之前,都得先翻電話簿,把名字換成數字地址。這個「查電話簿」的動作就叫 **DNS 查詢**。

**容器是什麼?**  
可以想成同一台電腦裡的許多間小房間。每個服務(bar、API Gateway、...)各住一間,彼此之間用一條虛擬的網路線相連。

那麼在 Podman 的世界裡,容器要查電話簿時,是誰在接電話?

答案是一支叫 **aardvark-dns** 的小程式。  
每個容器的設定檔裡都只寫了一行:「電話簿服務在 `10.0.0.1`」——這是容器網路的出入口 (Gateway) 的地址:

```text
search dns.podman
nameserver 10.0.0.1
```

{{< mermaid >}}
sequenceDiagram
    participant App as 應用容器
    participant AD as aardvark-dns（10.0.0.1:53）
    participant UP as 上游 DNS
    App->>AD: bar 的地址是多少？
    AD-->>App: 10.0.0.2（同網路的容器名，它自己就會答）
    App->>AD: www.example.com 呢？
    AD->>UP: 不認識的名字，幫忙問外面的電話簿
    UP-->>AD: 192.168.0.1
    AD-->>App: 192.168.0.1
{{< /mermaid >}}

重點只有一句:**容器查名字,走的是「容器 → gateway 的 53 port」這條路**。記住這條路,等等它會是關鍵。

另外還有一位角色叫 **netavark**。它負責幫容器把網路接好——每次有容器啟動或停止,它都會出來跑一次設定,順便更新 aardvark-dns 手上的電話簿。

## 案發現場

回到症狀本身,把已知線索排開:

* 升級流程大致是:停掉全部服務 → 換上新版程式 → 更新資料庫 → `up -d` 全部啟動 → 最後設定防火牆
* 網頁本身開得起來 (`GET /status` 回 200) ,只有「登入」這個動作會出現 `lookup bar: i/o timeout`
* 重開一下 bar,**整個系統** 就恢復正常

第三點透露了很重要的訊息。前面說過,任何容器重開,netavark 都會重跑一次網路設定。所以「重開 bar 修好一切」極可能不是 bar 的功勞,而是 **netavark 在設定網路時,順手把某個壞掉的東西修回來了**。

換句話說:兇手應該藏在網路層,而不是 bar 本身。

## 假設一:是防火牆重載把規則洗掉了?

先解釋一下防火牆。它就像大樓的警衛,每個進出的網路封包都要被它檢查一次,不合規定的就擋下來。RHEL 上管這位警衛的軟體叫 **firewalld**。

看安裝腳本,筆者注意到一個順序問題:`up -d` 把服務都啟動之後,**最後一步**才執行 `firewall-cmd --reload`(重新載入防火牆設定)。

「firewalld 一 reload,容器網路的規則就會被沖掉」是江湖上流傳已久的坑。一切看起來都對上了:reload 洗掉規則 → DNS 封包被警衛擋下 → 查不到名字;重開容器 → netavark 重建規則 → 復活。

於是設計實驗:趁系統正常時,手動執行一次 `sudo firewall-cmd --reload`,再登入看看會不會壞。

結果——**登入完全正常**。假設一卒。

> 先破個梗:這個實驗其實騙了筆者,後面會揭曉為什麼。但當下筆者是真心以為方向錯了。

## 假設二:電話簿裡少了 bar 這一頁?

換個方向。aardvark-dns 的電話簿其實就是一個純文字檔,直接打開來看:

```bash
sudo cat /run/containers/networks/aardvark-dns/foo_default
```

在壞掉的狀態下,bar 那行**好端端地在**:

```text
10.0.0.1
51fcbe7ba365... 10.0.0.229  foo-bar-1,bar,...
ef1fba5a0c9d... 10.0.0.248  foo-API Gateway-1,API Gateway,...
（其餘省略）
```

假設二也陣亡了。不過這輪收集資料時,撈到兩條重要線索:

* 錯誤訊息是 `lookup bar: i/o timeout`,不是 `dial tcp 10.0.0.x:6379: i/o timeout`。前者是「查電話簿」這一步就失敗了;後者是「查到地址了,但打過去沒人接」。所以問題確定在 DNS 這一層,無誤。
* 升級前後,容器的 ID 完全相同——容器沒有被砍掉重建,只是重新啟動、換了一個 IP。

{{< notice tip "讀錯誤訊息的小技巧" >}}
Go 程式的網路錯誤,會把「失敗在哪一步」寫進訊息裡:`lookup <名字>` 代表查 DNS 失敗,`dial tcp <IP>:<port>` 代表連線失敗。一個字之差,查案方向完全不同。
{{< /notice >}}

## 假設三:aardvark-dns 沒收到「電話簿更新了」的通知?

檔案是對的,查詢卻失敗。那會不會是這樣:電話簿檔案更新了,但 aardvark-dns **腦中記的還是舊版**?

背景是:netavark 每次改完電話簿檔案,會發一個訊號(SIGHUP)通知 aardvark-dns:「嘿,重讀一次檔案!」萬一這個通知遺失了⋯⋯

驗證方式也很直接:不透過容器,直接從主機(host)問 aardvark-dns 一次,再手動補發一次通知。

```bash
dig @10.0.0.1 bar +time=2 +tries=1
# ;; ANSWER SECTION:
# bar.  0  IN  A  10.0.0.2      ← 秒答,而且答案是對的

sudo kill -HUP "$(pgrep aardvark-dns)"
# 手動補發通知之後,登入依然噴 lookup bar: i/o timeout
```

假設三也出局。但這一輪的收穫是整個案件的轉捩點:

**從主機問 aardvark-dns,一切正常;從容器裡問同一台 server,卻失敗。**接電話的人沒問題,問題出在「容器到 gateway」這段路上——電話線被人剪了。

## 假設四:警衛把容器的 DNS 封包擋下來了

主機問 aardvark-dns 走的是「屋內對講」,不用出門;容器問它則要走出房間、經過走廊,而走廊上站著防火牆這位警衛。兩條路的差別,就是有沒有經過警衛。

嫌疑重新回到防火牆身上。先看看 netavark 設的規則(nftables 版):

```bash
sudo nft list table inet netavark
# Error: No such file or directory
```

> 咦,規則表不存在?

原來 RHEL 9 上的 netavark,預設用的是比較舊的 **iptables** 這套機制,規則放在 `NETAVARK_*` 開頭的 chain 裡。那就把規則全部倒出來,修好前後各存一份,比對差異:

```bash
sudo iptables -S | tee /tmp/iptables-broken.txt
sudo podman network reload --all        # ← 這個指令會重建容器網路的防火牆狀態
sudo iptables -S | tee /tmp/iptables-fixed.txt
diff /tmp/iptables-broken.txt /tmp/iptables-fixed.txt
```

三個結果:

1. `podman network reload --all` **真的修好了**——完全不用碰任何容器
2. 但壞掉版和修好版的 iptables 規則**一模一樣**,連「放行 53 port」的那條都好好的
3. 壞掉時在容器內做查詢,錯誤訊息長這樣:

```bash
sudo podman exec foo-bar-1 nslookup bar 10.0.0.1
# ;; connection timed out; no servers could be reached
# nslookup: write to '10.0.0.1': Host is unreachable
```

`Host is unreachable` 是一個**很有指紋**的錯誤。如果封包只是被默默丟掉,你只會看到 timeout(等到天荒地老沒人回);但這裡是對方**明著回了一句「你不准過」**(一個 ICMP 拒絕訊息)。而 firewalld 擋人的預設方式,正是回這種「明著拒絕」。

整理一下矛盾:iptables 規則說放行,封包卻被拒絕;`network reload` 修好了問題,iptables 卻一個字都沒變。結論只有一個:**netavark 管理的防火牆狀態不只 iptables 這一份,還有另外一塊——而被弄壞的是那一塊。**

## 兇手:firewalld 的「暫存設定」與「正式設定」

答案揭曉:是 firewalld 的 **trusted zone**(信任區)。

這裡需要最後一塊背景知識。firewalld 的設定分成兩份:

* **runtime(暫存)**:現在正在生效的規則。任何程式都可以動態加東西進來,但它只存在記憶體裡。
* **permanent(正式)**:寫在設定檔裡的規則。重載或重開機後,以它為準。

關鍵行為有兩個:

第一,netavark 在容器啟動時,除了 iptables 規則之外,還會跟 firewalld 說:「`10.0.0.0/24` 這個網段(容器們住的社區)是自己人,請加進信任區」——**但它只加在暫存區,沒有寫進正式設定**。

第二,`firewall-cmd --reload` 做的事,正是「把暫存區整個丟掉,重新照正式設定來一遍」。

兩件事疊在一起,案情全貌就出來了:

{{< mermaid >}}
sequenceDiagram
    participant IN as 安裝腳本
    participant NV as netavark
    participant FW as firewalld
    participant App as 應用容器
    IN->>IN: up -d 啟動所有容器
    NV->>FW: 把 10.0.0.0/24 加進信任區（只加在暫存）
    IN->>FW: firewall-cmd --reload（最後一步）
    FW->>FW: 暫存被重置回正式設定，信任區清空
    App->>FW: DNS 查詢 → gateway:53
    FW-->>App: ICMP host-prohibited（明著拒絕）
    Note over App: lookup bar: i/o timeout
{{< /mermaid >}}

安裝腳本的最後一步 reload,每次都準時把 netavark 剛登記好的信任名單洗掉。**每次升級必壞,分毫不差。**

重新驗證一次,完整重現:

```bash
sudo firewall-cmd --zone=trusted --list-sources   # 10.0.0.0/24,正常
sudo firewall-cmd --reload
sudo firewall-cmd --zone=trusted --list-sources   # （空的!)
sudo podman exec foo-bar-1 nslookup bar 10.0.0.1
# nslookup: write to '10.0.0.1': Host is unreachable

sudo podman network reload --all
sudo firewall-cmd --zone=trusted --list-sources   # 10.0.0.0/24 回來了!
```

這也順便解開了前面兩個懸案:

* **為什麼重開 bar 能修好一切**:netavark 重跑網路設定,把信任名單重新登記回去。修好的從來不是 bar,是整個網路。
* **為什麼假設一的實驗沒壞**:當時登入時用的 bar 連線,是連線池裡**早就建好的舊連線**——電話早就撥通了,根本不需要重新查電話簿,於是「看起來」沒壞。改用 `nslookup` 直接查一次名字,就不會被連線池騙到。

{{< notice warning "小心 false negative" >}}
驗證網路假設時,盡量用「每次都會真的走一遍該路徑」的工具(如 `nslookup`、`dig`)直接測,不要透過應用程式的行為間接觀察——連線池、快取都會幫倒忙,讓你太早排除掉正確答案。
{{< /notice >}}

## 修法:三層防禦

確診之後,筆者在安裝腳本補上三層:

1. **調整順序**:把 `firewall-cmd --reload` 移到**啟動服務之前**。reload 發生在還沒有任何容器的時刻,之後 `up -d` 才去登記信任名單,自然不會被洗掉。
2. **啟用 `netavark-firewalld-reload.service`**:這是 netavark 附的官方保險,會監聽 firewalld 的 reload 事件、自動把信任名單登記回去。防的是日後管理者手動 reload 再踩一次。
3. **啟動後 DNS 自檢**:服務全部啟動後,腳本會進容器 `nslookup bar` 真的查一次名字,失敗就自動 `podman network reload --all` 補救。不管未來哪種機制再弄壞狀態,都會在使用者看到錯誤之前被修好。

## 小結

回顧這場追兇,幾個值得帶走的重點:

* **`lookup x: i/o timeout` 和 `dial tcp ip: timeout` 是兩個案子**:前者卡在「查電話簿」,後者才是「打電話沒人接」。
* **`Host is unreachable` 是被明著拒絕的指紋**:防火牆用 REJECT(回你一句不准過)才會這樣;如果只是默默丟包,你看到的會是乾等到底的 timeout。
* **Podman 容器查名字的路徑是「容器 → gateway 的 53 port → aardvark-dns」**:主機上查得到、容器內查不到,問題就在中間那段路上。
* **firewalld 的暫存(runtime)與正式(permanent)是兩個世界**:`--reload` 會把別人動態加進暫存的東西全部洗掉,netavark 登記的信任名單正是受害者。
* **「重開某個容器就好了」通常不是那個容器的問題**:真正的解藥是重開時順便重跑的網路設定。看到這種線索,值得多想一層。
* **驗證假設要走真實路徑**:連線池與快取製造的假象,差點讓筆者與正解擦身而過。

未來如果 netavark 在 EL9 預設啟用 firewalld 的 reload 監聽,這篇也許就功成身退了——在那之前,希望能幫到同樣被容器 DNS 陰過的同學!

## 參考連結

- [Podman][1]
- [netavark（GitHub）][2]
- [aardvark-dns（GitHub）][3]
- [podman network reload — man page][4]
- [firewalld — Runtime vs Permanent][5]

[1]:https://podman.io/
[2]:https://github.com/containers/netavark
[3]:https://github.com/containers/aardvark-dns
[4]:https://docs.podman.io/en/latest/markdown/podman-network-reload.1.html
[5]:https://firewalld.org/documentation/howto/
