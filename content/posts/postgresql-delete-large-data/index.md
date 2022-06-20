---
date: 2022-06-20T11:32:58+08:00
title: "如何在 Postgresql 資料庫中的刪除大量資料"
description: ""
author: "Yuan"
draft: false
tags: ["postgresql"]
keywords: []
categories: ["database"]
---

## 前言

一開始為了收集、分析資料，筆者把所有的記錄都保存起來。隨著專案的進行我們只需要保留特定條件的記錄。想說就趁著這次順手記錄起來吧。
<!--more-->

## 主要內容

### 登入資料庫

```bash
psql -h myhost -d mydb -U myuser [-W]
```

### 列出所有資料表
```postgres
postgres=# \dt
```
or

```sql
SELECT *
FROM pg_catalog.pg_tables
WHERE 1 = 1 AND
    schemaname != 'pg_catalog' AND 
    schemaname != 'information_schema';
```

### 透過建立臨時表來刪除大量資料

```sql
BEGIN;

SET LOCAL temp_buffers = '1000MB';

-- copy surviving rows into temporary table
CREATE TEMP TABLE tmp AS
SELECT u.*
FROM users u
WHERE u.id IS NULL;

-- empty table
TRUNCATE users;

-- insert back surviving rows
INSERT INTO users TABLE tmp;

COMMIT;

```
{{< notice info >}}
如果途中有出現錯誤，則要使用 `END;` 進行退回 (Rollback)。
{{< /notice >}}


## 參考連結

- [Postgresql show tables][1]
- [Best way to delete millions of rows by id][2]

[1]: https://www.postgresqltutorial.com/postgresql-administration/postgresql-show-tables/
[2]: https://stackoverflow.com/questions/8290900/best-way-to-delete-millions-of-rows-by-id
