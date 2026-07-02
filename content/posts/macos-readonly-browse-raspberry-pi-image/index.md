---
date: 2026-07-01T13:30:00+08:00
title: "在 macOS 上唯讀瀏覽 Raspberry Pi image — 用 Docker 繞過 ext4 的圍牆"
description: "手上有一顆 61GB 的 Raspberry Pi disk image,想在 Mac 上翻翻裡面的檔案,卻發現 macOS 根本掛不動 ext4。這篇記錄筆者怎麼用一支 Docker 唯讀掛載的 bash script 解決,以及過程中踩到的兩個坑。"
author: "Yuan"
draft: false
tags: ["raspberry-pi", "docker", "ext4", "macos", "bash"]
keywords: []
categories: ["embedded system"]
---

## 前言

某天收到了 Raspberry Pi 的磁碟 image 過來,檔案有 61GB = =  
筆者只是想看看裡面到底放了哪些設定檔、開機腳本、還有塞了什麼程式進去。

聽起來很單純吧?「掛起來看一下不就好了。」

結果一到 macOS 上就卡住了 —— Mac **原生掛不動 ext4**。而 Raspberry Pi 的 root filesystem 偏偏就是 ext4。

於是這一篇就誕生了!我們要做的,是寫一支 bash script,讓筆者可以像登入到 Pi 裡面一樣,用 shell 自由地逛整個檔案系統,而且**全程唯讀**,絕對不弄髒這顆收到的原始 image。

<!--more-->

這篇會從「先搞清楚 image 是什麼」開始,講到三個方案的取捨、最後選定的 Docker 做法,以及過程中踩到的兩個很有代表性的坑。

## 先搞清楚:這個 image 到底是什麼

在動手之前,先用 `file` 看清楚它的長相:

```bash
file demo_image
```

輸出大概長這樣:

```text
DOS/MBR boot sector;
 partition 1 : ID=0xc  ... startsector 8192,    1048576 sectors
 partition 2 : ID=0x83 ... startsector 1056768, 119824384 sectors
```

翻譯一下:

* **Partition 1(ID=0x0c)**:FAT32 的 boot 分割區,約 512MB。這個 macOS 可以原生掛。
* **Partition 2(ID=0x83)**:Linux ext4 的 root filesystem,約 57GB。**這個才是重點,而 macOS 掛不動。**

所以真正的難題只有一個:怎麼在 Mac 上讀到那個 ext4 分割區。

## 為什麼 macOS 直接掛不動?三個方案的取捨

macOS 的核心沒有內建 ext4 的讀取支援。筆者想到三條路:

* **方案 A — Docker 唯讀 loop mount + 互動 shell**:開一個 Linux 容器,用真正的 Linux kernel 把分割區掛起來,再進去用 bash 逛。
* **方案 B — macFUSE + fuse-ext2**:裝套件後直接把 ext4 掛到 macOS 的目錄,連 Finder 都能看。
* **方案 C — debugfs(e2fsprogs)**:完全不掛載,用工具直接讀 ext4。

{{< notice info "為什麼最後選 A" >}}
方案 B 的 FUSE 驅動對新版 ext4 特性(metadata_csum 之類)相容性時好時壞、速度也慢;方案 C 的互動介面太陽春,不像真正的 shell。方案 A 用的是**貨真價實的 Linux kernel**,任何 ext4 特性都讀得動,體驗也最接近「登入到 Pi 裡面」。而且筆者的 Docker 本來就開著,幾乎沒有額外成本。
{{< /notice >}}

## 核心做法:用 Docker 把 image 唯讀掛起來

整個流程其實很好懂,先看一張序列圖:

{{< mermaid >}}
sequenceDiagram
    participant Mac as macOS(筆者)
    participant Sh as browse-pi-image.sh
    participant Ctn as Docker 容器
    participant Img as image 檔(唯讀)
    Mac->>Sh: ./browse-pi-image.sh
    Sh->>Ctn: docker run --privileged(image 以 :ro 掛入)
    Ctn->>Img: losetup --read-only + mount -o ro
    Ctn-->>Mac: 進入 /rootfs 的互動 shell
    Note over Mac,Img: 全程唯讀,離開自動清理
{{< /mermaid >}}

在容器裡,關鍵只有兩步:先用 `losetup` 把 image 變成一個 loop 區塊裝置並偵測分割區,再把第二個分割區(rootfs)唯讀掛起來。

```bash
# 自動偵測分割區,不寫死 offset
LOOP=$(losetup -fP --read-only --show /image.img)

# 把 ext4 rootfs(partition 2)唯讀掛到 /rootfs
mount -o ro "${LOOP}p2" /rootfs

# 進去逛
cd /rootfs
exec bash -i
```

 這裡刻意用 `losetup -fP` **自動偵測**分割區,而不是把「offset = 1056768 × 512」這種魔術數字寫死 —— 換一顆 image 也能用。

## 唯讀,而且是「三層」唯讀

因為這是**收到的原始資料**,筆者最在意的一件事就是:絕對不能改到它。所以唯讀不是掛一層就算了,而是疊了三層互相保險:

* **第一層 — bind mount 加 `:ro`**:`docker run -v "$IMG:/image.img:ro"`,容器層級就不給寫。
* **第二層 — `losetup --read-only`**:loop 區塊裝置本身唯讀。
* **第三層 — `mount -o ro`**:檔案系統唯讀;萬一 journal 不乾淨,再退一步用 `-o ro,noload` 跳過 replay,避免任何寫入嘗試。

驗證也很直接,進去之後 `touch` 一下就知道:

```text
pi-image:/rootfs# touch test
touch: cannot touch 'test': Read-only file system
```

 看到 `Read-only file system` 就安心了 —— 原始 image 動不了。至於想留下的檔案,可以另外開一個 `_export/` 目錄用 rw 掛進去,`cp` 出來就好,唯一可寫的地方僅此一處。

## 第一個坑:容器裡沒有 udev,partx 建不出裝置節點

理論很美好,實際一跑就翻車。`losetup -fP` 明明成功了,`${LOOP}p2` 卻不存在。

> 等一下…… 分割區明明偵測到了,裝置節點怎麼憑空消失?

追下去才發現容器跑在一個 **LinuxKit 的輕量 VM** 裡,而這個 VM **沒有跑 udev**。`losetup -fP` 只在 kernel 裡登記了分割區,卻沒有人幫忙在 `/dev` 底下建出 `/dev/loopNpN` 這些節點。

解法是自己動手:從 `/proc/partitions` 讀出 major / minor,再用 `mknod` 把缺的節點補回來。

```bash
# udev 沒跑時,partx 建不出節點 → 從 /proc/partitions 補建
for _p in 1 2; do
  _dev="${LOOP}p${_p}"
  if [ ! -e "$_dev" ]; then
    _name="${LOOP#/dev/}p${_p}"
    _maj=$(awk -v n="$_name" '$4==n{print $1}' /proc/partitions)
    _min=$(awk -v n="$_name" '$4==n{print $2}' /proc/partitions)
    [ -n "$_maj" ] && mknod "$_dev" b "$_maj" "$_min" 2>/dev/null || true
  fi
done
```

{{< notice tip "為什麼 mknod 不會破壞唯讀" >}}
筆者一開始也擔心:自己 `mknod` 出來的節點是可寫的,會不會開了一條後門?其實不會。唯讀是由 loop 驅動在 kernel 層強制的 —— 只要 loop device 是用 `--read-only` 建的,就算你的裝置**節點**權限可寫,實際 I/O 依然是唯讀。節點只是個入口,擋讀寫的是背後的 loop 裝置。
{{< /notice >}}

## 第二個坑:loop device 會「洩漏」

以為大功告成,結果在收尾前跑最後一次測試,又炸了:

```text
losetup: /image.img: failed to set up loop device: No such file or directory
losetup: device node /dev/loop5 (7:5) is lost. You may use mknod(1) to recover it.
```

奇怪的是,前面測了好幾次都好好的,怎麼突然壞掉?進去 VM 一看 `losetup -a`,真相大白:loop0 到 loop4 **全都還附掛著**,背後指向的都是早就被刪掉的容器。

> 原來每跑一次,就漏一顆 loop device。

原因是:loop device 是**整個 VM 全域共用**的,不像檔案系統掛載那樣被容器命名空間隔離。`docker run --rm` 只會移除容器,不會幫你把 loop device 卸掉。跑幾次之後,`losetup -f` 挑到一個號碼(loop5),但那個號碼在無 udev 的 VM 裡連節點都沒有,於是就掛了。

修法是加一個 `EXIT` trap,不管是正常離開、跑完自我測試、還是中途出錯,離開前都把掛載卸掉、把 loop device `losetup -d` 掉:

```bash
LOOP=""
cleanup() {
  [ -n "$LOOP" ] || return 0
  cd / 2>/dev/null || true
  umount -R /rootfs 2>/dev/null || true
  losetup -d "$LOOP" 2>/dev/null || true
}
trap cleanup EXIT
```

這裡有個小細節:互動模式原本用的是 `exec bash`,但 `exec` 會**取代**目前的行程,trap 就永遠不會觸發。所以要把它改成一般呼叫,讓使用者離開 shell 後,控制權回到腳本、trap 才有機會清理:

```bash
# 從 exec bash ... 改成:
bash --rcfile /root/.browserc -i || true
```

{{< notice caution "共用資源的清理,別靠 --rm" >}}
這個坑很值得記起來:凡是動到 **VM/主機層級的全域資源**(loop device、network、掛載點……),都不能指望容器的 `--rm` 幫你收拾,因為那些東西根本不在容器的命名空間裡。自己建的,就自己拆。
{{< /notice >}}

驗收方式也很明確 —— 連續跑三次自我測試,而且事後 `losetup -a` 必須是空的:

```bash
for i in 1 2 3; do ./browse-pi-image.sh --selftest; done
docker run --rm --privileged debian:stable-slim losetup -a   # 應為空
```

 「跑完之後 loop device 歸零」才是這個修正真正該通過的測試,而不只是「這次能跑」。

## 完整用法

最後成品是一支 [`browse-pi-image.sh`](./browse-pi-image.sh),用起來就三種姿勢:

```bash
# 進入互動瀏覽(像登入 Pi 一樣逛)
./browse-pi-image.sh

# 非互動自我測試(驗證掛載 / 唯讀 / 匯出)
./browse-pi-image.sh --selftest

# 指定別的 image
./browse-pi-image.sh /path/to/other.img
```

進去之後 rootfs 就掛在 `/rootfs`,提示字元是 `pi-image:/rootfs#`,`ls` 一下就能看到 `bin boot etc home usr var …` 一整套熟悉的 Linux 根目錄。想把檔案帶回 Mac 就 `cp /rootfs/… /export/`。`exit` 離開後,容器自動移除、loop device 自動 detach。

## 小結

回顧一下這趟旅程:

* macOS 掛不動 ext4,但我們可以借一個 **Docker 容器的 Linux kernel** 來讀,體驗最接近真機。
* 用 `losetup -fP` **自動偵測**分割區,不寫死 offset,換 image 也能用。
* 唯讀要疊**三層**(`:ro` / `losetup --read-only` / `mount -o ro`),對「收到的原始資料」這種場景特別重要。
* Docker Desktop 的 LinuxKit VM **沒有 udev**,要自己 `mknod` 補裝置節點。
* loop device 是 **VM 全域共用**的,`--rm` 不會幫你清,得自己用 `trap` 在離開時 `losetup -d`,否則會慢慢洩漏。

其中最讓筆者有感的,是最後那個 loop 洩漏的坑 —— 它是在「收尾閘門」跑最後一次測試時才現形的。這也再次提醒我們:**測試不是為了證明它會動,而是為了逼出那些平常剛好沒踩到的狀態。**

未來如果有機會玩到需要**寫入** image、或想改用 macFUSE 直接掛進 Finder 的版本,或許會再寫一篇續集!

## 參考連結

- [Raspberry Pi — Installing over the network / image 結構說明][1]
- [losetup(8) manual page][2]
- [util-linux — partx / 分割區工具][3]
- [Docker Desktop 與 LinuxKit VM][4]
- [ext4 Data Structures and Algorithms (kernel.org)][5]
- [macFUSE][6]

[1]:https://www.raspberrypi.com/documentation/computers/os.html
[2]:https://man7.org/linux/man-pages/man8/losetup.8.html
[3]:https://man7.org/linux/man-pages/man8/partx.8.html
[4]:https://docs.docker.com/desktop/
[5]:https://www.kernel.org/doc/html/latest/filesystems/ext4/index.html
[6]:https://macfuse.github.io/
