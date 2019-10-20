---
title: 本地 rebase 多个 commit 的几个命令
date: 2018-02-03 21:02:25
tags:
- git
---

```bash
# 进入编辑窗口后，除了最上的 commit 不能够 squash，其他全部都可以 squash。然后提交还会出现一个重新修改注释的地方。
git rebase -i 还可以加上要变基的最后一个 commit（开区间）

# 如果出了问题，可以用这个命令退出
git rebase --abort

# 查看全部提交历史
git log

# 查看某个提交的具体细节
git show a828e5a2ea49845a8136df62b5bab536676c975e

# 修改最后一次提交的细节
git commit --amend
```
