---
date: 2022-08-06T02:01:43+08:00
title: "Certificated Ethical Hacker (CEH) 考試小記"
description: ""
author: "Yuan"
draft: false
tags: ["ceh","hacker"]
keywords: []
categories: ["hacker"]
---

## 前言

前一陣子每天下班後花 2 個小時讀書，終於通過了周三的考試。本文主要會簡述它是什麼以及要如何準備它！

<!--more-->

## 主要內容

筆者報名的是[恆逸][2]連續 5 天，每天 8 小時遠距教學。  
一開始很天真的想在上完課後直接報名隔週的考試，看看能不能在 10 天內取得它。 (( 年輕人終究是年輕人 ~ 

### Certificated Ethical Hacker (CEH)

Certificated Ethical Hacker ( 道德駭客認證 )，主要是在於教導、介紹一些駭客常用的工具和方法。所謂知己知彼 百戰不殆，藉由瞭解攻擊方式以及原理進而進行系統防護。

### 課程範圍

1. Introduction to Ethical Hacking (介紹何謂道德入侵)
2. Footprinting and Reconnaissance (蒐集蛛絲馬跡與網路勘查)
3. Scanning Networks (網路服務與弱點掃描)
4. Enumeration (列舉系統資訊)
5. Vulnerability Analysis (弱點分析)
6. System Hacking (入侵電腦系統)
7. Malware Threats (惡意程式威脅)
8. Sniffers (網路監聽與攻擊)
9. Social Engineering (社交工程)
10. Denial-of-Service (阻斷服務攻擊與傀儡網路)
11. Session Hijacking (連線劫持)
12. Evading IDS, Firewalls and Honeypots (規避入侵偵測/防火牆與誘捕系統)
13. Hacking Webservers (入侵網站)
14. Hacking Web Application (入侵網站程式)
15. SQL Injection (資料隱碼攻擊)
16. Hacking Wireless Network (入侵無線網路)
17. Hacking Mobile Platforms (入侵行動平台)
18. IoT and OT Hacking(入侵物聯網與工控)
19. Cloud Computing (雲端運算)
20. Cryptography (密碼學)


### 考試題目的類型

150 道選擇題上機考。  題目大多是考:

1. 攻擊類型 / 原理 / 方式
	例:
	> While performing online banking using a Web browser, a user receives an email that contains a link to an interesting Web site. When the user clicks on the link, another Web browser session starts and displays a video of cats playing a piano. The next business day, the user receives what looks like an email from his bank, indicating that his bank account has been accessed from a foreign country. The email asks the user to call his bank and verify the authorization of a funds transfer that took place. What Web browser-based security vulnerability was exploited to compromise the user?
	>
	> A. Clickjacking
	B. Cross-Site Request Forgery
	C. Cross-Site Scripting
	D. Web form input validation

2. 防範方式 / 方法
	例:
	> Some clients of TPNQM SA were redirected to a malicious site when they tried to access the TPNQM main site. Bob, a system administrator at TPNQM SA, found that they were victims of DNS Cache Poisoning.
What should Bob recommend to deal with such a threat?
	>
	>A. The use of security agents in clients' computers
	B. The use of double-factor authentication
	C. Client awareness
	D. The use of DNSSEC
3. 工具軟體與使用方式
	例:
	> If you want to only scan fewer ports than the default scan using Nmap tool, which option would you use?
	>
	> A. -n
	B. -F
	C. -O
	D. -sT
	
4. 通訊協定與其它背科
	例:
	> Identify the UDP port that Network Time Protocol (NTP) uses as its primary means of communication?
	>
	> A. 131
	B. 3389
	C. 123
	D. 160

### 報名考式

筆者在上完課之後，立馬詢問了要如何報名考試。才知道考試需要提前 5 天進行。所以報名了後面的梯次。

[考試報名連結][3]

### Exam 跟 ASPEN 的信箱不一樣 ？！

上課的時候會在 [ASPEN](https://aspen.eccouncil.org) 上建立帳號來取得電子教材。
考試的時候會是在 [EC Council - Exam Center][4] 進行考試。

當考試完通過之後要取得電子證書時，這兩個平台是認注冊時的電子信箱的。
如果這兩個平台使用的 是不同信箱，在發證時會自動用你 Exam Center  的信箱幫你在 ASPEN 建立帳號。

後續就可以用忘記密碼的流程來設定密碼。

{{< figure src="images/aspen_1.png" caption="上課時的帳號" >}}

{{< figure src="images/aspen_2.png" caption="考過後自動產生的帳號" >}}


### 秀 Time

不免俗的還是要來秀一下證書

{{< figure src="images/ECC-CEH-Certificate.png" caption="CEH 證書" >}}

在官方提供的[證書驗證頁面][1]來輸入姓名與證號來驗證它否是為有效的證書。

## 小結

筆者認為取得這張證照頂多是知道了相關知識，而非真就真的會進行攻擊。

## 參考連結

- [官方網站](https://www.eccouncil.org/programs/certified-ethical-hacker-ceh/)
-  [EC Council - Exam Center][4]
- [ECCouncil 312-50v11 Exam][5]

[1]:https://aspen.eccouncil.org/VerifyBadge?type=certification&a=ML2/I/iEhBS2vf5FeUb5KKu2z4yLzqefpujmqTkFBUE=
[2]:https://www.uuu.com.tw/Course/Show/300/EC-Council-CEH駭客技術專家認證課程
[3]:https://www.uuu.com.tw/Forms/ClassPicker/SelectRedhatExams
[4]:https://www.eccexam.com
[5]:https://www.examtopics.com/exams/eccouncil/312-50v11