---
title: 闭包的理解
date: 2018-05-30T14:21:26+08:00
lastmod: 2018-05-30T14:21:26+08:00
author: hanamichi
cover: /img/closure.jpg
categories: ['编程语言学习']
tags: ['编程概念']
---

关于闭包的一些理解及记录

<!--more-->

## 闭包

> **对象是带方法的数据，而闭包是带数据的方法**(后半句的数据特指外部数据)

> 闭包也是一种为表示带有自由变量的过程而用的实用技术

```
f(x,y) = x+y+z
```

在函数f中，x,y为约束变量，z为自由变量。

同样在一个代码块中，如果某个变量在这个代码块中没被定义过，那么这个变量就可以被认为是一个自由变量。

Haskell社区把函数分为两类，一种为闭包，另一种和闭包相对的叫组合子

> 不含自由变量的函数叫组合子。

> 全局函数是一个有名字但不会捕获任何值的闭包。

全局函数（本质上是一个有名字的组合子）被归为闭包的一种特殊形式。

例子：

```javascript
//从银行账户中取款时，每一次取款都会更新账户余额balance，
function makeAccount(balance){
    function withdraw(amount){
    	balance = balance - amount;
        return balance;
    }
    return withdraw;
}
//withdraw（是一个闭包）作为函数makeAccount的返回值，这样withdraw不仅仅单纯作为一个函数存在，而且携带着balance变量

var withdraw1 = makeAccount(100);  // withdraw1 is a closure here.
withdraw1(10);
// => 90
withdraw1(30);
// => 60
//我们还可以生成不止一个withdraw闭包，而且各个闭包之间是相互独立的。
```
