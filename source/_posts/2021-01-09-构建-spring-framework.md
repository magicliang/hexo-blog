---
title: 构建 spring-framework
date: 2021-01-09 14:39:58
tags:
- Spring
- gradle
---
# 介绍下使用到的 Gradle 工具

[《一篇文章讲清楚Gradle与Gradle Wrapper的区别》][1]

comments：

 - Gradle Wrapper 提供了一种“在本地构建中，使用特定版本的 Gradle 进行构建”的功能。
 - 换言之，对于大多数敏捷迭代的项目而言，应该选择 ./gradlew clean build，而不是 gradle clean build。这样不会遇到 pluginManagement 之类的问题，这样说来，每个项目都是自构建的。
 - 要么 IDE（像 Android Studio）自带 gradle wrapper，要么项目自带一个 gradle/wrapper 文件夹，这个文件夹里指定了 gradle-wrapper.properties。 这个命令专门指定了特定版本的 gradle。-all.jar、-bin.jar、-src.jar 分别代表不同的包。
 - gradlew是在linux,mac下使用的，gradlew.bat是在window下使用的，提供在命令行下执行gradle命令的功能。-这种 w 的中间层策略，值得我们学习。
 - 每个项目本身都带有特定的 plugin（可能在下一版本失效），所以 gradle 专门写了针对 gradle project 的 upgrade 指南​。
 - .gradle文件夹，就是那个跟项目第一个文件夹，带点的那个。那个对我们没什么用，他是gradle运行的时候产生的一些记录性的文件。我们不需要关注。

# 实际构建的过程

`./gradlew -a :spring-webmvc:test`

这里面蕴藏一个模式`./gradlew -a :项目名:task名`。

# 代码风格

Spring 使用 tab 而不是空格（和很多其他项目恰恰相反），替换空格的方法是`find . -type f -name "*.java" -exec perl -p -i -e "s/[ \t]$//g" {} \;`。

Spring 的代码不提倡使用静态引用：

> Static imports should not be used in production code. They should be
> used in test code, especially for things like import static
> org.assertj.core.api.Assertions.assertThat;.

成员的顺序：

1. static fields
2. normal fields
3. constructors
4. (private) methods called from constructors
5. static factory methods
6. JavaBean properties (i.e., getters and setters)
7. method implementations coming from interfaces
8. private or protected templates that get called from method
9. implementations coming from interfaces
10. other methods
11. equals, hashCode, and toString

Spring 使用埃及括号。Braces mostly follow the Kernighan and Ritchie style (a.k.a., "Egyptian brackets") for nonempty blocks and block-like constructs。

  [1]: https://blog.csdn.net/sinat_31311947/article/details/81084689
