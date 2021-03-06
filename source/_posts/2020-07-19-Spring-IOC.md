---
title: Spring IOC
date: 2020-07-19 12:03:57
tags:
- Spring
- Java
---
# 总体的类图

![spring-aop-proxy-creation.png](spring-aop-proxy-creation.png)

# Resource

Spring 的基本获取 Bean 的形式是获取配置文件（通常是 xml），而读取配置文件，首先要解决资源抽象问题。

```java
public interface Resource {
    InputStream getInputStream() throws IOException;
}

public class ClassPathResource implements Resource{
    
    private String path;
    
    private ClassLoader classLoader;
    
    public ClassPathResource(String path) {
        this(path, (ClassLoader)null);
    }
    
    public ClassPathResource(String path, ClassLoader classLoader) {
        this.path = path;
        this.classLoader = (classLoader != null ? classLoader : Thread.currentThread().getContextClassLoader());
    }

    @Override
    public InputStream getInputStream() throws IOException {
        return classLoader.getResourceAsStream(path);
    }
    
    /**
     * 来自于父类
     * This implementation returns a File reference for the underlying class path
     * resource, provided that it refers to a file in the file system.
     * @see org.springframework.util.ResourceUtils#getFile(java.net.URL, String)
     */
    @Override
    public File getFile() throws IOException {
        URL url = getURL();
        if (url.getProtocol().startsWith(ResourceUtils.URL_PROTOCOL_VFS)) {
            return VfsResourceDelegate.getResource(url).getFile();
        }
        return ResourceUtils.getFile(url, getDescription());
    }

}
```

除了 Resource 以外，还有另一种获取资源的方式，那就是通过 ResourceLoader：


```java
public class ResourceLoader {
    
    final String CLASSPATH_URL_PREFIX = "classpath:";
    
    public Resource getResource(String location){
        if (location.startsWith(CLASSPATH_URL_PREFIX)) {
            return new ClassPathResource(location.substring(CLASSPATH_URL_PREFIX.length()));
        }
        else {
            return new ClassPathResource(location);
        }
    }
}
```

# BeanDefinition

从配置文件里映射出来的数据结构，首先绑定到 BeanDefinition 上：

```java
public class BeanDefinition {
    // bean名称
    private String beanName;
    // bean的class对象
    private Class beanClass;
    // bean的class的包路径
    private String beanClassName;
    // bean依赖属性
    private PropertyValues propertyValues = new PropertyValues();
}
```

存储属性的地方使用了一个包装器类型来包含属性值列表：
```java
    private List<PropertyValue> propertyValues = new ArrayList<PropertyValue>();
    
    public void addPropertyValue(PropertyValue propertyValue){
        propertyValues.add(propertyValue);
    }
    
    public List<PropertyValue> getPropertyValues(){
        return this.propertyValues;
    }
}

/**
 * 这个 kv 值是可以被直接使用的
 */
public class PropertyValue {
    private final String name;
    private final Object value;
    
    public PropertyValue(String name, Object value) {
        this.name = name;
        this.value = value;
    }
    public String getName() {
        return name;
    }
    public Object getValue() {
        return value;
    }
}

```

# XmlBeanDefinitionReader

ResourceLoader + BeanDefinition + BeanDefinitionRegistry= BeanDefinitionReader，比如 XmlBeanDefinitionReader：

```java
public class XmlBeanDefinitionReader implements BeanDefinitionReader{
    // BeanDefinition注册到BeanFactory接口
    private BeanDefinitionRegistry registry;
    // 资源载入类
    private ResourceLoader resourceLoader;
    
    public XmlBeanDefinitionReader(BeanDefinitionRegistry registry, ResourceLoader resourceLoader) {
        this.registry = registry;
        this.resourceLoader = resourceLoader;
    }
    
    @Override
    public void loadBeanDefinitions(String location) throws Exception{
        InputStream is = getResourceLoader().getResource(location).getInputStream();
        doLoadBeanDefinitions(is);
    }
    
    public BeanDefinitionRegistry getRegistry(){
        return registry;
    }
    
    public ResourceLoader getResourceLoader(){
        return resourceLoader;
    }
}

protected void doLoadBeanDefinitions(InputStream is) throws Exception {
    // 1. 获取 document的 factory
    DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
    DocumentBuilder builder = factory.newDocumentBuilder();
    // 2. 把资源转化为 w3c 规定的 document
    Document document = builder.parse(is);
    // 3. 注册 bean 定义
    registerBeanDefinitions(document);
    is.close();
}

protected void registerBeanDefinitions(Document document) {
    // 1. 取出根
    Element root = document.getDocumentElement();
    // 2. 通过遍历根 
    parseBeanDefinitions(root);
}


protected void processBeanDefinition(Element ele) {
    String name = ele.getAttribute("id");
    String className = ele.getAttribute("class");
    if(className==null || className.length()==0){
        throw new IllegalArgumentException("Configuration exception: <bean> element must has class attribute.");
    }
    if(name==null||name.length()==0){
        name = className;
    }
    // 实际上也是用 new 方法来生成 beanDefinition，把 attribute 转换成为 BeanDefinition 的属性
    BeanDefinition beanDefinition = new BeanDefinition();
    beanDefinition.setBeanClassName(className);
    processBeanProperty(ele,beanDefinition);
    getRegistry().registerBeanDefinition(name, beanDefinition);
}

protected void processBeanProperty(Element ele, BeanDefinition beanDefinition) {
        NodeList childs = ele.getElementsByTagName("property");
        for (int i = 0; i < childs.getLength(); i++) {
            Node node = childs.item(i);
            if(node instanceof Element){
                Element property = (Element)node;
                // 把内部的 attribute 转换为 PropertyValues
                String name = property.getAttribute("name");
                String value = property.getAttribute("value");
                if(value!=null && value.length()>0){
                    beanDefinition.getPropertyValues().addPropertyValue(new PropertyValue(name, value));
                }else{
                    String ref = property.getAttribute("ref");
                    if(ref==null || ref.length()==0){
                        throw new IllegalArgumentException("Configuration problem: <property> element for "+
                                name+" must specify a value or ref.");
                    }
                    BeanReference reference = new BeanReference(ref);
                    beanDefinition.getPropertyValues().addPropertyValue(new PropertyValue(name, reference));
                }
            }
        }
    }
```

而 BeanDefinitionRegistry 则是另一个维护 map 的接口：

```java
public interface BeanDefinitionRegistry {
    void registerBeanDefinition(String beanName, BeanDefinition beanDefinition);
}
```

通常 BeanDefinitionRegistry 和 BeanFactory 被实现在同一个实现里：

```java
public class DefaultListableBeanFactory extends AbstractBeanFactory implements ConfigurableListableBeanFactory,BeanDefinitionRegistry{

    private Map<String, BeanDefinition> beanDefinitionMap = new ConcurrentHashMap<String, BeanDefinition>();
    private List<String> beanDefinitionNames = new ArrayList<String>();
    
    public void registerBeanDefinition(String beanName,BeanDefinition beanDefinition){
        beanDefinitionMap.put(beanName, beanDefinition);
        beanDefinitionNames.add(beanName);
    }
}
```

# BeanFactory

BeanFactory 自有其继承体系：

```java
public interface BeanFactory {
    
    Object getBean(String beanName);
}

// 这个抽象类是整个模板方法里最重要的
public abstract class AbstractBeanFactory implements ConfigurableListableBeanFactory {
    private Map<String, Object> singleObjects = new ConcurrentHashMap<String, Object>();
    
    protected abstract BeanDefinition getBeanDefinitionByName(String beanName);
    
    // 所有的创建 bean 的方法的入口
    protected Object createInstance(BeanDefinition beanDefinition) {
    try {
        if(beanDefinition.getBeanClass() != null){
            return beanDefinition.getBeanClass().newInstance();
        }else if(beanDefinition.getBeanClassName() != null){
            try {
                Class clazz = Class.forName(beanDefinition.getBeanClassName());
                beanDefinition.setBeanClass(clazz);
                return clazz.newInstance();
            } catch (ClassNotFoundException e) {
                throw new RuntimeException("bean Class " + beanDefinition.getBeanClassName() + " not found");
            }
        }
    } catch (Exception e) {
        throw new RuntimeException("create bean " + beanDefinition.getBeanName() + " failed");
    } 
    throw new RuntimeException("bean name for " + beanDefinition.getBeanName() + " not define bean class");
}

    /**
     * 从 bean definition 里生成 bean，这个方法在 getBean 里才执行，它可以被优化成一个惰性求值的方法
     * Return an instance, which may be shared or independent, of the specified bean.
     * @param name the name of the bean to retrieve
     * @param requiredType the required type of the bean to retrieve
     * @param args arguments to use when creating a bean instance using explicit arguments
     * (only applied when creating a new instance as opposed to retrieving an existing one)
     * @param typeCheckOnly whether the instance is obtained for a type check,
     * not for actual use
     * @return an instance of the bean
     * @throws BeansException if the bean could not be created
     */
    @SuppressWarnings("unchecked")
    protected <T> T doGetBean(final String name, @Nullable final Class<T> requiredType,
            @Nullable final Object[] args, boolean typeCheckOnly) throws BeansException {

        final String beanName = transformedBeanName(name);
        Object bean;

        // Eagerly check singleton cache for manually registered singletons.
        Object sharedInstance = getSingleton(beanName);
        if (sharedInstance != null && args == null) {
            if (logger.isTraceEnabled()) {
                if (isSingletonCurrentlyInCreation(beanName)) {
                    logger.trace("Returning eagerly cached instance of singleton bean '" + beanName +
                            "' that is not fully initialized yet - a consequence of a circular reference");
                }
                else {
                    logger.trace("Returning cached instance of singleton bean '" + beanName + "'");
                }
            }
            bean = getObjectForBeanInstance(sharedInstance, name, beanName, null);
        }

        else {
            // Fail if we're already creating this bean instance:
            // We're assumably within a circular reference.
            if (isPrototypeCurrentlyInCreation(beanName)) {
                throw new BeanCurrentlyInCreationException(beanName);
            }

            // Check if bean definition exists in this factory.
            BeanFactory parentBeanFactory = getParentBeanFactory();
            if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
                // Not found -> check parent.
                String nameToLookup = originalBeanName(name);
                if (parentBeanFactory instanceof AbstractBeanFactory) {
                    return ((AbstractBeanFactory) parentBeanFactory).doGetBean(
                            nameToLookup, requiredType, args, typeCheckOnly);
                }
                else if (args != null) {
                    // Delegation to parent with explicit args.
                    return (T) parentBeanFactory.getBean(nameToLookup, args);
                }
                else if (requiredType != null) {
                    // No args -> delegate to standard getBean method.
                    return parentBeanFactory.getBean(nameToLookup, requiredType);
                }
                else {
                    return (T) parentBeanFactory.getBean(nameToLookup);
                }
            }

            if (!typeCheckOnly) {
                markBeanAsCreated(beanName);
            }

            try {
                final RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
                checkMergedBeanDefinition(mbd, beanName, args);

                // Guarantee initialization of beans that the current bean depends on.
                String[] dependsOn = mbd.getDependsOn();
                if (dependsOn != null) {
                    for (String dep : dependsOn) {
                        if (isDependent(beanName, dep)) {
                            throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                                    "Circular depends-on relationship between '" + beanName + "' and '" + dep + "'");
                        }
                        registerDependentBean(dep, beanName);
                        try {
                            getBean(dep);
                        }
                        catch (NoSuchBeanDefinitionException ex) {
                            throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                                    "'" + beanName + "' depends on missing bean '" + dep + "'", ex);
                        }
                    }
                }

                // Create bean instance.
                if (mbd.isSingleton()) {
                    sharedInstance = getSingleton(beanName, () -> {
                        try {
                            return createBean(beanName, mbd, args);
                        }
                        catch (BeansException ex) {
                            // Explicitly remove instance from singleton cache: It might have been put there
                            // eagerly by the creation process, to allow for circular reference resolution.
                            // Also remove any beans that received a temporary reference to the bean.
                            destroySingleton(beanName);
                            throw ex;
                        }
                    });
                    bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
                }

                else if (mbd.isPrototype()) {
                    // It's a prototype -> create a new instance.
                    Object prototypeInstance = null;
                    try {
                        beforePrototypeCreation(beanName);
                        prototypeInstance = createBean(beanName, mbd, args);
                    }
                    finally {
                        afterPrototypeCreation(beanName);
                    }
                    bean = getObjectForBeanInstance(prototypeInstance, name, beanName, mbd);
                }

                else {
                    String scopeName = mbd.getScope();
                    final Scope scope = this.scopes.get(scopeName);
                    if (scope == null) {
                        throw new IllegalStateException("No Scope registered for scope name '" + scopeName + "'");
                    }
                    try {
                        Object scopedInstance = scope.get(beanName, () -> {
                            beforePrototypeCreation(beanName);
                            try {
                                return createBean(beanName, mbd, args);
                            }
                            finally {
                                afterPrototypeCreation(beanName);
                            }
                        });
                        bean = getObjectForBeanInstance(scopedInstance, name, beanName, mbd);
                    }
                    catch (IllegalStateException ex) {
                        throw new BeanCreationException(beanName,
                                "Scope '" + scopeName + "' is not active for the current thread; consider " +
                                "defining a scoped proxy for this bean if you intend to refer to it from a singleton",
                                ex);
                    }
                }
            }
            catch (BeansException ex) {
                cleanupAfterBeanCreationFailure(beanName);
                throw ex;
            }
        }

        // Check if required type matches the type of the actual bean instance.
        if (requiredType != null && !requiredType.isInstance(bean)) {
            try {
                T convertedBean = getTypeConverter().convertIfNecessary(bean, requiredType);
                if (convertedBean == null) {
                    throw new BeanNotOfRequiredTypeException(name, requiredType, bean.getClass());
                }
                return convertedBean;
            }
            catch (TypeMismatchException ex) {
                if (logger.isTraceEnabled()) {
                    logger.trace("Failed to convert bean '" + name + "' to required type '" +
                            ClassUtils.getQualifiedName(requiredType) + "'", ex);
                }
                throw new BeanNotOfRequiredTypeException(name, requiredType, bean.getClass());
            }
        }
        return (T) bean;
    }
}
```

在 AbstractAutowireCapableBeanFactory 里有 createBean 的一个例子
```java
@Override
    protected Object createBean(String beanName, RootBeanDefinition mbd, @Nullable Object[] args)
            throws BeanCreationException {

        if (logger.isTraceEnabled()) {
            logger.trace("Creating instance of bean '" + beanName + "'");
        }
        RootBeanDefinition mbdToUse = mbd;

        // Make sure bean class is actually resolved at this point, and
        // clone the bean definition in case of a dynamically resolved Class
        // which cannot be stored in the shared merged bean definition.
        Class<?> resolvedClass = resolveBeanClass(mbd, beanName);
        if (resolvedClass != null && !mbd.hasBeanClass() && mbd.getBeanClassName() != null) {
            mbdToUse = new RootBeanDefinition(mbd);
            mbdToUse.setBeanClass(resolvedClass);
        }

        // Prepare method overrides.
        try {
            mbdToUse.prepareMethodOverrides();
        }
        catch (BeanDefinitionValidationException ex) {
            throw new BeanDefinitionStoreException(mbdToUse.getResourceDescription(),
                    beanName, "Validation of method overrides failed", ex);
        }

        try {
            // 注意，这里可以给 InstantiationAwareBeanPostProcessor 之类的后处理器一个机会，进行实例化的一个拦截
            // Give BeanPostProcessors a chance to return a proxy instead of the target bean instance.
            Object bean = resolveBeforeInstantiation(beanName, mbdToUse);
            if (bean != null) {
                return bean;
            }
        }
        catch (Throwable ex) {
            throw new BeanCreationException(mbdToUse.getResourceDescription(), beanName,
                    "BeanPostProcessor before instantiation of bean failed", ex);
        }

        try {
            Object beanInstance = doCreateBean(beanName, mbdToUse, args);
            if (logger.isTraceEnabled()) {
                logger.trace("Finished creating instance of bean '" + beanName + "'");
            }
            return beanInstance;
        }
        catch (BeanCreationException | ImplicitlyAppearedSingletonException ex) {
            // A previously detected exception with proper bean creation context already,
            // or illegal singleton state to be communicated up to DefaultSingletonBeanRegistry.
            throw ex;
        }
        catch (Throwable ex) {
            throw new BeanCreationException(
                    mbdToUse.getResourceDescription(), beanName, "Unexpected exception during bean creation", ex);
        }
    }

```

# ApplicationContext

BeanFactory 是 Spring 早期设计的抽象，应该尽量不被直接使用，当代的 Spring 应该使用更加现代的抽象 ApplicationContext，如：
 
```java
public interface ApplicationContext extends BeanFactory{
}
```
如果我们使用 xml 来初始化 ApplicationContext，则我们应该使用 ClasspathXmlApplicationContext：

```java
public class ClasspathXmlApplicationContext extends AbstractApplicationContext {
    private String location;
    
    // 这个构造器有一个很特别的地方，那就是在构造器里直接 refresh
    public ClasspathXmlApplicationContext(String location) {
        this.location = location;
        try {
            refresh();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

这里引用的最重要的 refresh 方法，就是所有谈到 Spring 的文档里都必然谈到的 AbstractApplicationContext 里的 refresh()（经典的模板方法模式，所有的扩展点的顺序要依照它设定的方法来实现）：

```java
@Override
    public void refresh() throws BeansException, IllegalStateException {
        synchronized (this.startupShutdownMonitor) {
            // Prepare this context for refreshing.主要是设置开始时间以及标识active标志位为true
            prepareRefresh();

            // Tell the subclass to refresh the internal bean factory.    
            // 先获取一个 bean 工厂，注意，在它的子类（比如 GenericApplicationContext）的实现里，总是先刷新一下 BeanFactory，然后加载配置文件，把自己的成员的 beanFactory 返回到这一层。
            ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

            // 先装配这个 beanFactory
            // Prepare the bean factory for use in this context.
            prepareBeanFactory(beanFactory);

            try {
                // 没有生成任何的 bean，就先后处理这个 beanFactory，所以这里就会直接触发 bean 工厂的后处理，如web项目中配置 ServletContext
                // Allows post-processing of the bean factory in context subclasses.
                postProcessBeanFactory(beanFactory);

                // 实例化 + 调用注册好的 BeanFactoryPostProcessors，实际上是对各种 bean definition 的 PropertyValue 进行后处理。注意，这里是利用之前注册的扩展点来实现后处理
                // Invoke factory processors registered as beans in the context.
                invokeBeanFactoryPostProcessors(beanFactory);
                
                // 只是实例化，并注册 bean 后处理器
                // Register bean processors that intercept bean creation.
                registerBeanPostProcessors(beanFactory);
                
                // 初始化消息源
                // Initialize message source for this context.
                initMessageSource();

                // 初始化应用事件多播器（和listener 不同）
                // Initialize event multicaster for this context.
                initApplicationEventMulticaster();
                    
                // 调用子类的刷新生命周期的中间扩展点，如初始化特殊的bean
                // Initialize other special beans in specific context subclasses.
                onRefresh();
                
                // 注册监听器，所有的 bean 初始化完了，才会初始化监听器
                // Check for listener beans and register them.
                registerListeners();
                
                // 对 BeanFactory 初始化进行收尾
                // Instantiate all remaining (non-lazy-init) singletons.
                finishBeanFactoryInitialization(beanFactory);
                
                // 对刷新进行收尾，初始化生命周期，发布容器事件（如 ContextRefreshedEvent 是在这一步被发出的）
                // Last step: publish corresponding event.
                finishRefresh();
            }

            catch (BeansException ex) {
                if (logger.isWarnEnabled()) {
                    logger.warn("Exception encountered during context initialization - " +
                            "cancelling refresh attempt: " + ex);
                }

                // 销毁已经创建的单例bean
                // Destroy already created singletons to avoid dangling resources.
                destroyBeans();
                
                // 重置active标识
                // Reset 'active' flag.
                cancelRefresh(ex);

                // Propagate exception to caller.
                throw ex;
            }

            finally {
                // Reset common introspection caches in Spring's core, since we
                // might not ever need metadata for singleton beans anymore...
                resetCommonCaches();
            }
        }
    }
```

# 如何实现自动装配？

对于 AutoWired 而言，答案是使用 AutowiredAnnotationBeanPostProcessor 的生命周期钩子。可见，我们所有的 field injection 相关的注入，都要考虑 BeanPostProcessor 的钩子方法进行扩展。

对于 field injection，最关键的方法是：

```java
@Override
    public PropertyValues postProcessProperties(PropertyValues pvs, Object bean, String beanName) {
        InjectionMetadata metadata = findAutowiringMetadata(beanName, bean.getClass(), pvs);
        try {
            metadata.inject(bean, beanName, pvs);
        }
        catch (BeanCreationException ex) {
            throw ex;
        }
        catch (Throwable ex) {
            throw new BeanCreationException(beanName, "Injection of autowired dependencies failed", ex);
        }
        return pvs;
    }
```

和之前我设计和实现的缓存注入的思路是一样的，实际上所有的动态注入的 annotation 都应该这样设计，才能满足 Spring 的依赖管理的布局。
