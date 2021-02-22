---
title: maven-enforcer-plugin 解决包冲突设计方案
date: 2020-03-11 15:45:23
tags:
- Java
- Maven
---
# 执行时机

生命周期validate环节。

# dependencyConvergence执行逻辑

通过访问maven dependency tree生成的依赖树，存入map中，key是groupid和artifactId组合，value是依赖对象list，通过判断每个list里的版本号是否相同来判断所有依赖是否为同一个版本。

# 配置实例

```xml
<build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-enforcer-plugin</artifactId>
                <version>3.0.0-M3</version>
                <executions>
                    <execution>
                        <id>enforce</id>
                        <goals>
                            <goal>enforce</goal>
                        </goals>
                        <configuration>
                            <rules>
                                <bannedDependencies>
                                    <excludes>
                <exclude>com.alibaba:fastjson:(,1.2.60)</exclude>
                <exclude>org.hibernate:hibernate-validator</exclude>
                  </excludes>
                                </bannedDependencies>
                            </rules>
                            <fail>true</fail>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
</build>
```

# 快速检验

在自己分支开发完成后，执行`mvn validate`命令即可查看冲突信息

# 移除冲突jar

登陆线上机器确认冲突jar的版本，移除不是对应版本的jar，方法：`Dependency Analyzer` 中搜索冲突jar名，右键选择移除即可自动生成exclude内容。

# 参考

[《重新看待Jar包冲突问题及解决方案》][1]

  [1]: https://www.jianshu.com/p/100439269148
