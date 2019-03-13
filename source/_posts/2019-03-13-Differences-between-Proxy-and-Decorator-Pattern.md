---
title: Differences between Proxy and Decorator Pattern
date: 2019-03-13 16:01:10
tags:
- 设计模式
---
https://stackoverflow.com/questions/18618779/differences-between-proxy-and-decorator-pattern

https://powerdream5.wordpress.com/2007/11/17/the-differences-between-decorator-pattern-and-proxy-pattern/

Decorator Pattern focuses on dynamically adding functions to an object, while Proxy Pattern focuses on controlling access to an object.

Relationship between a Proxy and the real subject is typically set at compile time, Proxy instantiates it in some way, whereas Decorator is assigned to the subject at runtime, knowing only subject's interface.

```java
//Proxy Pattern
public class Proxy implements Subject{

       private Subject subject;
       public Proxy(){
             //the relationship is set at compile time
            subject = new RealSubject();
       }
       public void doAction(){
             ….
             subject.doAction();
             ….
       }
}

//client for Proxy
public class Client{
        public static void main(String[] args){
             //the client doesn’t know the Proxy delegate another object
             Subject subject = new Proxy();
             …
        }
}
//Decorator Pattern
public class Decorator implements Component{
        private Component component;
        public Decorator(Component component){
            this.component = component
        }
       public void operation(){
            ….
            component.operation();
            ….
       }
}

//client for Decorator
public class Client{
        public static void main(String[] args){
            //the client designate which class the decorator decorates
            Component component = new Decorator(new ConcreteComponent());
            …
        }
}
```