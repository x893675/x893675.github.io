---
layout:     post
title:      "GNU Features"
subtitle:   " \"Linux C Source Code \""
date:       2017-03-29 12:00:00
author:     "Hanamichi"
header-img: "img/post-bg-2015.jpg"
catalog: true
tags:
    - C
    - Linux
---


### 问题引发

在阅读**qemu**源码时发现有很多结构体定义看不懂，结构体代码如下：

```c
typedef struct {
    uint8_t    status;
    uint16_t    handle;
    uint8_t    encrypt;
} QEMU_PACKED evt_encrypt_change;
```

代码块中的`QEMU_PACKED`在当前文件没有任何定义，我在整个源码工程中搜索后看到如下定义：

```c
#if defined(_WIN32)
# define QEMU_PACKED __attribute__((gcc_struct, packed))
#else
# define QEMU_PACKED __attribute__((packed))
#endif
```
### \_\_attribute\_\_关键字

GCC使用\_\_attribute\_\_关键字来描述**函数，变量和数据类型**的属性，用于编译器对源代码的优化。一般放在声明的最后。

常用用法如下：

* void noreturnfun() \__attribute\__((noreturn)); //函数不会返回。

* void centon() \_\_attribute\_\_((alias("\_\_centon"))); //设置函数别名，函数是__cencon,别名是centon.

* void MainEnter() \_\_attribute\_\_((constructor)); //main_enter函数在进入main函数前调用

* void MainExit() \_\_attribute\_\_((destructor)); //main_exit函数在main函数返回后调用

* void Fun() \_\_attribute\_\_ ((noinline)); //fun函数不能作为inline函数优化

* void Fun() \_\_attribute\_\_ ((section("specials”))); //将函数放到specials段中，而不是通常的text段中

* no_instrument_function、constructor和destructor关键字主要用于剖析(profiling)源代码的。

* \_\_attribute\_\_(format(archetype,string-index,first-to-check)): format attribute提供了依照printf, scanf, strftime, strfmon类型函数的参数格式对目标函数进行类型的检查.

* \_\_attribute\_\_((weak)): weak symbol,弱符号. 若存在两个相同的全局符号时，会引发重定义错误. 如果使用weak attribute,则当weak symbol和non-weak symbol同时存在的时候，linker会使用non-weak symbol.若只有weak symbol存在的时候则只使用weak symbol.

* \_\_attribute\_\_((deprecated)): deprecated,弃用. 如果在源文件在任何地方地方使用deprecated attribute函数,编译器将会发出警告.

* \_\_attribute\_\_((aligned(alignment))): 指定变量或结构体最小字节对齐数,以byte为单位.ALIGNMENT: 指定的字节对齐操作数. <wbr>

* \_\_attribute\_\_((cleanup(cleanup_function)): 当一个变量的作用域消失时，便会执行后面的clean_function函数.

* \_\_attribute\_\_((packed)): 使变量或者是结构体按照最小的对齐方式，对于变量是1byte对齐，对于字段，也就是field指bit对齐.

* \_\_attribute\_\_((sentinel)) 此可变参函数需要一个NULL作为最后一个参数，这个NULL参数一般被称为哨兵参数 参考网址`http://blog.csdn.net/VermillionTear/article/details/49930651`

* \_\_attribute\_\_((always_inline)) 修饰的函数总是作为内联函数

#### 以上部分情况没有进行测试，待后续完成..