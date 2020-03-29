#!/bin/bash

git pull

# 以后用post文件夹来存储附件
# ./delete_all_post_folders.sh

echo "begin to scan sensitive contents:"

for i in {1..30}
do
    echo ""
done

grep -rn --color "\.sankuai\.\|\.meituan\." ./source/_posts

for i in {1..30}
 do
     echo ""
done

#if echo "$OUTPUT" | grep -q "(Status:\s200)"; then
#    echo "MATCH"
#fi


# 在部署前先清理旧文件
hexo clean
# 在部署前先生成
hexo d -g
git add  -A .
git commit -m "change blog"
git push


