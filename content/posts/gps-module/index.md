---
date: 2021-08-20T13:54:03+08:00
title: "NEO M8N GPS模組"
description: ""
author: "Yuan"
draft: false
tags: ["gps"]
keywords: []
categories: ["gis"]
libraries:
- katex
---

## 前言

因為工作上的需求，最近接觸到了 GNSS 模組。

維基百科是這樣說的。
> 衛星導航系統（Global Navigation Satellite System, GNSS）是覆蓋全球的自主地利空間定位的衛星系統，允許小巧的電子接收器確定它的所在位置（經度、緯度和高度），並且經由衛星廣播沿著視線方向傳送的時間信號精確到10米的範圍內。接收機計算的精確時間以及位置，可以作為科學實驗的參考。

<!--more-->

## 主要內容

### NEO M8N GPS模組

{{< figure src="images/gps-module.jpg" caption="https://www.ruten.com.tw/item/show?21550304728186" >}}

{{< figure src="images/preformance.png" caption="NEO-M8 Datasheet Page 6" >}}

### NMEA-0183

#### GGA
表示該語句為 GlobalPositioning System Fix Data(GGA) GPS定位信息
	
|  <1>  | <2> | <3>  | <4> | <5>  |   <6>   |    <7>    |    <8>     |  <9>  |      <10>       |  <11>   |  <12>  |
|-------|-----|------|-----|------|---------|-----------|------------|-------|-----------------|---------|--------|
| UTC時間 | 緯度  | 緯度方向 | 經度  | 經度方向 | GPS狀態指示 | 正在使用的衛星數量 | HDOP水平精度因子 | 海平面高度 | 地球橢球面相對大地水準面的高度 | 差分GPS信息 | 差分站ID號 |

#### GLL
表示該語句為 Geographic Position(GLL) 地理定位信息

| <1> | <2>  | <3> | <4>  |  <5>  | <6>  | <7> |
|-----|------|-----|------|-------|------|-----|
| 緯度  | 緯度方向 | 經度  | 經度方向 | UTC時間 | 定位狀態 | 校驗值 |

#### GSA
表示該語句為 GPSDOP and Active Satellites(GSA) 當前衛星信息
		
| <1>  | <2>  | <3>  |     <4>      |    <5>     |    <6>     |
|------|------|------|--------------|------------|------------|
| 定位模式 | 當前狀態 | PRN號 | PDOP綜合位置精度因子 | HDOP水平精度因子 | VDOP垂直精度因子 |

#### GSV
表示該語句為 GPSSatellites in View(GSV) 可見衛星信息
	
|    <1>    |    <2>    |   <3>    |    <4>    | <5>  | <6>  | <7> |
|-----------|-----------|----------|-----------|------|------|-----|
| GSV語句的總數目 | 當前GSV語句數目 | 顯示衛星的總數目 | 衛星的PRN號星號 | 衛星仰角 | 衛星鏇角 | 信噪比 |
	
#### MSS
表示該語句為 GPSSatellites in View(GSV) 可見衛星信息

#### RMC
表示該語句為 RecommendedMinimum Specific GPS/TRANSIT Data(RMC) 推薦最小定位信息

|   <1>    | <2> | <3> | <4>  | <5> | <6>  | <7>  | <8> |   <9>   | <10> | <11>  |
|----------|-----|-----|------|-----|------|------|-----|---------|------|-------|
| 定位時UTC時間 | 狀態  | 緯度  | 緯度方向 | 經度  | 經度方向 | 速率,節 | 方位角 | 當前UTC日期 | 磁偏角  | 磁偏角方向 |

#### VTG
表示該語句為TrackMade Good and Ground Speed(VTG) 地面速度信息

| <1>  | <2>  |   <3>    |   <4>   |
|------|------|----------|---------|
| 真實方向 | 相對方向 | 步長 Knots | 速率 km/h |

### GNGGA，GPGGA，BDGGA 傻傻分不清楚
即“混合定位”（多衛星系統）、“GPS定位”、“北斗定位”

- BD,BDS: 北斗二代衛星系統
- GP: GPS
- GL: GLONASS
- GA: Galileo
- GN: GNSS, 全球導航衛星系統

### GPS模組輸出

#### 連接方式

{{< figure src="images/connection.png" caption="使用 micro USB 線進行連接" >}}

#### 指令

筆者是在 MacOS 的環境中進行測試的，只要打開終端機開啟正確的裝置即可。

```bash
screen -L /dev/tty.XXXX 9600
```

#### 硬體識別
在開始接收之後，一開始會顯示該模組的相關資訊:
- U-Blox 的歡迎訊息
- 硬體版本
- 在 FLASH 的韌體版本
- 在 ROM 的韌體版本
- 型號
- 通訊協定版本
- GNSS 的配置
- 目前天線的配置
- 目前天線狀態
- FLASH 資訊結構進入點
- U-Blox 接收器配置

```txt
$GNTXT,01,01,02,u-blox AG - www.u-blox.com*4E                         // U-Blox 的歡迎訊息
$GNTXT,01,01,02,HW UBX-M80xx 00080000 *43                             // 硬體版本
$GNTXT,01,01,02,EXT CORE 2.01 (75350) Oct 29 2013 16:15:41*5C         // 在 FLASH 的韌體版本
$GNTXT,01,01,02,ROM BASE 2.01 (75331) Oct 29 2013 13:28:17*44         // 在 ROM 的韌體版本
$GNTXT,01,01,02,MOD NEO-M8N-0*7A                                      // 型號
$GNTXT,01,01,02,PROTVER 15.00*01                                      // 通訊協定版本
$GNTXT,01,01,02,GNSS OTP:  GPS GLO, SEL:  GPS GLO*67                  // GNSS配置
$GNTXT,01,01,02,ANTSUPERV=AC SD PDoS SR*3E                            // 目前天線的配置
$GNTXT,01,01,02,ANTSTATUS=OK*25                                       // 目前天線狀態
$GNTXT,01,01,02,FIS 0xEF4015 (79189) found*2D                         // FLASH 資訊結構進入點
$GNTXT,01,01,02,LLC FFFFFFFF-FFFFFFED-FFFFFFFF-FFFFFFFF-FFFFFF69*3E   // U-Blox 接收器配置
```

#### 定位資料

```txt
$GNRMC,054539.00,A,2524.04132,N,12130.71568,E,0.059,,200821,,,A*67
$GNVTG,,T,,M,0.059,N,0.109,K,A*39
$GNGGA,054539.00,2524.04132,N,12130.71568,E,1,09,1.82,35.1,M,17.8,M,,*75
$GNGSA,A,3,05,20,29,30,02,13,,,,,,,2.93,1.82,2.29*19
$GNGSA,A,3,87,72,71,,,,,,,,,,2.93,1.82,2.29*1A
$GPGSV,4,1,13,02,63,084,43,05,49,332,43,06,26,113,,07,05,051,43*7F
$GPGSV,4,2,13,11,52,086,,12,06,223,,13,76,177,21,15,46,226,16*74
$GPGSV,4,3,13,20,45,025,43,24,00,195,,25,02,252,,29,33,309,44*75
$GPGSV,4,4,13,30,21,081,42*44
$GLGSV,2,1,06,65,27,246,,71,36,015,34,72,58,301,28,85,30,146,*6B
$GLGSV,2,2,06,86,79,105,,87,28,336,35*62
$GNGLL,2524.04132,N,12130.71568,E,054539.00,A,A*7B
```

#### 座標轉換

由於模組的輸出是 $ddmm.mmmmm$ 格式，所以我們要再自行轉換為 $dd.dddddd$

轉換方式: $ dd + \dfrac {mm.mmmmm}{60} $

例:

假設我們收到的資料為 : 2524.04132N, 12130.71568E

轉換的方式則為 $25 + \dfrac {24.04132}{60} $, $121 + \dfrac {30.71568}{60}$

$ => 25.4006886667, 121.511928$

## 小結

本文僅先了解 GPS 模組基本輸出，尚未進行進一步的測試與研究。
此外[GPS模組輸出/定位資料]({{< relref "gps-module#定位資料" >}})章節的定位座標並非實際資料。

## 參考連結

- [NEO M8N GPS模組][1]
- [官方網站][2]
- [NEO M8N 資料手冊][datasheet]
- [這應該是關於GPS定位寫得最詳實清晰的文章之一][3]

[1]:https://www.ruten.com.tw/item/show?21550304728186
[2]:https://www.u-blox.com/en/product/neo-m8-series
[datasheet]:https://www.u-blox.com/en/ubx-viewer/view/u-blox8-M8_ReceiverDescrProtSpec_UBX-13003221?url=https%3A%2F%2Fwww.u-blox.com%2Fsites%2Fdefault%2Ffiles%2Fproducts%2Fdocuments%2Fu-blox8-M8_ReceiverDescrProtSpec_UBX-13003221.pdf
[3]:https://www.gushiciku.cn/dc_tw/108015572