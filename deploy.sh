#!/bin/bash

git pull

# 以后用post文件夹来存储附件
# ./delete_all_post_folders.sh

# 在部署前先清理旧文件
hexo clean
# 在部署前先生成
hexo d -g
git add  -A .
git commit -m "change blog"
git push


