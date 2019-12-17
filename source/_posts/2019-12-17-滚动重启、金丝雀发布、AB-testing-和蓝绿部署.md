---
title: 滚动重启、金丝雀发布、AB testing 和蓝绿部署
date: 2019-12-17 16:03:44
tags:
- 持续交付
---
本文讨论发布周期（release cycles）里 deployment strategy 的问题，抛开大规模部署的 [big bang deployment][1]。

# 滚动重启、金丝雀发布、AB testing
在 martin fowler 的博客里，金丝雀发布和滚动重启和 AB testing 并没有本质区别，都是 phased approach或者 incremental approach，是 [ParallelChange][2] 思想的实践。

当我们拥有一个新版本时：

## 滚动重启（rolling restart）
rolling restart 会让新旧版本在环境里长时间共存，逐一使节点部署新版本，这样易于发现问题和回滚。

## 金丝雀发布（canary release）
而金丝雀发布同样允许新旧版本长时间共存，在逐一部署新节点的前提下，逐步利用 LB 之类的基础设施来切分用户，其策略还可以细分为：

先不给新版本，在无流量的情况下在生产环境验证 - 很多大厂的实现都忽略了这点。

尽量让内部用户先使用 - FB 之类的大厂的员工都非常多，使用一个特性开关（名字很多，比如 feature bits, flags, flippers, switches， martin fowler prefers [FeatureToggle][3]），单独让内部员工使用，来检查其中的问题。 amazon 使用暗部署（dark launch），而蚂蚁金服使用灰度环境（grey environment） 来将生产的真流量释放到新版本上。

然后逐步开放给新用户使用。这个过程中涉及到的策略和方法是：使用 LB 的路由策略，将流量逐一发布到特定新版本节点上；基于用户选择，只有特定用户的流量可以进入到新版本的机器里。大部分大厂都采用基于节点的流量分配法则，实际上还可以根据源 ip、地理位置和用户人群划分来解决这个问题。

## AB testing
金丝雀发布因为可以使不同的人群体验不同版本，所以可以被看作 AB testing 的等同 implementation。

但是，金丝雀发布的用意是“发现新版本问题，提供回滚的灵活性”，而  AB testing 的用意是为了验证和比对不同的具体策略的效果。金丝雀发布必然导致软件的新版本代替旧版本（注意软件的版本和代码的版本是不一样的），间接地提供了 AB testing 的能力；而真正厉害的 ab testing 却可以不依赖软件版本更新，只把用户加以区分，并配以不同的策略即可。

# 蓝绿部署

蓝绿部署的特性要求：

1 旧版本存在于蓝集群。

2 新版本部署于绿集群。

绿集群在上线的时候完全没有流量，在充分验证完成以后一下子通过 LB 把流量完全切入绿集群。

金丝雀发布在事实上是在同一套物理环境里实现渐进式替换，优点是要求的节点数量更小，发现 last minute 问题的时候影响面更可控，缺点是出了问题也要逐步回滚，系统是在进行有损服务的。

蓝绿部署要求生产环境有两套环境，优点是可以直接通过 LB 一键回滚，缺点是占用节点数量过多，出现 last minute 问题的时候影响面更大。

# 特性开关

特性开关的细节可以参考[Feature Toggles (aka Feature Flags)][4]。

特性开关的要点是解耦 decision point 和 decision 决策逻辑。

维护这些开关的长期性和动态性实际上需要很重的架构权衡。

![此处输入图片的描述][5]


  [1]: https://dev.to/mostlyjason/intro-to-deployment-strategies-blue-green-canary-and-more-3a3
  [2]: https://martinfowler.com/bliki/ParallelChange.html
  [3]: https://martinfowler.com/bliki/FeatureToggle.html
  [4]: https://martinfowler.com/articles/feature-toggles.html
  [5]: https://s2.ax1x.com/2019/12/17/QoKOSI.png
