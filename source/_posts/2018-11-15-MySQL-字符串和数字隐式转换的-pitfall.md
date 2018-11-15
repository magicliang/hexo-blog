---
title: MySQL 字符串和数字隐式转换的 pitfall
date: 2018-11-15 14:46:59
tags:
- MySQL 
- 未完成
---
Data truncation: Truncated incorrect

不要小看 MySQL，它出 warning 就一定有错误。

不要滥用 MySQL 字符串到decimal，和 decimal 到 string 的转换。这样有时候 MySQL 不只是 warning。