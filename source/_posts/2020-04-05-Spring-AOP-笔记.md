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

Pointcut: A predicate that matches join points. Advice is associated with a pointcut expression and runs at any join point matched by the pointcut (for example, the execution of a method with a certain name). The concept of join points as matched by pointcut expressions is central to AOP, and Spring uses the AspectJ pointcut expression language by default. 切点（英文是点切）实际上是对 Join point 进行判定的谓词。**切点把 Join point 和 Advice 实际上结合起来了**。默认的 切点表达式来自于 AspectJ pointcut expression。

Advisor：Base interface holding AOP advice (action to take at a joinpoint) and a filter determining the applicability of the advice (such as a pointcut). This interface is not for use by Spring users, but to allow for commonality in support for different types of advice.
Spring AOP is based around around advice delivered via method interception, compliant with the AOP Alliance interception API. The Advisor interface allows support for different types of advice, such as before and after advice, which need not be implemented using interception. Advisor 不是给 Spring 用户用的。它包含一个 advice，是 一个 advice 的容器 - 相应地，Aspect 是包含很多 advice 的容器，这是个 Spring 用户用的。

Introductions：Declaring additional methods or fields on behalf of a type. 类似混型（mixin），在不打开原有类型以改变原有类型的内容的前提下（类似 Ruby 的元编程或者 C# 的 partial class），为类型增加新的功能。

Target object: An object being advised by one or more aspects. Also referred to as the “advised object”. Since Spring AOP is implemented by using runtime proxies, this object is always a proxied object. 目标对象、建议对象，即原始对象。

AOP proxy: An object created by the AOP framework in order to implement the aspect contracts (advise method executions and so on). In the Spring Framework, an AOP proxy is a JDK dynamic proxy or a CGLIB proxy. Interceptor、Proxy，aspect contracts 的实现。

Weaving: linking aspects with other application types or objects to create an advised object. This can be done at compile time (using the AspectJ compiler, for example), load time, or at runtime. Spring AOP, like other pure Java AOP frameworks, performs weaving at runtime. 织入，即把方面和 advised object 联系起来的过程。可以在编译时（性能最好）、装载时（容易被忽略）和运行时（所有的 pure java AOP framework 的默认选项）执行。大多数情况下，Spring AOP 已经够用了。

可以看出 Spring 的设计里面是尽可能地在 IOC 的基础上提供强大的`auto-proxying`服务，所有的增强功能，都是在代理里实现的，已解决企业级开发中常见的问题，而不是提供强大而完备的 AOP 实现（尽管它已经很强大了）。

# 到底应该使用哪种代理呢？

Spring 默认使用 Java 动态代理，任何接口实现都可以被代理。但这种代理只能拦截接口方法。最终产生的 object 是 Proxy 的 instance 且 Interface 的 implementation。

当一个对象没有实现一个接口的时候，Spring 会退而求其次，使用 cglib 代理。当然，我们也可以（实际上经常）[强制使用 cglib 代理][1]。这种代理可以拦截一切可以覆写的方法。最终产生的 object 是原类型的 subclass 的 instance。

# Spring 的 AOP 实现基础策略

所有声明、配置，advisor、Interceptor、proxies 可以混合使用，即 Mixing Aspect Types。

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

## 声明 Aspect

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

## 详解 pointcut

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
```

-  bean 特定的 bean 名称/名称模式引用的 

```java
bean(tradeService)
bean(*Service)
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

## 详解 advice

### advice 的类型

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
        // 这里如果限制返回值类型，后果自负
    public void doAccessCheck(Object retVal) {
        // ...
    }

}
```
 - After throwing（不怎么常见，但 Spring MVC 的 Controller Advice 就是这样实现的）。PCD 里是不包含对于 exception 的定位的，只能通过 PCD 里定位方法，然后使用这个 advice。

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
 - around（大部分的 advice 都可以这样用，因为它兼容 before、after（实际上囊括了上面所有的 advice）， 而且管控范围最广）适合申请资源、释放资源、权限管理、日志，它因为是栈封闭的，所以是线程安全地共享状态 - timer 的合理方式。

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

### advice 的优先级

有最高优先级的 advice 在 advice 嵌套的最外层，before 最先执行而 after 最后执行。

可以通过实现 org.springframework.core.Ordered 或者使用 Order 注解给 Aspect - advice 的优先级跟着 aspect 的优先级走。

## 激活 schema-based approach

解析 xml 标签的模式，被 Spring 称为 [schema-based approach][5] 。

这种解决方案的表达能力不如基于注解的表达能力强（**有些切点表达式可以用注解表达，无法用 xml 表达**）。

它基于 [aop schema][6]，需要使用的时候引入一个 schema：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    // 一定要使用这个 xmlns
    xmlns:aop="http://www.springframework.org/schema/aop"
    xsi:schemaLocation="
        http://www.springframework.org/schema/beans https://www.springframework.org/schema/beans/spring-beans.xsd
        http://www.springframework.org/schema/aop https://www.springframework.org/schema/aop/spring-aop.xsd">

    <!-- bean definitions here -->

</beans>
```

advisor 适用于内部的 advice，普通的 advice 应该使用 aspect。


# 一般的继承关系

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

除此之外，还有其他我们常见的 xml 配置，而且他们对 proxy creator 的影响是相互的、全局的：

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

# MethodInvocation

joinpoit - Spring 自己的方法闭包执行点


# 如何在被代理的 bean 里调用 proxy

 1. 要求暴露了代理，如`<aop:aspectj-autoproxy proxy-target-class="true" expose-proxy="true"/>`。
 2. 使用`AopContext`：`((Service) AopContext.currentProxy()).callMethodB();`这里的callMethodB 是一个需要被代理增强的方法。
 

```java
```

参考：

1. [《Introduction to Pointcut Expressions in Spring》][7]


  [1]: https://docs.spring.io/spring/docs/current/spring-framework-reference/core.html#aop-proxying
  [2]: https://docs.spring.io/spring/docs/current/spring-framework-reference/core.html#aop-ataspectj
  [3]: https://stackoverflow.com/questions/11446893/spring-aop-why-do-i-need-aspectjweaver
  [4]: https://www.eclipse.org/aspectj/doc/released/progguide/semantics-pointcuts.html
  [5]: https://docs.spring.io/spring/docs/current/spring-framework-reference/core.html#aop-schema
  [6]: https://docs.spring.io/spring/docs/current/spring-framework-reference/core.html#xsd-schemas-aop
  [7]: https://www.baeldung.com/spring-aop-pointcut-tutorial#3-this-and-target
