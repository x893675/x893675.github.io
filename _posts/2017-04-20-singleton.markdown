---
layout:     post
title:      "单例模式的思考"
subtitle:   " \" Ｃ++单例模式宏及深思 \""
date:       2017-04-20 12:00:00
author:     "Hanamichi"
header-img: "img/post-bg-os-metro.jpg"
catalog: true
tags:
    - 技术
    - C++
---

## C++单例模式宏定义
```
//singleton.h
#ifndef SINGLETON_H_
#define SINGLETON_H_
#define DECLARE_SINGLETON(ClassName) \
	private: \
		static ClassName *singleton_; \
	public: \
		static ClassName *GetInstance(); \
		static void ReleaseInstance();
#define IMPLEMENT_SINGLETON(ClassName) \
	ClassName *ClassName::singleton_ = NULL; \
	ClassName *ClassName::GetInstance() { \
		if (singleton_ == NULL) { \
			singleton_ = new ClassName(); \
		} \
		return singleton_; \
	} \
	void ClassName::ReleaseInstance() { \
		if (singleton_ != NULL) { \
			delete singleton_; \
			singleton_ = NULL; \
		} \
	}
#endif
```

## 由单例模式引发的思考

1.**问题的引发**

在Ｃ++中，类静态函数只能访问类的静态成员变量和静态成员函数，也不能在类静态函数中使用this指针(因为类静态函数不与对象绑定，所以没有this指针)，那么单例模式中，GetInstance方法可能会调用类构造函数，而构造函数并不是静态函数，这与static的使用相违背。

2.**思考**

该说法并不一定对，只是本人的思考。

由这个问题引申的一个问题是C与C++的区别到底是什么，C是面向过程？C++是面向对象?这个区别仅仅是作为语言特性在区分，而这些语言特性仅仅是编译器做的相关限制。所以在单例模式这个问题上我认为可以做一些相关的转换思考，**所谓的类静态成员函数可以将其看做是一个普通的全局函数，只要知道其他任何函数的地址就可以访问该函数，编译器对这个全局函数做了诸多限制，简而言之就是很多函数的地址对他来说是透明的，只有编译器允许的函数地址才能访问。**
