---
title: Spring AOP 笔记
date: 2020-04-05 12:17:29
tags:
- Java
- Spring 
---
# AOP 的基本概念

Aspect: A modularization of a concern that cuts across multiple classes. 方面，**横跨多个类**的模块化关注点。如果只是简单地横跨多个类，可以考虑使用继承 + 组合 + 设计模式。如果使用某种模式匹配来横跨多个类，才需要考虑使用 Aspect。

Join point: A point during the execution of a program, such as the execution of a method or the handling of an exception. In Spring AOP, a join point always represents a method execution. 结合点是我们最需要关注的东西，既包括了**方法执行过程，也包含了异常处理过程**。

Advice: Action taken by an aspect at a particular join point. 方面针对结合点采取的**行动**。对 Advice 而言，join point 经常是他们的参数（至少 Advice 对应的 Interceptor 里包装了这些参数）。

Pointcut: A predicate that matches join points. Advice is associated with a pointcut expression and runs at any join point matched by the pointcut (for example, the execution of a method with a certain name). The concept of join points as matched by pointcut expressions is central to AOP, and Spring uses the AspectJ pointcut expression language by default. 切点（英文是点切）实际上是对 Join point 进行判定的谓词。**切点把 Join point 和 Advice 实际上结合起来了**。默认的切点表达式来自于 AspectJ pointcut expression。

Advisor：Base interface holding AOP advice (action to take at a joinpoint) and a filter determining the applicability of the advice (such as a pointcut). This interface is not for use by Spring users, but to allow for commonality in support for different types of advice.
Spring AOP is based around around advice delivered via method interception, compliant with the AOP Alliance interception API. The Advisor interface allows support for different types of advice, such as before and after advice, which need not be implemented using interception. Advisor 不是给 Spring 用户用的。它包含一个 advice，是 一个 advice 的容器 - 相应地，Aspect 是包含很多 advice 的容器，这是个 Spring 用户用的。

Introductions：Declaring additional methods or fields on behalf of a type. 类似混型（mixin），在不打开原有类型以改变原有类型的内容的前提下（类似 Ruby 的元编程或者 C# 的 partial class），为类型增加新的功能。

Target object: An object being advised by one or more aspects. Also referred to as the “advised object”. Since Spring AOP is implemented by using runtime proxies, this object is always a proxied object. 目标对象、建议对象，即原始对象。

AOP proxy: An object created by the AOP framework in order to implement the aspect contracts (advise method executions and so on). In the Spring Framework, an AOP proxy is a JDK dynamic proxy or a CGLIB proxy. Interceptor、Proxy，aspect contracts 的实现。

Weaving: linking aspects with other application types or objects to create an advised object. This can be done at compile time (using the AspectJ compiler, for example), load time, or at runtime. Spring AOP, like other pure Java AOP frameworks, performs weaving at runtime. 织入，即把方面和 advised object 联系起来的过程。可以在编译时（性能最好）、装载时（容易被忽略）和运行时（所有的 pure java AOP framework 的默认选项）执行。大多数情况下，Spring AOP 已经够用了。

可以看出 Spring 的设计里面是尽可能地在 IOC 的基础上提供强大的`auto-proxying`服务，所有的增强功能，都是在代理里实现的，已解决企业级开发中常见的问题，而不是提供强大而完备的 AOP 实现（尽管它已经很强大了）。

所有声明、配置（不管是注解还是 xml 配置）：aspect、advice、pointcut、advisor、自己实现的 Interceptor、其他 proxies 可以混合使用，即 Mixing Aspect Types。

# 到底应该使用哪种代理呢？

Spring 默认使用 Java 动态代理，任何接口实现都可以被代理。但这种代理只能拦截接口方法。最终产生的 object 是 Proxy 的 instance 且 Interface 的 implementation。

当一个对象没有实现一个接口的时候，Spring 会退而求其次，使用 cglib 代理。当然，我们也可以（实际上经常）[强制使用 cglib 代理][1]。这种代理可以拦截一切可以覆写的方法。最终产生的 object 是原类型的 subclass 的 instance。

It is perfectly possible to mix @AspectJ style aspects by using the auto-proxying support, schema-defined <aop:aspect> aspects, <aop:advisor> declared advisors, and even proxies and interceptors in other styles in the same configuration. All of these are implemented by using the same underlying support mechanism and can co-exist without any difficulty.

# 声明各种基础类型

## 激活 @Aspect 注解的方式

使用 @Aspect 注解的风格被称为 [@AspectJ style][2]。@AspectJ refers to a style of declaring aspects as regular Java classes annotated with annotations. 

以下两种流程都能激活 @Aspect 注解的解析。注意，即使第二种方法使用 了 xml，也只是激活了对 @Aspect 注解的解析。真正的配置还是放在  @Aspect 里。

注意，这种注解本身的定义来自于 AspectJ 项目（[哪怕实际上是 Spring AOP 在起作用][3]），这也要求类路径里存在`aspectjweaver.jar`。

```java
@Configuration
@EnableAspectJAutoProxy
public class AppConfig {
}
```

```xml
<aop:aspectj-autoproxy/>
```

### 声明 Aspect

```java
package org.xyz;
import org.aspectj.lang.annotation.Aspect;

@Aspect
public class NotVeryUsefulAspect {
}

```

```xml
<bean id="myAspect" class="org.xyz.NotVeryUsefulAspect">
    <!-- configure properties of the aspect here -->
</bean>
```

Aspect 可以是普通的 class，只是里面可以有 advice、pointcut 和 introduction。

```java
// 直接声明切点，方法签名都是 void，这个声明要要被引用，直接用名称 anyOldTransfer - 用一个方法来设计切点变量是一种设计思想
@Pointcut("execution(* transfer(..))") // the pointcut expression
private void anyOldTransfer() {} // the pointcut signature

// 切点里加上 advice
@Around("execution(public * package..*.*(..))")
    public Object around(ProceedingJoinPoint joinPoint) throws Throwable {}
```

```xml
<aop:config>
    <aop:pointcut id="anyDaoMethod"
      expression="@target(org.springframework.stereotype.Repository)"/>
</aop:config>
```

Spring AOP （proxy-based）的切点里 this 总是指代理，而 target 指的是被代理对象；AOP （type-based）里都指代理和被代理对象。

Spring AOP 里的 join point 专指 method execution，其他 AOP 框架不只是拦截方法执行。

### 详解 pointcut

切点有自己的 PCD（pointcut designators ），来自于  pointcut expressions（主要来自于 AspectJ），完整的表达式语法见[《Appendix B. Language Semantics》][4]：

- execution: For matching method execution join points. This is the primary pointcut designator to use when working with Spring AOP. 方法执行连接点，这是最常用的。

```java
@Pointcut("execution(public String com.baeldung.pointcutadvice.dao.FooDao.findById(Long))")
@Pointcut("execution(* com.baeldung.pointcutadvice.dao.FooDao.*(..))")

// 它的语法是：
execution(modifiers-pattern? ret-type-pattern declaring-type-pattern?name-pattern(param-pattern)
                throws-pattern?)
```
- within: Limits matching to join points within certain types (the execution of a method declared ** within a matching type ** when using Spring AOP) 以只在特定类型里的方法执行作为切点。execution 的阉割版本。

```java
@Pointcut("within(com.baeldung.pointcutadvice.dao.FooDao)")
@Pointcut("within(com.baeldung..*)")
```
- this: Limits matching to join points (the execution of methods when using Spring AOP) where the bean reference (Spring AOP proxy) is an instance of the given type.  这里的 this 是 proxy 的意思，限制 proxy - 当我们使用 JDK dynamic proxy 的时候，推荐使用这个 PCD（并不必然）。

```java
public class FooDao implements BarDao {
    ...
}

// jdk dynamic proxy
@Pointcut("target(com.baeldung.pointcutadvice.dao.BarDao)")
```

- target: Limits matching to join points (the execution of methods when using Spring AOP) where the target object (application object being proxied) is an instance of the given type. 限制目标类型。当我们使用 cglib proxy 的时候，推荐使用这个 PCD（并不必然）

```java
// cglib proxy
@Pointcut("this(com.baeldung.pointcutadvice.dao.FooDao)")
```

- args: Limits matching to join points (the execution of methods when using Spring AOP) where the arguments are instances of the given types. 限制参数。

```java
@Pointcut("execution(* *..find*(Long))")
```

- @target: Limits matching to join points (the execution of methods when using Spring AOP) where the class of the executing object has an annotation of the given type. 限制 target 有特定注解。**这种切点配合特定的类注解特别有用！**

```java
@Pointcut("@target(org.springframework.stereotype.Repository)")
```

- @args: Limits matching to join points (the execution of methods when using Spring AOP) where the runtime type of the actual arguments passed have annotations of the given types. 限制参数有特定注解。

```java
//  Suppose that we want to trace all the methods accepting beans annotated with @Entity annotation:
@Pointcut("@args(com.baeldung.pointcutadvice.annotations.Entity)")
public void methodsAcceptingEntities() {}

@Before("methodsAcceptingEntities()")
public void logMethodAcceptionEntityAnnotatedBean(JoinPoint jp) {
    logger.info("Accepting beans with @Entity annotation: " + jp.getArgs()[0]);
}
```

- @within: Limits matching to join points within types that have the given annotation (the execution of methods declared in types with the given annotation when using Spring AOP). 限制在类型有特定注解。

```java

@Pointcut("@within(org.springframework.stereotype.Repository)")

// 等价于

@Pointcut("within(@org.springframework.stereotype.Repository *)")
```

- @annotation: Limits matching to join points where the subject of the join point (the method being executed in Spring AOP) has the given annotation. 限制连接点方法有特定注解。**这种切点配合特定的方法注解特别有用！**

```java
@Pointcut("@annotation(com.baeldung.pointcutadvice.annotations.Loggable)")
public void loggableMethods() {}

@Before("loggableMethods()")
public void logMethod(JoinPoint jp) {
    String methodName = jp.getSignature().getName();
    logger.info("Executing method: " + methodName);
}

@Retention(RetentionPolicy.RUNTIME)
public @interface Idempotent {
    // marker annotation
}

<aop:pointcut id="idempotentOperation"
        expression="execution(* com.xyz.myapp.service.*.*(..)) and
        @annotation(com.xyz.myapp.service.Idempotent)"/>
```

-  bean 特定的 bean 名称/名称模式引用的，类似` BeanNameAutoProxyCreator`。

```java
@Pointcut("bean(tradeService)")
@Pointcut("bean(*Service)")
```

更多例子：

```java
// anyPublicOperation matches if a method execution join point represents the execution of any public method.

// inTrading matches if a method execution is in the trading module.
@Pointcut("execution(public * *(..))")
private void anyPublicOperation() {} 

// tradingOperation matches if a method execution represents any public method in the trading module.
@Pointcut("within(com.xyz.someapp.trading..*)")
private void inTrading() {} 

@Pointcut("anyPublicOperation() && inTrading()")
private void tradingOperation() {} 

// 按照系统架构进行切点的分类

@Aspect
public class SystemArchitecture {

    /**
     * A join point is in the web layer if the method is defined
     * in a type in the com.xyz.someapp.web package or any sub-package
     * under that.
     */
    @Pointcut("within(com.xyz.someapp.web..*)")
    public void inWebLayer() {}

    /**
     * A join point is in the service layer if the method is defined
     * in a type in the com.xyz.someapp.service package or any sub-package
     * under that.
     */
    @Pointcut("within(com.xyz.someapp.service..*)")
    public void inServiceLayer() {}

    /**
     * A join point is in the data access layer if the method is defined
     * in a type in the com.xyz.someapp.dao package or any sub-package
     * under that.
     */
    @Pointcut("within(com.xyz.someapp.dao..*)")
    public void inDataAccessLayer() {}

    /**
     * A business service is the execution of any method defined on a service
     * interface. This definition assumes that interfaces are placed in the
     * "service" package, and that implementation types are in sub-packages.
     *
     * If you group service interfaces by functional area (for example,
     * in packages com.xyz.someapp.abc.service and com.xyz.someapp.def.service) then
     * the pointcut expression "execution(* com.xyz.someapp..service.*.*(..))"
     * could be used instead.
     *
     * Alternatively, you can write the expression using the 'bean'
     * PCD, like so "bean(*Service)". (This assumes that you have
     * named your Spring service beans in a consistent fashion.)
     */
    @Pointcut("execution(* com.xyz.someapp..service.*.*(..))")
    public void businessService() {}

    /**
     * A data access operation is the execution of any method defined on a
     * dao interface. This definition assumes that interfaces are placed in the
     * "dao" package, and that implementation types are in sub-packages.
     */
    @Pointcut("execution(* com.xyz.someapp.dao.*.*(..))")
    public void dataAccessOperation() {}

    // The execution of any public method:
    execution(public * *(..))
    
    // The execution of any method with a name that begins with set:
    execution(* set*(..))
    
    // The execution of any method defined by the AccountService interface:
    execution(* com.xyz.service.AccountService.*(..))
    
    // The execution of any method defined in the service package:
    execution(* com.xyz.service.*.*(..))
    
    // The execution of any method defined in the service package or one of its sub-packages:
    execution(* com.xyz.service..*.*(..))
    
    // Any join point (method execution only in Spring AOP) within the service package:
    within(com.xyz.service.*)

    // Any join point (method execution only in Spring AOP) within the service package or one of its sub-packages:
    within(com.xyz.service..*)
    
    // Any join point (method execution only in Spring AOP) where the proxy implements the AccountService interface:
    this(com.xyz.service.AccountService)
    
    // Any join point (method execution only in Spring AOP) where the target object implements the AccountService interface:
    target(com.xyz.service.AccountService)
    
    // Any join point (method execution only in Spring AOP) that takes a single parameter and where the argument passed at runtime is Serializable:
    args(java.io.Serializable)

    // Any join point (method execution only in Spring AOP) where the target object has a @Transactional annotation:
    @target(org.springframework.transaction.annotation.Transactional)
You can also use '@target' in a binding form. See the Declaring Advice section for how to make the annotation object available in the advice body.
Any join point (method execution only in Spring AOP) where the declared type of the target object has an @Transactional annotation:

    @within(org.springframework.transaction.annotation.Transactional)
You can also use '@within' in a binding form. See the Declaring Advice section for how to make the annotation object available in the advice body.
Any join point (method execution only in Spring AOP) where the executing method has an @Transactional annotation:

    @annotation(org.springframework.transaction.annotation.Transactional)
You can also use '@annotation' in a binding form. See the Declaring Advice section for how to make the annotation object available in the advice body.
Any join point (method execution only in Spring AOP) which takes a single parameter, and where the runtime type of the argument passed has the @Classified annotation:

    @args(com.xyz.security.Classified)
}
```

切点表达式会在编译时被优化，被冲写成 DNF 范式形式，并且会被重排序，以提升性能。
 
注意，可以混合使用任何地方定义的切点：**Java config 里的 bean 可以引用 xml 里定义的切点；反过来也可以**。

```xml
<aop:config>
    <!--  -->
    <aop:advisor
        pointcut="com.xyz.someapp.SystemArchitecture.businessService()"
        advice-ref="tx-advice"/>
</aop:config>

<tx:advice id="tx-advice">
    <tx:attributes>
        <tx:method name="*" propagation="REQUIRED"/>
    </tx:attributes>
</tx:advice>
```

切点表达式分为三类：

- Kinded designators select a particular kind of join point: execution, get, set, call, and handler.

- Scoping designators select a group of join points of interest (probably of many kinds): within and withincode

- Contextual designators match (and optionally bind) based on context: this, target, and @annotation

好的切点应该使用两种以上的表达式，性能才好，如：

```java
 within(com.bigboxco..*) && execution(public * *(..))
```

### 详解 advice

#### advice 的类型

Advice 可以分为：

 - before 申请资源适合放在这里
 - After returning

```java
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.AfterReturning;

@Aspect
public class AfterReturningExample {
    @AfterReturning(
        pointcut="com.xyz.myapp.SystemArchitecture.dataAccessOperation()",
        // 注意名字必须完全匹配形参
        returning="retVal")
            // 使用返回值的 after 例子，注意这个 object 参数，这里不可能泛型化
        // 这里如果限制返回值类型，后果自负，spring 本身是 fully typed 类型匹配的，有好处也有坏处
    public void doAccessCheck(Object retVal) {
        // ...
    }

}
```
 - After throwing（不怎么常见，但 Spring MVC 的 Controller Advice 就是这样实现的）。PCD 里是不包含对于 exception 的定位的，只能通过 PCD 里定位方法，然后使用这个 advice。这是 Spring 对异常处理的唯一设计。

```java
@Aspect
public class AfterThrowingExample {

    @AfterThrowing(
        pointcut="com.xyz.myapp.SystemArchitecture.dataAccessOperation()",
        // 注意名字必须完全匹配形参
        throwing="ex")
        // 这里可以限制异常类型，后果自负
    public void doRecoveryActions(DataAccessException ex) {
        // ...
    }
}
```

 - After (finally) advice = returning + throwing，隐式包含 finally。释放资源适合放在这里。
 - around（大部分的 advice 都可以这样用，因为它兼容 before、after（实际上囊括了上面所有的 advice）， 而且管控范围最广）适合申请资源、释放资源、权限管理、日志，它因为是栈封闭的，所以是在方法执行前后，线程安全地共享状态（ share state before and after a method execution in a thread-safe manner） - timer 的合理方式。

```java

// 注意，这里的参数名指的是 advice 里的参数名，而不是原始被拦截方法的参数名-也不适合理解原始参数名

// 使用命名参数的正统方式。被拦截的方法，必须至少有一个参数，且第一个参数要被转化为 Account 类型传递给 Advice。
@Before("com.xyz.myapp.SystemArchitecture.dataAccessOperation() && args(account,..)")
public void validateAccount(Account account) {
    // ...
}

// 理解注解的正统方式
@Retention(RetentionPolicy.RUNTIME)
// 注意严格限定注解的使用类型
@Target(ElementType.METHOD)
public @interface Auditable {
    AuditCode value();
}

@Before("com.xyz.lib.Pointcuts.anyPublicMethod() && @annotation(auditable)")
public void audit(Auditable auditable) {
    AuditCode code = auditable.value();
    // ...
}

// 处理泛型
public interface Sample<T> {
    void sampleGenericMethod(T param);
    void sampleGenericCollectionMethod(Collection<T> param);
}

// 这里 MyType 就是 type parameter，实例化了 T
@Before("execution(* ..Sample+.sampleGenericMethod(*)) && args(param)")
public void beforeSampleMethod(MyType param) {
    // Advice implementation
}

// Collection<MyType> 不会生效的。Collection<?>能够保证整个 Collection 里只有一个类型，这样我们只要 check 一个元素就能知道整个集合的 type。
@Before("execution(* ..Sample+.sampleGenericCollectionMethod(*)) && args(param)")
public void beforeSampleMethod(Collection<?> param) {
    // Advice implementation
}


// 使用 argName 的 attribute 来指定实际的 advice 参数的名称和顺序
@Before(value="com.xyz.lib.Pointcuts.anyPublicMethod() && target(bean) && @annotation(auditable)",
        argNames="bean,auditable")
public void audit(Object bean, Auditable auditable) {
    AuditCode code = auditable.value();
    // ... use code and bean
}

// 如果要强行指定切点的类型，则只能使用 ProceedingJoinPoint，不能用 argNames
@Component
@Aspect
public class AspectJAnnotationArgsBrowserAroundAdvice {

    @Pointcut("execution(* com.lcifn.spring.aop.bean.ChromeBrowser.*(String,java.util.Date+,..))")
    private void pointcut(){
        
    }
    
    @Around(value="pointcut()")
    public Object aroundIntercept(ProceedingJoinPoint pjp) throws Throwable{
        Object retVal = pjp.proceed();
        return retVal;
    }
}
```

如果要使用 args 和 argName 配合，则不能指定切点的类型。

```xml
<!-- 注意 pointcut 和 around 都可以指定参数名称，而且必须一一匹配，否则 Spring 会出错-->
<aop:config proxy-target-class="true">
    <aop:pointcut id="pointcut" expression="execution(* com.lcifn.spring.aop.bean.*.*(..)) and args(str,date,..)"/>
    <aop:aspect ref="advice">
        <aop:around method="aroundIntercept" pointcut-ref="pointcut" arg-names="str,date"/>
    </aop:aspect>
</aop:config>
```
 
**通常意义上的 Advice 被建模为 interceptor（所以 Advice 的实现是一个方法，映射到 Spring 的内部不是一个方法，而是一个类型，因为一个MethodInterceptor 只有一个 invoke 点**）。围绕着 Join point 串起来一系列 interceptor（aspect 对 advised object 可以多对一，但彼此之间并不能相互 advised）。
 
我们通常会使用 around，但 Spring 推荐尽量用 less powerful 的 advice 以避免出错。

#### advice 的优先级

有最高优先级的 advice 在 advice 嵌套的最外层，before 最先执行而 after 最后执行。

可以通过实现 org.springframework.core.Ordered 或者使用 Order 注解给 Aspect - advice 的优先级跟着 aspect 的优先级走。

### 详解 introduction

对于 this proxy 而言，introduction 引入了混型（mixin）；而对于调用者而言，这个新的 proxy 实际上是个 adapter。

```java
@Aspect
public class UsageTracking {
    
    // 解耦设计 1：符合这个 pattern 的 bean  的 proxy（不是 bean 本身），都会被默认实现这个接口 UsageTracked，且带有一个默认实现 DefaultUsageTracked。
    @DeclareParents(value="com.xzy.myapp.service.*+", defaultImpl=DefaultUsageTracked.class)
    public static UsageTracked mixin;

    // 解耦设计 2：凡是 proxy 本身带有这个接口 usageTracked 实现，则进行调用。而且这里把 usageTracked 赋值成一个方法参数
    @Before("com.xyz.myapp.SystemArchitecture.businessService() && this(usageTracked)")
    public void recordUsage(UsageTracked usageTracked) {
        usageTracked.incrementUseCount();
    }
}

// 解耦设计 3：直接用 context getBean
UsageTracked usageTracked = (UsageTracked) context.getBean("myService");
```

这个功能在 Spring 内部实际上非常悠久，在 2003 年开发的代码里，就留有 IntroductionAdvisor 的痕迹了。

###  高级主题 - AOP （其他）初始化模型

缺省的情况下，全局只有一个单例 aspect， AOP 把它称作“singleton instantiation model”。

```java
@Aspect("perthis(com.xyz.myapp.SystemArchitecture.businessService())")
public class MyAspect {

    private int someState;

    @Before(com.xyz.myapp.SystemArchitecture.businessService())
    public void recordServiceUsage() {
        // ...
    }

}
```

这样的设计允许某些局部状态被限定起来，不再是全局共享。现实中并不太实用 - TransactionInterceptor 本身管理复杂的事务和连接，它却是靠 threadlocal 实现的，并没有依靠多个拦截器。

## 激活 schema-based approach

解析 xml 标签的模式，被 Spring 称为 [schema-based approach][5] 。

这种解决方案的表达能力不如基于注解的表达能力强（**有些切点表达式可以用注解表达，无法用 xml 表达**，，比如 xml 可以表达 id pointcut，却无法表达由 named pointcut 组成的 composited pointcut）。

它基于**新增加**的 [aop schema][6]，需要使用的时候引入一个 schema：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    // 一定要使用这个 xmlns
    xmlns:aop="http://www.springframework.org/schema/aop"
    xsi:schemaLocation="
        http://www.springframework.org/schema/beans https://www.springframework.org/schema/beans/spring-beans.xsd
        http://www.springframework.org/schema/aop https://www.springframework.org/schema/aop/spring-aop.xsd">
    
    <!-- 可以存在多个 <aop:config/> -->
    <aop:config>
    <!-- 可以放 pointcut、aspect 和 advisor -->
    <aop:aspect id="myAspect" ref="aBean">
    </aop:aspect>
     <aop:pointcut id="businessService"
        expression="execution(* com.xyz.myapp.service.*.*(..))"/>
        <!-- 这个类里有好几个 pointcut 表达式 -->
    <aop:pointcut id="businessService"
        expression="com.xyz.myapp.SystemArchitecture.businessService()"/>
    <aop:aspect id="myAspect" ref="aBean">
            <!-- 在标记语言里面慎用 && -->
        <aop:pointcut id="businessService"
            expression="execution(* com.xyz.myapp.service.*.*(..)) and this(service)"/>
            <!-- before advice pointcut 的 service 参数会赋给 monitor -->
            <aop:before pointcut-ref="businessService" method="monitor"/>
            <!-- 指定返回参数 -->
            <aop:after-returning
                pointcut-ref="dataAccessOperation"
                returning="retVal"
                method="doAccessCheck"/>
        
            <!-- 指定抛出异常 -->
            <aop:after-throwing
                pointcut-ref="dataAccessOperation"
                <!-- 绑定参数 -->
                throwing="dataAccessEx"
                method="doRecoveryActions"/>
        
            <!-- 无参数的 after -->
            <aop:after
                pointcut-ref="dataAccessOperation"
                method="doReleaseLock"/>

        </aop:aspect>
        

<!-- introduction 的 xml 版本 -->
<aop:aspect id="usageTrackerAspect" ref="usageTracking">
    <aop:declare-parents
        types-matching="com.xzy.myapp.service.*+"
        implement-interface="com.xyz.myapp.service.tracking.UsageTracked"
        default-impl="com.xyz.myapp.service.tracking.DefaultUsageTracked"/>

    <aop:before
        pointcut="com.xyz.myapp.SystemArchitecture.businessService()
            and this(usageTracked)"
            method="recordUsage"/>

</aop:aspect>
    </aop:config>
    
    <bean id="aBean" class="...">
</beans>
```

注意：**这个`<aop:config/>`依赖于[auto-proxying][7]机制，因而与`AutoProxyCreator`如`BeanNameAutoProxyCreator`是相互冲突的**，所以两者不要混用-与 Mixing Aspect Types 的观点稍微有点冲突。换言之，`<aop:config/>`与`<bean class="org.springframework.aop.framework.autoproxy.BeanNameAutoProxyCreator">`或者手动创建的`DefaultAdvisorAutoProxyCreator`互斥。从优先级来讲，恐怕 <aop:config/> 更适合大多数场景。

### Advisor

Advisor 是 Spring 特定的概念，AspectJ 里没有。

Advisor 是一个自包含的 aspect，只包含一个 advice - 类似 Java8 引入的函数式接口，而且它本身是一个平凡的 bean（废话），必须实现以 Spring 的官定 [advice interface][8]。advisor 适用于内部的 advice，普通的 advice 应该使用 aspect。

```xml
<aop:config>

    <aop:pointcut id="businessService"
        expression="execution(* com.xyz.myapp.service.*.*(..))"/>

    <aop:advisor
        pointcut-ref="businessService"
        advice-ref="tx-advice"/>

</aop:config>

<!-- 事务 advisor -->
<tx:advice id="tx-advice">
    <tx:attributes>
        <tx:method name="*" propagation="REQUIRED"/>
    </tx:attributes>
</tx:advice>

<!-- cache definitions -->
<cache:advice id="cacheAdvice" cache-manager="cacheManager">
    <cache:caching cache="books">
        <cache:cacheable method="findBook" key="#isbn"/>
        <cache:cache-evict method="loadBooks" all-entries="true"/>
    </cache:caching>
</cache:advice>

<!-- 缓存 advisor -->
<!-- apply the cacheable behaviour to all BookService interfaces -->
<aop:config>
    <aop:advisor advice-ref="cacheAdvice" pointcut="execution(* x.y.BookService.*(..))"/>
</aop:config>
```

## 到底应该使用哪种 AOP？

AspectJ 实际上包含了 Compiler 和 weaver，不如 Spring AOP 开箱即用。
根据 [Spring 文档][9]：

 1. 只做 container managed bean interception 可以只用 Spring AOP，否则考虑 AspectJ AOP（如某些领域对象，我想这里指的是 JPA 取出的 entity）。
 2. 如果只做 method interception，可以只用 Spring AOP，否则考虑 AspectJ AOP（如 field set 和 get）- **这决定了实际上这种 aspect 的增强比 proxied-based 的方案强，self-invocation 依然可以被拦截**。
 3. 当场景里需要大量使用 Aspect + 拥有 Eclipse AJDT 插件的时候，使用 AspectJ language syntax （code style）；否则使用 AspectJ 的注解（比如Aspect 很少）。

## 使用 xml 或是 @AspectJ 注解

- xml 的优点是：
 - 它可以独立变化（不同的人对这一点持不同看法），所以比系统里的切面配置更清晰。
- xml 的缺点是：
 - 它违反 DRY 原则，造成了重复；
 - 它表达能力有限：它只有 singleton instantiation model；它不能表达 composite pointcut；

# 代理机制

## 手动调用代理工厂

提供 jdkDynamicProxy 和 cglib 的 proxy 之外的统一抽象。

![aop-proxy-call.png](aop-proxy-call.png)

```java
public class Main {
    public static void main(String[] args) {
        ProxyFactory factory = new ProxyFactory(new SimplePojo());
        factory.addInterface(Pojo.class);
        factory.addAdvice(new RetryAdvice());

        Pojo pojo = (Pojo) factory.getProxy();
        // this is a method call on the proxy!
        pojo.foo();
    }
}
```
 
从外部调用 proxy，会调到 advice。self-invocation （大多数情况下）不会-因为，`Finally, it must be noted that AspectJ does not have this self-invocation issue because it is not a proxy-based AOP framework`，AspectJ 还是很强大的。

## 如何在被代理的 bean 里调用 proxy

 1. 要求暴露了代理，如`<aop:aspectj-autoproxy proxy-target-class="true" expose-proxy="true"/>`或者 `@EnableAspectJAutoProxy(exposeProxy=true)`或者`<aop:config proxy-target-class="true" expose-proxy="true">`或者`        factory.setExposeProxy(true)`。
 2. 使用`AopContext`：`((Service) AopContext.currentProxy()).callMethodB();`这里的callMethodB 是一个需要被代理增强的方法。这样做是不好的，因为这个类感知到了它正在被 proxied，而且直接耦合 Spring API。

它基于一段命名线程局部对象：

```java
public final class AopContext {

    /**
     * ThreadLocal holder for AOP proxy associated with this thread.
     * Will contain {@code null} unless the "exposeProxy" property on
     * the controlling proxy configuration has been set to "true".
     * @see ProxyConfig#setExposeProxy
     */
    private static final ThreadLocal<Object> currentProxy = new NamedThreadLocal<>("Current AOP proxy");


    private AopContext() {
    }


    /**
     * Try to return the current AOP proxy. This method is usable only if the
     * calling method has been invoked via AOP, and the AOP framework has been set
     * to expose proxies. Otherwise, this method will throw an IllegalStateException.
     * @return the current AOP proxy (never returns {@code null})
     * @throws IllegalStateException if the proxy cannot be found, because the
     * method was invoked outside an AOP invocation context, or because the
     * AOP framework has not been configured to expose the proxy
     */
    public static Object currentProxy() throws IllegalStateException {
        Object proxy = currentProxy.get();
        if (proxy == null) {
            throw new IllegalStateException(
                    "Cannot find current proxy: Set 'exposeProxy' property on Advised to 'true' to make it available.");
        }
        return proxy;
    }

    /**
     * Make the given proxy available via the {@code currentProxy()} method.
     * <p>Note that the caller should be careful to keep the old value as appropriate.
     * @param proxy the proxy to expose (or {@code null} to reset it)
     * @return the old proxy, which may be {@code null} if none was bound
     * @see #currentProxy()
     */
    @Nullable
    static Object setCurrentProxy(@Nullable Object proxy) {
        Object old = currentProxy.get();
        if (proxy != null) {
            currentProxy.set(proxy);
        }
        else {
            currentProxy.remove();
        }
        return old;
    }

}
```
 
## @AspectJ 代理的创建方法

注意，这里产生的还是 proxy，适用于注解 bean：

```java
// create a factory that can generate a proxy for the given target object
AspectJProxyFactory factory = new AspectJProxyFactory(targetObject);

// add an aspect, the class must be an @AspectJ aspect
// you can call this as many times as you need with different aspects
factory.addAspect(SecurityManager.class);

// you can also add existing aspect instances, the type of the object supplied must be an @AspectJ aspect
factory.addAspect(usageTracker);

// now get the proxy object...
MyInterfaceType proxy = factory.getProxy();
```

# 使用真正的 AspectJ

ApsectJ 提供一个 compiler 和一个 weaver，可以实现 compile-time weaving 和 load-time weaving - 所以一共有三种织入 aspect 的方法，pure java framework（Java 动态代理 + cglib 代理）都是 runtime，AspectJ 则是更前置的语言特性。Spring 交付一个专门的库`spring-aspects.jar`，来提供以上功能。

通常编译期的织入，由一个特定的 compiler 来实现。可以由 [ant tasks][10] 来实现，基于 ajc。对性能的影响。

load-time 的织入则依赖于 LTW 机制。对性能的影响比 pure java aop 小。

## 使用 AspectJ 来进行领域对象的依赖注入（Dependency Injection）

所谓的领域对象，指的是 new 出来的、orm 框架创建出来的-带有 id 的对象，符合 ddd 里对 domain entity 的定义。

但我们可以使用 AspectJ，让被 new 出来的对象，也被 config。在 Spring 里，有一类类型如果被标记为`@Configurable`的，Spring 就会改写它的行为，使他隐式地成为一个 bean。这种支持是用在“容器控制之外的对象”上的，实际上建立了一种 “AspectJ 控制的对象”。

AspectJ在类加载时，将AnnotationBeanConfigurerAspect切面将织入到（weaving）标注有@Configurable注解的类中。

AnnotationBeanConfigurerAspect将这些类和Spring IoC容器进行了关联，AnnotationBeanConfigurerAspect本身实现了BeanFactoryAware的接口。 

实际上，大量的单元测试的 mock 对象，如果这种注入不生效，手动地注入 stub 和 skeleton 也是可以生效的。

AnnotationBeanConfigurerAspect 是一个单例切面，每一个类加载器拥有一个单例。

 - 如果在一个类加载器里定义了多个 Spring Context，要考虑清楚在哪个 Context 里配置 @EnableSpringConfigured bean，并放置 spring-aspects.jar。
 - 如果一个父的 spring context 和多个子 spring context （特别是多个 servlet 容器场景下）共用一些基础 service，应该在父 context 里激活 @EnableSpringConfigured 配置，在它的类路径（WEB-INF/）里放置 spring-aspects.jar。

一个例子：

 - 需要准备的 jar：
  - spring-core，spring-beans，spring-context，spring-instrument，spring-aspects，aspectjweaver。实际执行的的 LTW 是 spring-context 的`InstrumentationLoadTimeWeaver`
  - 在`@Configuration`上加上`@EnableLoadTimeWeaving`和`@EnableSpringConfigured`
  - 运行前（有可能要涉及改动**launch script**）加上-javaagent:/path/to/spring-instrument.jar这个 jvm 参数（如：-javaagent:/Users/magicliang/.m2/repository/org/springframework/spring-instrument/5.2.5.RELEASE/spring-instrument-5.2.5.RELEASE.jar）；理论上还可以加上 aspectjweaver.jar 的路径（例如：-Xset:weaveJavaxPackages=true -javaagent:/Users/magicliang/.m2/repository/org/aspectj/aspectjweaver/1.9.5/aspectjweaver-1.9.5.jar，-Xset 这段可以去掉），但实际上没有尝试成功 work 过。
  - 要让 AnnotationBeanConfigurerAspect 被织入到特定 bean 里面，强行使特定的对象和 Spring 容器被关联起来。

待确定用途的功能：

使用自定义的 aspect + 工厂方法 bean：

```xml
<bean id="profiler" class="com.xyz.profiler.Profiler"
        factory-method="aspectOf"> 

    <property name="profilingStrategy" ref="jamonProfilingStrategy"/>
</bean>
```

## 上面的例子不成功，这个例子会成功

参考[《spring-boot-aspectj》][11]

基础的配置：

resources/org/aspectj/aop.xml
```
<!DOCTYPE aspectj PUBLIC "-//AspectJ//DTD//EN" "https://www.eclipse.org/aspectj/dtd/aspectj.dtd">
<!-- 这个文件只能放在类路径下的 META-INF 或者  org/aspectj 文件夹里-->
<!-- 放在 org/aspectj 文件夹里更好，因为 https://github.com/dsyer/spring-boot-aspectj -->
<aspectj>
    <weaver options="-verbose -showWeaveInfo">
        <!-- only weave classes in our application-specific packages -->
        <!-- .. 代表子包 -->
        <!-- 这里可以注释掉，aspect 也会生效 -->
<!--                <include within="com.magicliang..*"/>-->
        <!-- 绝大多数情况下，不需要打开这个注解，我们不需要 advised spring boot 自己的模块 -->
        <!--        <include within="org.springframework.boot..*"/>-->
    </weaver>
    <aspects>
        <!-- 这里不能注释，否则无法让切面生效 -->
        <aspect name="com.magicliang.experiments.aspect.ProfilingAspect"/>
    </aspects>
</aspectj>
```

```java
/**
 * project name: spring-experiments
 * <p>
 * description: 被织入的类
 *
 * 使用 javaagent 要改启动脚本。
 *
 * 要给 jvm 加参数，而不是 application 加参数（application 的 main class 本身也是 jvm 的一个参数）：
 * $HOME
 * -javaagent:/Users/magicliang/.m2/repository/org/springframework/spring-instrument/5.2.5.RELEASE/spring-instrument-5.2.5.RELEASE.jar
 *
 * 不要使用这个参数，没用：
 * -Xset:weaveJavaxPackages=true -javaagent:/Users/magicliang/.m2/repository/org/aspectj/aspectjweaver/1.9.5/aspectjweaver-1.9.5.jar
 *
 * @author magicliang
 * <p>
 * date: 2020-04-18 17:43
 */
@Data
// 这个注解不能放在 spring-managed bean 上，不然会导致对象被初始化两次
// 这个注解什么作用都不起，它会指示 AnnotationBeanConfigurerAspect 在 construction 前后把依赖注入进这个 bean。注解和切面会联系在一起
// preConstruction 一用上，就会导致注入在 construction 之前。value = "user"，以为着要寻找一个名为 user 的 bean definition
// @Configurable(autowire = Autowire.BY_NAME, dependencyCheck = true)
@Configurable
@Slf4j
public class User {

    @Autowired
    private Dog dog;

    public void output() {
        foo();
    }

    public void foo() {
        log.info("doggy is:" + dog.toString());
    }

    private String name;
    private int age;
}

@Data
public class Dog {

    private int id;
    private String name;
}

/**
 * project name: spring-experiments
 * <p>
 * description:
 *
 * @author magicliang
 * <p>
 * date: 2020-04-18 23:28
 */
@Slf4j
// 这个注解可有可无
// @ConfigurationProperties("interceptor")
@Aspect
public class ProfilingAspect {

    @Around("methodsToBeProfiled()")
    public Object profile(ProceedingJoinPoint pjp) throws Throwable {
        StopWatch sw = new StopWatch(getClass().getSimpleName());
        try {
            sw.start(pjp.getSignature().getName());
            return pjp.proceed();
        } finally {
            sw.stop();
            log.info("time:" + sw.prettyPrint());
        }
    }

    @Pointcut("execution(public * com.magicliang..*.*(..))")
    public void methodsToBeProfiled() {
    }
}

@RestController
@RequestMapping("/res/v1")
@Slf4j
// 只有打开这个注解， @Configurable 注解才会生效
@EnableSpringConfigured
@SpringBootApplication
public class AspectjLoadTimeWeaverApplication {

    public static void main(String[] args) {
        SpringApplication.run(AspectjLoadTimeWeaverApplication.class, args);
    }

    @GetMapping("/user")
    public User getUser() {
        User user = new User();
        user.output();
        return user;
    }

    // 没什么卵用的 ConditionalOnClass
    // @ConditionalOnClass(AnnotationBeanConfigurerAspect.class)
    @Bean
    Dog dog() {
        Dog d = new Dog();
        d.setId(1);
        d.setName("dog");
        return d;
    }

    // 这个 bean 方法有的项目建议有，但其实没有也无所谓
//    @Bean
//    public ProfilingAspect interceptor() {
//        // This will barf at runtime if the weaver isn't working (probably a
//        // good thing)
//        return Aspects.aspectOf(ProfilingAspect.class);
//    }

}
```

启动的时候加上这个 vm args：-javaagent:${HOME}/.m2/repository/org/springframework/spring-instrument/5.2.5.RELEASE/spring-instrument-5.2.5.RELEASE.jar

只要有这个 javaagent，@Configurable + @EnableSpringConfigured 的自动注入就会生效 - 这个注解强依赖于这个 jave agent。

而如果有了 aop.xml 的 aspect，怎样的 public 方法都可以被增强。

Spring Boot 提供的 @EnableLoadTimeWeaving 和 spring-instrument.jar [理论上应该一起生效][12]，但不知道怎样搭配才能生效还不可知。

## compile time weaving

compile time weaving 需要给 maven 增加以下配置：

```xml
<build>
        <pluginManagement>
            <plugins>
                <plugin>
                    <groupId>org.springframework.boot</groupId>
                    <artifactId>spring-boot-maven-plugin</artifactId>
                    <dependencies>
                    <!-- thin-jar 是相对于 fatjar 而言的，比较难用 -->
<!--                        <dependency>-->
<!--                            <groupId>org.springframework.boot.experimental</groupId>-->
<!--                            <artifactId>spring-boot-thin-layout</artifactId>-->
<!--                            <version>${thin-jar.version}</version>-->
<!--                        </dependency>-->
                        <dependency>
                            <groupId>org.aspectj</groupId>
                            <artifactId>aspectjweaver</artifactId>
                            <version>${aspectj.version}</version>
                        </dependency>
                    </dependencies>
                </plugin>
            </plugins>
        </pluginManagement>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>

            <!-- 使用 delombok 插件来使生成的代码无 lombok，让 aspectjc 的编译无寻找不到符号问题 -->
            <plugin>
                <groupId>org.projectlombok</groupId>
                <artifactId>lombok-maven-plugin</artifactId>
                <version>1.16.16.0</version>
                <executions>
                    <execution>
                        <phase>generate-sources</phase>
                        <goals>
                            <goal>delombok</goal>
                        </goals>
                    </execution>
                </executions>
                <configuration>
                    <addOutputDirectory>false</addOutputDirectory>
                    <sourceDirectory>src/main/java</sourceDirectory>
                </configuration>
            </plugin>

            <plugin>
                <groupId>org.codehaus.mojo</groupId>
                <artifactId>aspectj-maven-plugin</artifactId>
                <version>1.10</version>
                <configuration>
                    <source>${java.version}</source>
                    <target>${java.version}</target>
                    <proc>none</proc>
                    <complianceLevel>${java.version}</complianceLevel>
                    <showWeaveInfo>true</showWeaveInfo>
                    <!-- 另一种解法 https://stackoverflow.com/questions/41910007/lombok-and-aspectj -->
                </configuration>
                <executions>
                    <execution>
                        <goals>
                            <goal>compile</goal>
                        </goals>
                    </execution>
                </executions>
                <dependencies>
                    <dependency>
                        <groupId>org.aspectj</groupId>
                        <artifactId>aspectjtools</artifactId>
                        <version>${aspectj.version}</version>
                    </dependency>
                </dependencies>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-deploy-plugin</artifactId>
                <configuration>
                    <skip>true</skip>
                </configuration>
            </plugin>
        </plugins>
    </build>
    
    <pluginRepositories>
        <pluginRepository>
            <id>spring-snapshots</id>
            <name>Spring Snapshots</name>
            <url>https://repo.spring.io/snapshot</url>
            <snapshots>
                <enabled>true</enabled>
            </snapshots>
        </pluginRepository>
        <pluginRepository>
            <id>spring-milestones</id>
            <name>Spring Milestones</name>
            <url>https://repo.spring.io/milestone</url>
            <snapshots>
                <enabled>false</enabled>
            </snapshots>
        </pluginRepository>
    </pluginRepositories>
```

然后不用 javaagent 就能启动增强了。

但是 @Configurable 不生效，要生效，还是要加上 javaagent：

```bash
java -javaagent:$HOME/.m2/repository/org/aspectj/aspectjweaver/1.8.13/aspectjweaver-1.8.13.jar -jar target/*.jar
```

被编译增强的类，debug 起来非常困难，因为增加了很多代码。
还是普通的 spring aop 就足够了。

## Spring 允许每个类加载器有细颗粒的 LTW

待研究这样做的用处是什么

# Spring 的 AOP API

## 切点相关 API

切点负责让 advices 指向特定的类和方法。

Spring 用切点 API，使得切点成为一个框架特性，而不是一个语言特性-语言特性需要编译器支持。

但是，大多数情况下，我们应该**只使用一个切点表达式**就足够了，不要直接使用切点 API。

```java
public interface Pointcut {
    //  restrict the pointcut to a given set of target classes
    ClassFilter getClassFilter();

    MethodMatcher getMethodMatcher();
}
```

切点的 api 还可以分为两个部分（用于 union 其他 method matcher）：

```java
public interface ClassFilter {

    boolean matches(Class clazz);
}
```

ClassFilter 用于限制一个目标类的切点。

而 MethodMatcher 更重要：

```java
public interface MethodMatcher {

    boolean matches(Method m, Class targetClass);

    boolean isRuntime();

    boolean matches(Method m, Class targetClass, Object[] args);
}
```

双参数的 matches(Method, Class) 方法可以确认一个目标类上的特定方法是否符合切点要求。这个求值可以在 AOP proxy 被创建时发生，而不是每一次方法调用时发生。它返回 true，则 isRuntime 返回 true，然后三参数的 matches 每次方法执行会被调用。

大多数 MethodMatcher 被实现为静态的，isRuntime 返回 false，则 三参数的 matches 永不会被执行。这是被 Spring 鼓励的，这样 Spring 可以在 AOP proxy 被创建的时候，缓存 pointcut evaluation 的结果。

除此之外，并集和交集的 API 可以参考`org.springframework.aop.support.Pointcuts`和`ComposablePointcut`。

大多数情况下，使用一个静态切点（即只关注 target class 上的方法特征，而不关注真正的运行时 arguments）就最好了

### 一些有用的切点实现

使用切点作为 bean，然后关联 bean 和 advice。

#### JdkRegexpMethodPointcut

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"    
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"       
    xsi:schemaLocation="http://www.springframework.org/schema/beans 
    http://www.springframework.org/schema/beans/spring-beans-2.0.xsd">
 
  <bean id="person" class="Person"/>
  <bean id="loggerPerson" class="LoggerPerson"/>
  <bean id="pointcut" class="org.springframework.aop.support.JdkRegexpMethodPointcut">
    <property name="patterns">
      <list>
        <value>.*ay.*</value>
        <value>.*ie</value>
      </list>
    </property>
  </bean>
 
 <!-- DefaultPointcutAdvisor 就是典型的 advice api + pointcut api -->
  <bean id="advisor" class="org.springframework.aop.support.DefaultPointcutAdvisor">
    <property name="pointcut" ref="pointcut"/>
    <property name="advice" ref="loggerPerson"/>
  </bean>
 
  <bean id="ProxyFactoryBean" class="org.springframework.aop.framework.ProxyFactoryBean">
    <property name="target">
      <ref bean="person"/>
    </property>
    <property name="interceptorNames">
      <list>
        <value>advisor</value>
      </list>
    </property>
  </bean>
</beans>
```

#### RegexpMethodPointcutAdvisor

```xml
<bean id="settersAndAbsquatulateAdvisor"
        class="org.springframework.aop.support.RegexpMethodPointcutAdvisor">
    <property name="advice">
        <ref bean="beanNameOfAopAllianceInterceptor"/>
    </property>
    <property name="patterns">
        <list>
            <value>.*set.*</value>
            <value>.*absquatulate</value>
        </list>
    </property>
</bean>
```

#### ControlFlowPointcut

[Control Flow Pointcut][13]

```java
package roseindia.net.coltrolFlowpointcut;

public class SimpleClass {
    public void sayHi() {
        System.out.println("Hello Friend");
    }
}

package roseindia.net.coltrolFlowpointcut;

import java.lang.reflect.Method;

import org.aopalliance.intercept.MethodInterceptor;
import org.springframework.aop.MethodBeforeAdvice;

public class TestAdvice implements MethodBeforeAdvice {

    @Override
    public void before(Method method, Object[] boObjects, Object object)
            throws Throwable {
        // TODO Auto-generated method stub
        System.out.println("Calling before " + method);
    }

}

package roseindia.net.coltrolFlowpointcut;

import org.aopalliance.aop.Advice;
import org.springframework.aop.Advisor;
import org.springframework.aop.ClassFilter;
import org.springframework.aop.MethodMatcher;
import org.springframework.aop.Pointcut;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.aop.support.ControlFlowPointcut;
import org.springframework.aop.support.DefaultPointcutAdvisor;

public class TestControlFlow {
    public void test() {
        SimpleClass target = new SimpleClass();
        Pointcut pointcut = new ControlFlowPointcut(TestControlFlow.class,
                "controlFlowTest");
        Advice advice = new TestAdvice();
        ProxyFactory proxyFactory = new ProxyFactory();

        Advisor advisor = new DefaultPointcutAdvisor(pointcut, advice);
        proxyFactory.addAdvisor(advisor);
        proxyFactory.setTarget(target);
        SimpleClass simpleProxy = (SimpleClass) proxyFactory.getProxy();
        System.out.println("Calling Normally");
        simpleProxy.sayHi();
        System.out.println("Calling in ControlFlow");
        controlFlowTest(simpleProxy);
    }

    public void controlFlowTest(SimpleClass simpleClass) {
        simpleClass.sayHi();
    }

}

package roseindia.net.coltrolFlowpointcut;

public class MainClaz {
    public static void main(String[] args) {
        TestControlFlow testControlFlow = new TestControlFlow();
        testControlFlow.test();
    }
}
```

#### 通用的静态切点父类

```java
class TestStaticPointcut extends StaticMethodMatcherPointcut {

    public boolean matches(Method m, Class targetClass) {
        // return true if custom criteria match
    }
}
```

## advice 相关 API

Spring 的 advice 主要分为 per-class 和 per-instance 两类。 per-class 最常用，比如 transaction advisor； per-instance 通常用来作为 introduction 支持混型的基本技术，它会给 proxied object 增加状态。

尽量使用 Alliance-compliant AOP  advice 的拦截器，这样可以保证拦截器可以被其他 AOP 框架使用（如 google guice）。

interceptor 自己会产生一个 interceptor chain，这个 chain 是会被破坏的。

各种 advice、advisor 可以在一套 proxy 配置里生效。

### Interception Around Advice

最常用的拦截器，能够完全控制方法的执行。在方法前后，完全环绕：

```java
public interface MethodInterceptor extends Interceptor {

    Object invoke(MethodInvocation invocation) throws Throwable;
}
public class DebugInterceptor implements MethodInterceptor {

    public Object invoke(MethodInvocation invocation) throws Throwable {
        System.out.println("Before: invocation=[" + invocation + "]");
        Object rval = invocation.proceed();
        System.out.println("Invocation returned");
        return rval;
    }
}
```

### Before Advice

只在方法前执行，所以不需要`MethodInvocation`，只要能够引用到 Method 即可：
```java
public interface MethodBeforeAdvice extends BeforeAdvice {

    void before(Method m, Object[] args, Object target) throws Throwable;
}

public class CountingBeforeAdvice implements MethodBeforeAdvice {

    private int count;

    public void before(Method m, Object[] args, Object target) throws Throwable {
        ++count;
    }

    public int getCount() {
        return count;
    }
}
```

它如果挂了，方法执行就会挂掉。而且会抛出一个异常给 client 调用端-如果异常 match client 的异常，可以抛原始异常给 client，否则会抛出一个包装器。

这个 advice 可以配合切点使用。

### Throws Advice

这是一个 tag interface，所以本身不包含任何的实际方法。但 Spring 又支持 typed advice，所以可以自由组织各种 advice 的实现方法。

```java
// 原始的 tag interface
public interface ThrowsAdvice extends AfterAdvice {

}
// 推荐的模式
afterThrowing([Method, args, target], subclassOfThrowable)

// 现实中的 advice
public class RemoteThrowsAdvice implements ThrowsAdvice {

    public void afterThrowing(RemoteException ex) throws Throwable {
        // Do something with remote exception
    }
}

public class ServletThrowsAdviceWithArguments implements ThrowsAdvice {

    public void afterThrowing(Method m, Object[] args, Object target, ServletException ex) {
        // Do something with all arguments
    }
}

public static class CombinedThrowsAdvice implements ThrowsAdvice {

    public void afterThrowing(RemoteException ex) throws Throwable {
        // Do something with remote exception
    }

    public void afterThrowing(Method m, Object[] args, Object target, ServletException ex) {
        // Do something with all arguments
    }
}
```

这个 advice 可以配合切点使用。

### After Returning Advice

可以获取返回参数和抛出异常：

```java
public interface AfterReturningAdvice extends Advice {

    void afterReturning(Object returnValue, Method m, Object[] args, Object target)
            throws Throwable;
}
```

这个 advice 可以配合切点使用。

### Introduction Advice

```java
public interface IntroductionInterceptor extends MethodInterceptor, DynamicIntroductionAdvice {}

public class LockMixin extends DelegatingIntroductionInterceptor implements Lockable {

    private boolean locked;

    public void lock() {
        this.locked = true;
    }

    public void unlock() {
        this.locked = false;
    }

    public boolean locked() {
        return this.locked;
    }

    public Object invoke(MethodInvocation invocation) throws Throwable {
        if (locked() && invocation.getMethod().getName().indexOf("set") == 0) {
            throw new LockedException();
        }
        return super.invoke(invocation);
    }
}

public class LockMixinAdvisor extends DefaultIntroductionAdvisor {

    public LockMixinAdvisor() {
        super(new LockMixin(), Lockable.class);
    }
}

// 接下来可以用 xml bean、 Advised.addAdvisor() 或者 auto proxy creators 来让这个 advisor 生效。
```

这个 advice 不可以配合切点使用。

## ProxyFactoryBean

一个 bean 引用一个 ProxyFactoryBean，其实不是引用它的 instance，而是在引用它的 getObject() 产生的对象。ProxyFactoryBean 有一个优点，因为由他搞出来的 advices 和 pointcuts 本身都是 IoC 容器管理的 bean。

几个基础属性：

 - proxyTargetClass: true，强制使用 CGLIB 代理。proxy-based vs interface-based（jdk-based proxy）。如果 interface-based 不可能正确生成，即使是这个值是 false，也会强制使用 CGLIB 代理。principle of least surprise。
 - optimize：可以对 CGLIB 代理施以激进优化。
 - frozen：是否允许变动配置（如增加 advice）。
 - exposeProxy：是否把代理放在线程里，允许 AopContext.currentProxy() 生效。
 - proxyInterfaces：接口列表。如果什么都不提供，使用 CGLIB 代理，提供了，有可能使用 jdk 动态代理。
 - interceptorNames：拦截器、advice 列表。名字的顺序实际上决定了 interceptor chain 的生效顺序。这个列表本身不是 name-ref 的模式，是为了允许 prototype 模式生效。
 - singleton：是否单例，大部分的 FactoryBean 的实现的这个值都是 true。

如果有可能，Spring 会顺着接口列表生成 JdkDynamicProxy；否则，会退而求其次生成 cglib proxy。

```xml
<bean id="personTarget" class="com.mycompany.PersonImpl">
    <property name="name" value="Tony"/>
    <property name="age" value="51"/>
</bean>

<bean id="myAdvisor" class="com.mycompany.MyAdvisor">
    <property name="someProperty" value="Custom string property value"/>
</bean>

<bean id="debugInterceptor" class="org.springframework.aop.interceptor.DebugInterceptor">
</bean>

<bean id="person"
    class="org.springframework.aop.framework.ProxyFactoryBean">
    <property name="proxyInterfaces" value="com.mycompany.Person"/>

    <property name="target" ref="personTarget"/>
    <property name="interceptorNames">
        <list>
            <!-- You might be wondering why the list does not hold bean references. The reason for this is that, if the singleton property of the ProxyFactoryBean is set to false, it must be able to return independent proxy instances. If any of the advisors is itself a prototype, an independent instance would need to be returned, so it is necessary to be able to obtain an instance of the prototype from the factory. Holding a reference is not sufficient.
 -->
            <value>myAdvisor</value>
            <value>debugInterceptor</value>
        </list>
    </property>
</bean>
```

```java
Person person = (Person) factory.getBean("person");
```

我们也可以使用一个内部类声明，使全局的 bean 能够藏住一个不可被引用的被代理的 target，而且也无法从全局的其他地方被引用。

```xml
<bean id="myAdvisor" class="com.mycompany.MyAdvisor">
    <property name="someProperty" value="Custom string property value"/>
</bean>

<bean id="debugInterceptor" class="org.springframework.aop.interceptor.DebugInterceptor"/>

<bean id="person" class="org.springframework.aop.framework.ProxyFactoryBean">
    <property name="proxyInterfaces" value="com.mycompany.Person"/>
    <!-- Use inner bean, not local reference to target -->
    <property name="target">
        <bean class="com.mycompany.PersonImpl">
            <property name="name" value="Tony"/>
            <property name="age" value="51"/>
        </bean>
    </property>
    <property name="interceptorNames">
        <list>
            <value>myAdvisor</value>
            <value>debugInterceptor</value>
        </list>
    </property>
</bean>
```

interceptorNames 支持通配符模式：

```xml
<bean id="proxy" class="org.springframework.aop.framework.ProxyFactoryBean">
    <property name="target" ref="service"/>
    <property name="interceptorNames">
        <list>
            <value>global*</value>
        </list>
    </property>
</bean>

<bean id="global_debug" class="org.springframework.aop.interceptor.DebugInterceptor"/>
<bean id="global_performance" class="org.springframework.aop.interceptor.PerformanceMonitorInterceptor"/>
```

```xml
<!-- 父代理工厂 -->
<bean id="txProxyTemplate" abstract="true"
        class="org.springframework.transaction.interceptor.TransactionProxyFactoryBean">
    <property name="transactionManager" ref="transactionManager"/>
    <property name="transactionAttributes">
        <props>
            <prop key="*">PROPAGATION_REQUIRED</prop>
        </props>
    </property>
</bean>
<!-- 子代理工厂 -->
<bean id="myService" parent="txProxyTemplate">
    <property name="target">
        <bean class="org.springframework.samples.MyServiceImpl">
        </bean>
    </property>
</bean>
<!-- 子代理工厂覆盖父配置 -->
<bean id="mySpecialService" parent="txProxyTemplate">
    <property name="target">
        <bean class="org.springframework.samples.MySpecialServiceImpl">
        </bean>
    </property>
    <property name="transactionAttributes">
        <props>
            <prop key="get*">PROPAGATION_REQUIRED,readOnly</prop>
            <prop key="find*">PROPAGATION_REQUIRED,readOnly</prop>
            <prop key="load*">PROPAGATION_REQUIRED,readOnly</prop>
            <prop key="store*">PROPAGATION_REQUIRED</prop>
        </props>
    </property>
</bean>
```

## 程序化地创建 AOP 代理的方法

使用 ProxyFactory（注意，不是 xml 使用的`ProxyFactoryBean`）；

```java
ProxyFactory factory = new ProxyFactory(myBusinessInterfaceImpl);
factory.addAdvice(myMethodInterceptor);
factory.addAdvisor(myAdvisor);
MyBusinessInterface tb = (MyBusinessInterface) factory.getProxy();
```

所有的 proxy 都可以转化为`org.springframework.aop.framework.Advise`接口，其包含这些方法：

可以看出来 advice 和 advisor 的区别还是很大的：

```xml
Advisor[] getAdvisors();

void addAdvice(Advice advice) throws AopConfigException;

void addAdvice(int pos, Advice advice) throws AopConfigException;

void addAdvisor(Advisor advisor) throws AopConfigException;

void addAdvisor(int pos, Advisor advisor) throws AopConfigException;

int indexOf(Advisor advisor);

boolean removeAdvisor(Advisor advisor) throws AopConfigException;

void removeAdvisor(int index) throws AopConfigException;

boolean replaceAdvisor(Advisor a, Advisor b) throws AopConfigException;

boolean isFrozen();
```

下面是一个例子，可以把 proxy 的 advisor 都取出来：

```java
Advised advised = (Advised) myObject;
Advisor[] advisors = advised.getAdvisors();
int oldAdvisorCount = advisors.length;
System.out.println(oldAdvisorCount + " advisors");

// Add an advice like an interceptor without a pointcut
// Will match all proxied methods
// Can use for interceptors, before, after returning or throws advice
advised.addAdvice(new DebugInterceptor());

// Add selective advice using a pointcut
advised.addAdvisor(new DefaultPointcutAdvisor(mySpecialPointcut, myAdvice));

assertEquals("Added two advisors", oldAdvisorCount + 2, advised.getAdvisors().length);
```

注意，以上操作还是会受 frozen 的影响。

## 使用自动代理设施

这种自动处理机制，很多系统都喜欢用。
它的本质是对 bean definition 进行操作，使用 proxy 代理特定模式的 bean definition（targets eligible），依赖于 bean 后处理器的基础设施。

### BeanNameAutoProxyCreator

这是最常见的做法：

```xml
<bean class="org.springframework.aop.framework.autoproxy.BeanNameAutoProxyCreator">
    <property name="beanNames" value="jdk*,onlyJdk"/>
    <property name="interceptorNames">
        <list>
            <value>myInterceptor</value>
        </list>
    </property>
</bean>
```

### DefaultAdvisorAutoProxyCreator

这个东西会自动地把 advisor 和 target 关联起来，所有需要做的事情只是：

 - 声明一系列 advisor。
 - 声明一个 DefaultAdvisorAutoProxyCreator。

从这里看出来 advisor 和 advice、interceptor 的显著区别，advisor 天然就有 pointcut，可以自动被识别。

```java
@Configuration
public class AppConfig {
    // 要创建代理的目标 Bean
    @Bean
    public UserService userService(){
        return new UserServiceImpl();
    }
    // 创建Advice
    @Bean
    public Advice myMethodInterceptor(){
        return new MyMethodInterceptor();
    }
    // 使用 Advice 创建Advisor
    @Bean
    public NameMatchMethodPointcutAdvisor nameMatchMethodPointcutAdvisor(){
        NameMatchMethodPointcutAdvisor nameMatchMethodPointcutAdvisor=new NameMatchMethodPointcutAdvisor();
        nameMatchMethodPointcutAdvisor.setMappedName("pri*");
        nameMatchMethodPointcutAdvisor.setAdvice(myMethodInterceptor());
        return nameMatchMethodPointcutAdvisor;
    }
    @Bean
    public DefaultAdvisorAutoProxyCreator defaultAdvisorAutoProxyCreator() {
        return new DefaultAdvisorAutoProxyCreator();
    }
}
```

## TargetSource API

###  可热替换（hot-swappable）的 target source

Spring 提供一个 API，可以让代理暴露自己的目标源：

```xml
<bean id="initialTarget" class="mycompany.OldTarget"/>

<bean id="swapper" class="org.springframework.aop.target.HotSwappableTargetSource">
    <constructor-arg ref="initialTarget"/>
</bean>

<bean id="swappable" class="org.springframework.aop.framework.ProxyFactoryBean">
    <property name="targetSource" ref="swapper"/>
</bean>
```

```java
// 甚至这个接口还可以提供 swap target 的能力
HotSwappableTargetSource swapper = (HotSwappableTargetSource) beanFactory.getBean("swapper");
Object oldTarget = swapper.swap(newTarget);
```

### 池化 target source

Spring 可以和各种 pooling api 配合使用，如以下的例子：

```xml
<bean id="businessObjectTarget" class="com.mycompany.MyBusinessObject"
        scope="prototype">
    ... properties omitted
</bean>

<!-- 依赖于 common-pools 2.3：org.apache.commons.pool2.ObjectPool -->
<bean id="poolTargetSource" class="org.springframework.aop.target.CommonsPool2TargetSource">
    <property name="targetBeanName" value="businessObjectTarget"/>
    <property name="maxSize" value="25"/>
</bean>

<bean id="businessObject" class="org.springframework.aop.framework.ProxyFactoryBean">
    <property name="targetSource" ref="poolTargetSource"/>
    <property name="interceptorNames" value="myInterceptor"/>
</bean>
```

相关的关键类是：org.springframework.aop.target.AbstractPoolingTargetSource。

如果做了以下操作，可以把目标 bean 内部的 pool 配置读出来（比如对象池大小）：
```xml
<bean id="poolConfigAdvisor" class="org.springframework.beans.factory.config.MethodInvokingFactoryBean">
    <property name="targetObject" ref="poolTargetSource"/>
    <property name="targetMethod" value="getPoolingConfigMixin"/>
</bean>
```

```java
PoolingConfig conf = (PoolingConfig) beanFactory.getBean("businessObject");
System.out.println("Max pool size is " + conf.getMaxSize());
```

能够被池化复用的对象，应该是无状态的对象，比如 EJB 对象，所以这个功能到底是不是真的有用，还要看业务场景。Spring 文档说无状态对象是线程安全的，只是把这个类型当做 transaction service 而已-如此说，prototype 和 singleton 又有什么区别。

### 原型化 target source

还有原型化的 target source api。原型化的 api 一般都很不好用，因为它意味着每次方法调用都会产生新对象。产生新对象的成本并不高，绑上（wiring）依赖的成本会很高。

```xml
<bean id="prototypeTargetSource" class="org.springframework.aop.target.PrototypeTargetSource">
    <!-- prototype 的 bean-->
    <property name="targetBeanName" ref="businessObjectTarget"/>
</bean>
```

相当于 bean 还要被套在 TargetSource 里，所以 TargetSource 本质上只是一种 proxy 而已。

### ThreadLocal target source

```xml
<bean id="threadlocalTargetSource" class="org.springframework.aop.target.ThreadLocalTargetSource">
    <property name="targetBeanName" value="businessObjectTarget"/>
</bean>
```

ThreadLocal 在多线程和多类加载器的场景下，会导致内存泄漏。

### 定义新的 Advice 类型

Spring 的 AOP 框架本身是支持类型扩展的，自定义的扩展可以通过一套 SPI 机制进行扩展。见[`org.springframework.aop.framework.adapter`][14]文档。

**几个悬而未决的问题，怎样使用 aop 是最合理，最简单的 。各种机制的使用场景是什么？那么多复杂的内部机制来实现 advice，都不如直接用原生的 @Aspect 注解类的 advice 注解类来读写各种 joinpoint 甚至原型方法更简单。**

```java
```
```java
```
```java
```
```java
```
```java
```
```java
```
```java
```
```java
```
```java
```
```java
```
<!--  -->



MethodInvocation

joinpoit - Spring 自己的方法闭包执行点

到底有多少个 interceptor、advisor、advice？全局的状态要怎么维护？prototype、request scope、threadlocal？

Spring 为什么要提供那么多的 mixin？

# 一般的继承关系

spring-aop 模块的 jar 里包含 org.aopalliance.intercept package。

代表单一方法的一等公民类型 Advice/Interceptor。

Advice（marker interface） -> Interceptor（marker interface） -> MethodInterceptor（带有一个很重要的`invoke(MethodInvocation invocation)`方法） -> XXXInterceptor（比如 TransactionInterceptor）

## 解析 spring aop 标签的流程

我们常见的 xml 标签如下：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:context="http://www.springframework.org/schema/context"
        xmlns:aop="http://www.springframework.org/schema/aop"
        xmlns:tx="http://www.springframework.org/schema/tx"
        xsi:schemaLocation="http://www.springframework.org/schema/beans 
                http://www.springframework.org/schema/beans/spring-beans-2.5.xsd
                http://www.springframework.org/schema/context 
                http://www.springframework.org/schema/context/spring-context-2.5.xsd
                http://www.springframework.org/schema/tx
                http://www.springframework.org/schema/tx/spring-tx-2.5.xsd
                http://www.springframework.org/schema/aop
                http://www.springframework.org/schema/aop/spring-aop-2.5.xsd">

    <context:component-scan base-package="com.xh.spring.aop">
        <context:include-filter type="annotation" 
                 expression="org.aspectj.lang.annotation.Aspect"/>
    </context:component-scan>
    
    <!-- 强制使用 cglib proxy 的一种方法 -->
    <aop:aspectj-autoproxy proxy-target-class="true"/>
 </beans>
```

在 jar 下存在一个路径可以配置类似 SPI 的加载路径`.m2/repository/org/springframework/spring-aop/5.2.3.RELEASE/spring-aop-5.2.3.RELEASE.jar!/META-INF/spring.handlers`。

其激活的`AopNamespaceHandler` 为：

```java
public class AopNamespaceHandler extends NamespaceHandlerSupport {
    /**
     * Register the {@link BeanDefinitionParser BeanDefinitionParsers} for the
     * '{@code config}', '{@code spring-configured}', '{@code aspectj-autoproxy}'
     * and '{@code scoped-proxy}' tags.
     */
    @Override
    public void init() {
        // In 2.0 XSD as well as in 2.1 XSD.
        registerBeanDefinitionParser("config", new ConfigBeanDefinitionParser());
        registerBeanDefinitionParser("aspectj-autoproxy", new AspectJAutoProxyBeanDefinitionParser());
        registerBeanDefinitionDecorator("scoped-proxy", new ScopedProxyBeanDefinitionDecorator());

        // Only in 2.0 XSD: moved to context namespace as of 2.1
        registerBeanDefinitionParser("spring-configured", new SpringConfiguredBeanDefinitionParser());
    }
}
```

如果我们使用的 aop 配置是：
```xml
<!-- 强制使用 cglib proxy 的一种方法 -->
<aop:config proxy-target-class="true">
    <!-- other beans defined here... -->
</aop:config>
```
则对应的 Parser 是：

```java
```

如果我们使用的 aop 配置是：

```xml
```

则对应的 Parser 是：

```java
```

除此之外，还有其他我们常见的 xml 配置，而且他们对 proxy creator 的影响是相互的、全局的（只要有一个指定 AspectJ，就会导致全局 AspectJ）：

> To be clear, using proxy-target-class="true" on
> <tx:annotation-driven/>, <aop:aspectj-autoproxy/>, or <aop:config/>
> elements forces the use of CGLIB proxies for all three of them.

其中，我们常见的

由 Spring 自己根据上下文，决定生成 还是 ，当然，这个行为实际上是受`proxy-target-class="true`这一属性控制的。引述官方文档如下：

> If the target object to be proxied implements at least one interface
> then a JDK dynamic proxy will be used. All of the interfaces
> implemented by the target type will be proxied. If the target object
> does not implement any interfaces then a CGLIB proxy will be created.
> 如果要代理的目标对象实现至少一个接口，则将使用JDK动态代理。 目标类型实现的所有接口都将被代理。
> 如果目标对象未实现任何接口，则将创建CGLIB代理。

proxy-target-class 的语义，恰好与 jdkDynamicProxy 的 proxy targe interface 的语义对应过来。

我们可以不再显式地引入 cglib 相关的 jar，从 Spring 3.2 开始，cglib 相关的 jar 已经被自动打包进 spring-core.jar 里面了。

# 连接点设计

有了连接点，首先封装了 proxy，其他封装了 target，再次描述了方法的签名，最后封装了参数（这点特别重要，使得我们不需要直接使用 Object[]）。

连接点使用 PCD 的表达式，可以实现 data binding - 指定参数名称和类型。

## JoinPoint

一般的 advice 的参数使用 JoinPoint。

```java
public interface JoinPoint {  
   String toString();         //连接点所在位置的相关信息  
   String toShortString();     //连接点所在位置的简短相关信息  
   String toLongString();     //连接点所在位置的全部相关信息  
   Object getThis();         //返回AOP代理对象，也就是com.sun.proxy.$Proxy18
   Object getTarget();       //返回目标对象，一般我们都需要它或者（也就是定义方法的接口或类，为什么会是接口呢？这主要是在目标对象本身是动态代理的情况下，例如Mapper。所以返回的是定义方法的对象如aoptest.daoimpl.GoodDaoImpl或com.b.base.BaseMapper<T, E, PK>）
   Object[] getArgs();       //返回被通知方法参数列表  
   Signature getSignature();  //返回当前连接点签名  其getName()方法返回方法的FQN，如void aoptest.dao.GoodDao.delete()或com.b.base.BaseMapper.insert(T)(需要注意的是，很多时候我们定义了子类继承父类的时候，我们希望拿到基于子类的FQN，这直接可拿不到，要依赖于AopUtils.getTargetClass(point.getTarget())获取原始代理对象，下面会详细讲解)
   SourceLocation getSourceLocation();//返回连接点方法所在类文件中的位置  
   String getKind();        //连接点类型  
   StaticPart getStaticPart(); //返回连接点静态部分  
  }  
```

## ProceedingJoinPoint

Around Advice 使用 ProceedingJoinPoint。

```java
public interface ProceedingJoinPoint extends JoinPoint {
        // 执行下一个 advice （从侧面看出 advice 是可以嵌套的）或者目标方法
       public Object proceed() throws Throwable;
       // 使用数组参数来执行下一个 advice （从侧面看出 advice 是可以嵌套的）或者目标方法
       public Object proceed(Object[] args) throws Throwable;  
 } 
```
ProceedingJoinPoint 的 proceed 可以被执行 0 次、1 次、无数次。

常见的例子就是缓存 API 在校验了 cache 了以后可以执行底层方法，也可以不执行底层方法。

如果按顺序绑定 ProceedingJoinPoint 的参数到 advice 方法上，可以先处理那个参数，再把参数回传去再 proceed 来代替之前被处理的参数。如下面的例子，find 方法的第一个参数是 accountHolderNamePattern，被处理以后就出现新 pattern 来调用。

```java
@Around("execution(List<Account> find*(..)) && " +
        "com.xyz.myapp.SystemArchitecture.inDataAccessLayer() && " +
        "args(accountHolderNamePattern)")
public Object preProcessQueryPattern(ProceedingJoinPoint pjp,
        String accountHolderNamePattern) throws Throwable {
    String newPattern = preProcess(accountHolderNamePattern);
    return pjp.proceed(new Object[] {newPattern});
}
```

```java
```

参考：

1. [《Introduction to Pointcut Expressions in Spring》][15]
2. [《Spring @Configurable基本用法》][16]


  [1]: https://docs.spring.io/spring/docs/current/spring-framework-reference/core.html#aop-proxying
  [2]: https://docs.spring.io/spring/docs/current/spring-framework-reference/core.html#aop-ataspectj
  [3]: https://stackoverflow.com/questions/11446893/spring-aop-why-do-i-need-aspectjweaver
  [4]: https://www.eclipse.org/aspectj/doc/released/progguide/semantics-pointcuts.html
  [5]: https://docs.spring.io/spring/docs/current/spring-framework-reference/core.html#aop-schema
  [6]: https://docs.spring.io/spring/docs/current/spring-framework-reference/core.html#xsd-schemas-aop
  [7]: https://docs.spring.io/spring/docs/current/spring-framework-reference/core.html#aop-autoproxy
  [8]: https://docs.spring.io/spring/docs/current/spring-framework-reference/core.html#aop-api-advice-types
  [9]: https://docs.spring.io/spring/docs/current/spring-framework-reference/core.html#aop-spring-or-aspectj
  [10]: https://www.eclipse.org/aspectj/doc/released/devguide/antTasks.html
  [11]: https://github.com/dsyer/spring-boot-aspectj
  [12]: https://stackoverflow.com/questions/54749106/aspectj-ltw-weaving-not-working-with-spring-boot
  [13]: https://www.roseindia.net/tutorial/spring/spring3/aop/controlflowpointcut.html
  [14]: https://docs.spring.io/spring-framework/docs/5.2.5.RELEASE/javadoc-api/org/springframework/aop/framework/adapter/package-frame.html
  [15]: https://www.baeldung.com/spring-aop-pointcut-tutorial#3-this-and-target
  [16]: https://plentymore.github.io/2018/12/11/Spring-Configurable%E5%9F%BA%E6%9C%AC%E7%94%A8%E6%B3%95/
