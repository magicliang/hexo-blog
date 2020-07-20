#!/bin/bash

git pull

# 以后用post文件夹来存储附件
# ./delete_all_post_folders.sh

echo "begin to scan sensitive contents:"

for i in {1..10}
do
    echo ""
done

grep -rn --color "\.sankuai\.\|\.meituan\." ./source/_posts | grep -v "tech.meituan.com"

for i in {1..10}
 do
     echo ""
done

read -p "Continue? type n to stop, otherwise continue " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Nn]$ ]]
then
    # 直接退出
    echo "byebye"
    exit 0
fi

# 在部署前先清理旧文件
hexo clean
# 在部署前先生成
hexo d -g
git add  -A .
git commit -m "change blog"
git push


