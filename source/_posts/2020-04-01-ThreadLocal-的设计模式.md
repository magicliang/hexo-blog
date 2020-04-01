---
title: ThreadLocal 的设计模式
date: 2020-04-01 20:29:29
tags:
- Java
- 设计模式
---
# 基础版本

```java
// 定义基础的 Context 类型
public class ServerContext {
}
// 为这个基础类型装载一个 threadlocal 容器，然后为这个容器准备一个静态工具类
public class Context {
    // 这个容器如果是泛型的（如存储 dapper 的 trace 或者 span），可以考虑用 T 或者用 Object。
    private static final ThreadLocal<Object> SERVER_CONTEXT = new ThreadLocal<Object>();

    public static Object getServerContext() {
        return SERVER_CONTEXT.get();
    }

    public static void setServerContext(Object obj) {
        SERVER_CONTEXT.set(obj);
    }

    public static void removeServerContext() {
        SERVER_CONTEXT.remove();
    }
}

// 一个更大的 context，来汇总各种容器工具类
public class BizContext {

    public static void setCurrentServerContext(final ServerContext span) {
        // 注意这里把 null 拿来 clear，而不是直接 put 的逻辑，类似 spring 的例子
        if (span == null) {
            Context.removeServerContext();
        } else {
            Context.setServerContext(span);
        }
    }
}
```

# 用 map 来取消第一层工具类的方案（map 容易腐化）

```java
public class ContextFactory {

    /**
     * 私有构造器
     */
    protected ContextFactory() {
        // no op
    }

    /**
     * 上下文持有器
     * 全局静态变量，保存真正的交易上下文。因为是静态成员，所以无法引用每个实例特有的类型实参。
     * withInitial 没有被重载过，必须赋值给 ThreadLocal 类型，面向抽象类型编程更好。
     */
    private static final ThreadLocal<Map<String, Object>> CONTEXT_HOLDER = InheritableThreadLocal.withInitial(() -> new ConcurrentHashMap<>(CONTEXT_CACHE_SIZE));

    /**
     * 清理本线程上下文的内容
     */
    public static void clear() {
        CONTEXT_HOLDER.remove();
    }

    /**
     * 获取上下文持有器
     *
     * @return 上下文持有器
     */
    public static ThreadLocal<Map<String, Object>> getContextHolder() {
        return CONTEXT_HOLDER;
    }
}

public class InsTransactionContextFactory extends ContextFactory {

    /**
     * 私有构造器
     */
    private InsTransactionContextFactory() {
        throw new UnsupportedOperationException();
    }

    /**
     * InsTransactionContext key
     */
    private static final String INS_TRANSACTION_CONTEXT_KEY = "InsTransactionContext";

    /**
     * 静态工厂方法，获取交易上下文实例。
     * 正确的使用实践，是在第一次 getInstance 的时候就 initContext - 免得接下来的使用出问题
     * 因为线程封闭和线程隔离，这里无需加锁和 double check
     *
     * @return 交易上下文实例
     */
    @SuppressWarnings("unchecked")
    public static <R, T extends TransactionModel> InsTransactionContext<R, T> getInsTransactionContext() {
        // 1. 获取当前上下文的映射表
        Map<String, Object> realContextHolder = getContextHolder().get();
        if (null == realContextHolder) {
            realContextHolder = new ConcurrentHashMap<>(CONTEXT_CACHE_SIZE);
            getContextHolder().set(realContextHolder);
        }
        InsTransactionContext<R, T> realContext;
        Object mapValue = realContextHolder.get(INS_TRANSACTION_CONTEXT_KEY);
        // instanceof 包含 != null 的检查
        if (mapValue instanceof InsTransactionContext) {
            // 1. 如果持有这个上下文的类型是InsTransactionContext，直接 type casting
            realContext = (InsTransactionContext<R, T>) mapValue;
        } else {
            // 2. 否则使用标准类型覆盖原有 value
            realContext = new InsTransactionContext<>();
            realContextHolder.put(INS_TRANSACTION_CONTEXT_KEY, realContext);
        }
        return realContext;
    }
```

对这个 map 的加强版本

```java
@Override
    public void put(final String key, final String value) {
        if (!useMap) {
            return;
        }
        Map<String, String> map = localMap.get();
        map = map == null ? new HashMap<String, String>(1) : new HashMap<>(map);
        map.put(key, value);
        localMap.set(Collections.unmodifiableMap(map));
    }
```

绑定一个容器到线程上，并重建上一个状态-状态里还带有另一个 previous。

```java
private void bindToThread() {
            // Expose current TransactionStatus, preserving any existing TransactionStatus
            // for restoration after this transaction is complete.
            this.oldTransactionInfo = transactionInfoHolder.get();
            transactionInfoHolder.set(this);
        }

        private void restoreThreadLocalStatus() {
            // Use stack to restore old transaction TransactionInfo.
            // Will be null if none was set.
            transactionInfoHolder.set(this.oldTransactionInfo);
        }
```

# ThreadLocal 变策略模式

```java
// 不要使用 map，要把多个 threadlocal 用具体的类型区隔开来，每个类型配一个 threadlocal

final class InheritableThreadLocalSecurityContextHolderStrategy implements
        SecurityContextHolderStrategy {
    // ~ Static fields/initializers
    // =====================================================================================

    private static final ThreadLocal<SecurityContext> contextHolder = new InheritableThreadLocal<>();

    // ~ Methods
    // ========================================================================================================

    public void clearContext() {
        contextHolder.remove();
    }

    public SecurityContext getContext() {
        SecurityContext ctx = contextHolder.get();

        if (ctx == null) {
            ctx = createEmptyContext();
            contextHolder.set(ctx);
        }

        return ctx;
    }

    public void setContext(SecurityContext context) {
        Assert.notNull(context, "Only non-null SecurityContext instances are permitted");
        contextHolder.set(context);
    }

    public SecurityContext createEmptyContext() {
        return new SecurityContextImpl();
    }
}

public class SecurityContextHolder {
    // ~ Static fields/initializers
    // =====================================================================================

    public static final String MODE_THREADLOCAL = "MODE_THREADLOCAL";
    public static final String MODE_INHERITABLETHREADLOCAL = "MODE_INHERITABLETHREADLOCAL";
    public static final String MODE_GLOBAL = "MODE_GLOBAL";
    public static final String SYSTEM_PROPERTY = "spring.security.strategy";
    private static String strategyName = System.getProperty(SYSTEM_PROPERTY);
    private static SecurityContextHolderStrategy strategy;
    private static int initializeCount = 0;

    static {
        initialize();
    }

    // ~ Methods
    // ========================================================================================================

    /**
     * Explicitly clears the context value from the current thread.
     */
    public static void clearContext() {
        strategy.clearContext();
    }

    /**
     * Obtain the current <code>SecurityContext</code>.
     *
     * @return the security context (never <code>null</code>)
     */
    public static SecurityContext getContext() {
        return strategy.getContext();
    }

    /**
     * Primarily for troubleshooting purposes, this method shows how many times the class
     * has re-initialized its <code>SecurityContextHolderStrategy</code>.
     *
     * @return the count (should be one unless you've called
     * {@link #setStrategyName(String)} to switch to an alternate strategy.
     */
    public static int getInitializeCount() {
        return initializeCount;
    }

    private static void initialize() {
        if (!StringUtils.hasText(strategyName)) {
            // Set default
            strategyName = MODE_THREADLOCAL;
        }

        if (strategyName.equals(MODE_THREADLOCAL)) {
            strategy = new ThreadLocalSecurityContextHolderStrategy();
        }
        else if (strategyName.equals(MODE_INHERITABLETHREADLOCAL)) {
            strategy = new InheritableThreadLocalSecurityContextHolderStrategy();
        }
        else if (strategyName.equals(MODE_GLOBAL)) {
            strategy = new GlobalSecurityContextHolderStrategy();
        }
        else {
            // Try to load a custom strategy
            try {
                Class<?> clazz = Class.forName(strategyName);
                Constructor<?> customStrategy = clazz.getConstructor();
                strategy = (SecurityContextHolderStrategy) customStrategy.newInstance();
            }
            catch (Exception ex) {
                ReflectionUtils.handleReflectionException(ex);
            }
        }

        initializeCount++;
    }

    /**
     * Associates a new <code>SecurityContext</code> with the current thread of execution.
     *
     * @param context the new <code>SecurityContext</code> (may not be <code>null</code>)
     */
    public static void setContext(SecurityContext context) {
        strategy.setContext(context);
    }

    /**
     * Changes the preferred strategy. Do <em>NOT</em> call this method more than once for
     * a given JVM, as it will re-initialize the strategy and adversely affect any
     * existing threads using the old strategy.
     *
     * @param strategyName the fully qualified class name of the strategy that should be
     * used.
     */
    public static void setStrategyName(String strategyName) {
        SecurityContextHolder.strategyName = strategyName;
        initialize();
    }

    /**
     * Allows retrieval of the context strategy. See SEC-1188.
     *
     * @return the configured strategy for storing the security context.
     */
    public static SecurityContextHolderStrategy getContextHolderStrategy() {
        return strategy;
    }

    /**
     * Delegates the creation of a new, empty context to the configured strategy.
     */
    public static SecurityContext createEmptyContext() {
        return strategy.createEmptyContext();
    }

    @Override
    public String toString() {
        return "SecurityContextHolder[strategy='" + strategyName + "'; initializeCount="
                + initializeCount + "]";
    }
}
```

# 带名字的 ThreadLocal

```java
public class NamedThreadLocal<T> extends ThreadLocal<T> {

    private final String name;


    /**
     * Create a new NamedThreadLocal with the given name.
     * @param name a descriptive name for this ThreadLocal
     */
    public NamedThreadLocal(String name) {
        Assert.hasText(name, "Name must not be empty");
        this.name = name;
    }

    @Override
    public String toString() {
        return this.name;
    }

}
```

