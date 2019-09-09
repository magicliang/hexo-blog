---
title: Petroware 的 Unit Testing Guidelines
date: 2019-09-09 21:43:31
tags:
- Test
---

1. Keep unit tests small and fast

Ideally the entire test suite should be executed before every code check in. Keeping the tests fast reduce the development turnaround time.

让单元测试保持小和快。

最完美的是，整个测试套件应该在每次代码被签入的时候被执行。让测试保持快速减少了开发的周转时间。

点评：小的测试是低成本测试。


2. Unit tests should be fully automated and non-interactive

The test suite is normally executed on a regular basis and must be fully automated to be useful. If the results require manual inspection the tests are not proper unit tests.

单元测试应该是全自动化且无交互的。

单元测试总是被正式运行在常规基础之上，且必须被全自动化才能有用。如果结果需要手动检查，测试并不是恰当的单元测试。

点评：测试应该自动化。

3. Make unit tests simple to run

Configure the development environment so that single tests and test suites can be run by a single command or a one button click.

让单元测试运行简单。

配置开发环境使得单一测试和测试集可以通过一个命令或者一键执行。

4. Measure the tests

测量测试。

Apply coverage analysis to the test runs so that it is possible to read the exact execution coverage and investigate which parts of the code is executed and not.

对测试运营应用覆盖率分析，这样就可以读到精确的运行覆盖率，并调查哪一部分代码被运行了，哪一部分没有。

点评：测试要带给我们结论。哪里有 bug，哪里没有。那些 code path 是可达的，哪些 code path 是不可达的。

5. Fix failing tests immediately

立即修复失败测试。

Each developer should be responsible for making sure a new test runs successfully upon check in, and that all existing tests runs successfully upon code check in.

If a test fails as part of a regular test execution the entire team should drop what they are currently doing and make sure the problem gets fixed.

每个开发者必须负责使新测试一被签入就运行成功，且所有存量测试也在签入后运行成功。

如果一次常规测试执行中，一个测试失败了，整个团队应该丢下手头的事情，确保问题被修复。

点评：测试要有回归分析。

6. Keep testing at unit level

保持测试在单元级别。

Unit testing is about testing classes. There should be one test class per ordinary class and the class behaviour should be tested in isolation. Avoid the temptation to test an entire work-flow using a unit testing framework, as such tests are slow and hard to maintain. Work-flow testing may have its place, but it is not unit testing and it must be set up and executed independently.

单元测试是关于测试类的。每个普通的类应该有一个测试，且类的行为应该被隔离测试。要抵御用一个单元测试框架来测试整个工作流的诱惑，因为这样的测试缓慢且难于维护。自有进行工作流测试的地方，而不是在单元测试里，它必须要被独立设置起来执行。

点评：小的测试才是可以维护的。

7. Start off simple
从简单开始

One simple test is infinitely better than no tests at all. A simple test class will establish the target class test framework, it will verify the presence and correctness of both the build environment, the unit testing environment, the execution environment and the coverage analysis tool, and it will prove that the target class is part of the assembly and that it can be accessed.
The Hello, world! of unit tests goes like this:

     void testDefaultConstruction()
     {
       Foo foo = new Foo();
       assertNotNull(foo);
     }
     
一个简单的单元测试绝对好于没测试。一个测试类会建立目标测试框架，它会校验构建环境/单元测试环境/执行环境/覆盖率分析工具的存在性和正确性，它会证明目标类是集合的一部分，且可以被访问。单元测试的 Hello, world! 如下：

     void testDefaultConstruction()
     {
       Foo foo = new Foo();
       assertNotNull(foo);
     }

点评：有胜于无，1胜于0。

8. Keep tests independent

保证单元测试独立

To ensure testing robustness and simplify maintenance, tests should never rely on other tests nor should they depend on the ordering in which tests are executed.

为了保证鲁棒性并简化维护工作，测试绝不可依赖其他测试或者它们彼此之间的执行顺序。

点评：测试要独立。还是为维护性服务。

9. Keep tests close to the class being tested

让测试紧随被测试类

If the class to test is Foo the test class should be called FooTest (not TestFoo) and kept in the same package (directory) as Foo. Keeping test classes in separate directory trees makes them harder to access and maintain.
Make sure the build environment is configured so that the test classes doesn't make its way into production libraries or executables.

如果被测试类是 Foo，测试类应该叫 FooTest （而不是TestFoo），并且放在同 Foo 的一个包（目录）下。把测试类放在另一个目录树下让它们难以被触达和维护。

保证构建环境被配置过，所以测试类不会被放进生产库或者可执行文件里面。

点评：测试要和被测试的类紧密相连，概念上才连续，更好维护。

10. Name tests properly

恰当地命名测试。

Make sure each test method test one distinct feature of the class being tested and name the test methods accordingly. The typical naming convention is test[what] such as testSaveAs(), testAddListener(), testDeleteProperty() etc.

确保每个测试方法测试被测试类的一个截然不同的特征，并因应命名测试方法。典型测试惯例是test[什么]，例如 testSaveAs(), testAddListener(), testDeleteProperty() 等等。

点评：测试要和被测试的类紧密相连，概念上才连续，更好维护。同上。

11. Test public API

测试公共 API。

Unit testing can be defined as testing classes through their public API. Some testing tools makes it possible to test private content of a class, but this should be avoided as it makes the test more verbose and much harder to maintain. If there is private content that seems to need explicit testing, consider refactoring it into public methods in utility classes instead. But do this to improve the general design, not to aid testing.

单元测试可以通过测试类的公共 API 来定义。一些测试工具使得测试类的私有内容变得可能，但不应该让测试变得更加冗长，且更难以维护。如果有需要被显式测试的私有内容，考虑把它重构进工具类的公共方法里为好。但这么做是为了改善整体设计，而不是帮助测试。

点评：私有 API 要被测试，既是一个不当的测试问题，也是一个不当的设计问题。

12. Think black-box
黑盒思考

Act as a 3rd party class consumer, and test if the class fulfills its requirements. And try to tear it apart.

想象成第三方的类消费者，测试类是否满足它的需求。并且试图把它拆解。

点评：单元测试要注意基本测试。

13. Think white-box
白盒思考

After all, the test programmer also wrote the class being tested, and extra effort should be put into testing the most complex logic.

毕竟，测试程序员一样写了被测试，额外的劳动应该被放在测试最复杂的逻辑中。

点评：单元测试要注意复杂测试。

14. Test the trivial cases too

也要测试琐碎case。

It is sometimes recommended that all non-trivial cases should be tested and that trivial methods like simple setters and getters can be omitted. However, there are several reasons why trivial cases should be tested too:
Trivial is hard to define. It may mean different things to different people.
From a black-box perspective there is no way to know which part of the code is trivial.
The trivial cases can contain errors too, often as a result of copy-paste operations:
     private double weight_;
     private double x_, y_;

     public void setWeight(int weight)
     {
       weight = weight_;  // error
     }

     public double getX()
     {
       return x_;
     }

     public double getY()
     {
       return x_;  // error
     }
The recommendation is therefore to test everything. The trivial cases are simple to test after all.

getter 和 setter 也是要测试的。

15. Focus on execution coverage first

先关注执行覆盖率。

Distinguish between execution coverage and actual test coverage. The initial goal of a test should be to ensure high execution coverage. This will ensure that the code is actually executed on some input parameters. When this is in place, the test coverage should be improved. Note that actual test coverage cannot be easily measured (and is always close to 0% anyway).
Consider the following public method:

     void setLength(double length);
     
By calling setLength(1.0) you might get 100% execution coverage. To acheive 100% actual test coverage the method must be called for every possible double value and correct behaviour must be verified for all of them. Surly an impossible task.

要区别执行覆盖率和实际测试覆盖率。一个测试的首要目标应该是高的执行覆盖率。这可以确保代码在某些输入参数下切实被执行了。这一步到位了以后，应该改善测试覆盖率。要注意实际的测试覆盖率不容易被测量（实际上无论如何经常接近于 0%）。

     void setLength(double length);
的测试覆盖率是不可能达到百分之百的。

点评：不可穷举的case里面，执行覆盖率尤其重要。测试覆盖率只能用数学归纳法推理保证。

16. Cover boundary cases

覆盖边界 case。

Make sure the parameter boundary cases are covered. For numbers, test negatives, 0, positive, smallest, largest, NaN, infinity, etc. For strings test empty string, single character string, non-ASCII string, multi-MB strings etc. For collections test empty, one, first, last, etc. For dates, test January 1, February 29, December 31 etc. The class being tested will suggest the boundary cases in each specific case. The point is to make sure as many as possible of these are tested properly as these cases are the prime candidates for errors.

要保证参数的边界 case 被覆盖了。对于数字，要测试负数，0，整数，最大值，最小值，非数字，无限值，等等。对于字符串，要测试空字符串，单字符字符串，非 ASCII 字符串，几兆大小的字符串，等等。对于集合，要测试空集合，单集合，首元素，尾元素，等等。对日期，要测试1月1日，2月29日，12月31日，等等。被测试类会建议每一种独特 case 下的边界条件。关键点是这些case尽可能多地被测试到了，因为这些case是错误的元凶。

17. Provide a random generator

提供一个随机生成器。

When the boundary cases are covered, a simple way to improve test coverage further is to generate random parameters so that the tests can be executed with different input every time.
To achieve this, provide a simple utility class that generates random values of the base types like doubles, integers, strings, dates etc. The generator should produce values from the entire domain of each type.

当边界case被覆盖到以后，提升测试覆盖率的一个简单方法就是生成随机参数，这样测试每次都会被不同的输入执行。

为了达到这一点，提供一个简单的工具类来生成基础类型的随机值。生成器应该从每种类型的整个值域产生值。

If the tests are fast, consider running them inside loops to cover as many possible input combinations as possible. The following example verifies that converting twice between little endian and big endian representations gives back the original value. As the test is fast, it is executed on one million different values each time.

    void testByteSwapper()
    {
      for (int i = 0; i < 1000000; i++) {
        double v0 = Random.getDouble();
        double v1 = ByteSwapper.swap(v0);
        double v2 = ByteSwapper.swap(v1);
        assertEquals(v0, v2);
      }
    }
    
如果测试很快，在循环里执行它们以尽可能多的覆盖输入组合。

18. Test each feature once

一次只测试一个特性。

When being in testing mode it is sometimes tempting to assert on "everything" in every test. This should be avoided as it makes maintenance harder. Test exactly the feature indicated by the name of the test method.

As for ordinary code, it is a goal to keep the amount of test code as low as possible.

在测试的时候，有时候会尝试在每个测试里面测试所有东西。这应该被避免因为它使得维护变难。只测试测试方法名称指示的特性。

对于普通代码，有一个目标是保证测试代码的数量尽可能低。

19. Use explicit asserts

使用显式的断言。

Always prefer assertEquals(a, b) to assertTrue(a == b) (and likewise) as the former will give more useful information of what exactly is wrong if the test fails. This is in particular important in combination with random value parameters as described above when the input values are not known in advance.

总是选择 assertEquals(a, b) 而非 assertTrue(a == b)（反过来也一样），前者会给出更有用的信息-测试失败了，到底哪里有错。这在上面描述到的随机参数组合的时候尤其有重要，那时候并不是所有参数都事先明了。

20. Provide negative tests

提供负面测试。

Negative tests intentionally misuse the code and verify robustness and appropriate error handling.
Consider this method that throws an exception if called with a negative parameter:

    void setLength(double length) throws IllegalArgumentException;
Testing correct behavior for this particular case can be done by:
    try {
      setLength(-1.0);
      fail();  // If we get here, something went wrong
    }
    catch (IllegalArgumentException exception) {
      // If we get here, all is fine
    }
    
负面测试故意无用代码，并且验证程序的鲁棒性和正确的错误处理。

点评：非常重要，测试的深度就在这里了。

21. Design code with testing in mind

胸有测试，再设计代码。

Writing and maintaining unit tests are costly, and minimizing public API and reducing cyclomatic complexity in the code are ways to reduce this cost and make high-coverage test code faster to write and easier to maintain.

Some suggestions:

Make class members immutable by establishing state at construction time. This reduce the need of setter methods.
Restrict the use of excessive inheritance and virtual public methods.
Reduce the public API by utilizing friend classes (C++), internal scope (C#) and package scope (Java).
Avoid unnecessary branching.
Keep as little code as possible inside branches.
Make heavy use of exceptions and assertions to validate arguments in public and private API's respectively.
Restrict the use of convenience methods. From a black-box perspective every method must be tested equally well. Consider the following trivial example:
        public void scale(double x0, double y0, double scaleFactor)
        {
          // scaling logic
        }

        public void scale(double x0, double y0)
        {
          scale(x0, y0, 1.0);
        }
Leaving out the latter simplifies testing on the expense of slightly extra workload for the client code.

写单元测试是很昂贵的，减少公共 API 和代码中的圈复杂度是减轻这种开销的方法，使高覆盖率的测试代码更快被编写且更易被维护。

一些建议：

在构造时就建立不可修改的状态。这会减少 setter 的数量。

减少过分继承和虚函数的使用。

使用友元类（C++），内部域（C#）和包域（Java）来减少公共API。

避免不必要的分支。

分支里的代码尽可能少。

重度使用异常和断言，来验证公共和私有API（相应的）的实参。

限制使用方便方法。

点评：意在笔先，非常重要。

22. Don't connect to predefined external resources

Unit tests should be written without explicit knowledge of the environment context in which they are executed so that they can be run anywhere at anytime. In order to provide required resources for a test these resources should instead be made available by the test itself.
Consider for instance a class for parsing files of a certain type. Instead of picking a sample file from a predefined location, put the file content inside the test, write it to a temporary file in the test setup process and delete the file when the test is done.

不要连接到预先定义好的外部资源上。

单元测试必须在不需要显式了解要被执行的外部环境上下文的前提下被编写，这样它们在何时何地都可以被执行。要提供测试必须的资源，必须让测试自己来干。

考虑通过解析某个类型的文件，实例化一个类，而不是从某个预定义的场所取一个样例文件，把文件内容放进测试里。把文件的内容放进测试里，在测试启动流程里，把它写到临时文件中，测试完了就删掉。


点评：这也是测试的一个独立性问题。

23. Know the cost of testing

了解测试的开销。

Not writing unit tests is costly, but writing unit tests is costly too. There is a trade-off between the two, and in terms of execution coverage the typical industry standard is at about 80%.
The typical areas where it is hard to get full execution coverage is on error and exception handling dealing with external resources. Simulating a database breakdown in the middle of a transaction is quite possible, but might prove too costly compared to extensive code reviews which is the alternative approach.

不只是写单元测试昂贵，而且跑单元测试也昂贵（此处应有）。两者之间有所权衡，考虑到执行覆盖率，工业标准大约为80%。

难以得到完整执行覆盖率的典型领域是处理外部资源的异常处理。在事务执行中仿真数据库垮掉是可以做到的，但比起另一种方案，大量的代码审查，它太昂贵了。

点评：引入不确定性的依赖是最难测试的。

24. Prioritize testing
要为测试制定优先级。

Unit testing is a typical bottom-up process, and if there is not enough resources to test all parts of a system priority should be put on the lower levels first.

单元测试是典型的自底向上流程。如果没有足够的资源测试系统的所有部分，应该以底层测试为重。

点评：比较反一般直觉的是，底层的测试更重要。

25. Prepare test code for failures

准备失败的代码。

Consider the simple example:
    Handle handle = manager.getHandle();
    assertNotNull(handle);

    String handleName = handle.getName();
    assertEquals(handleName, "handle-01");
    
If the first assertion is false, the code crashes in the subsequent statement and none of the remaining tests will be executed. Always prepare for test failure so that the failure of a single test doesn't bring down the entire test suite execution. In general rewrite as follows:
    Handle handle = manager.getHandle();
    assertNotNull(handle);
    if (handle == null) return;

    String handleName = handle.getName();
    assertEquals(handleName, "handle-01");
    
点评：测试要跑完，测试也不能crash。测试也要捕获异常。


26. Write tests to reproduce bugs

写测试来重现 bug。

When a bug is reported, write a test to reproduce the bug (i.e. a failing test) and use this test as a success criteria when fixing the code.

当一个bug被报告，写一个测试来重现这个bug。然后用这个测试当做修复这段代码的成功标准。

27. Know the limitations

知道极限在哪。

Unit tests can never prove the correctness of code!!
A failing test may indicate that the code contains errors, but a succeeding test doesn't prove anything at all.

The most useful appliance of unit tests are verification and documentation of requirements at a low level, and regression testing: verifying that code invariants remains stable during code evolution and refactoring.

Consequently unit tests can never replace a proper up-front design and a sound development process. Unit tests should be used as a valuable supplement to the established development methodologies.

And perhaps most important: The use of unit tests forces the developers to think through their designs which in general improve code quality and API's.

点评：测试只能证明有bug，不能证明没有bug。正面的设计，合理的流程不是测试能替代的，测试反而是方法论里有价值的补充。