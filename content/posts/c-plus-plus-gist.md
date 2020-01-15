---
title: C++单例模式与线程类思考
date: 2017-04-20T14:21:26+08:00
lastmod: 2017-04-20T14:21:26+08:00
author: hanamichi
cover: /img/c-plus-plus-gist.jpg
categories: ['编程语言学习']
tags: ['c++']
---

C++代码片段研究

* 单例模式研究
* 自旋锁 

<!--more-->

- [C++单例模式宏定义](#c单例模式宏定义)
- [由单例模式引发的思考](#由单例模式引发的思考)
- [thread类与自解锁的封装](#thread类与自解锁的封装)

## C++单例模式宏定义

```c++
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


## thread类与自解锁的封装

1.**thread.h**
```c++
//thread.h
#include <pthread.h>
#include <unistd.h>
class Mutex
{
public:
    Mutex(bool init = false);
    ~Mutex();
    bool Init();
    void Destroy();
    bool TryLock();
    bool Lock();
    bool Unlock();
private:
    bool initialized_;
    pthread_mutex_t	mutex_;
};
inline bool Mutex::Init()
{
    if (!initialized_)
    {
        initialized_ = (pthread_mutex_init(&mutex_, NULL) == 0);
    }
    return initialized_;
}
inline void Mutex::Destroy()
{
    if (initialized_)
    {
        pthread_mutex_destroy(&mutex_);
        initialized_ = false;
    }
}
inline bool Mutex::TryLock()
{
    return pthread_mutex_trylock(&mutex_) == 0;//函数成功返回0，其他任何值都错误,非阻塞的LOCK方式
}
inline bool Mutex::Lock()
{
    return pthread_mutex_lock(&mutex_) == 0;//阻塞lock方式
}
inline bool Mutex::Unlock()
{
    return pthread_mutex_unlock(&mutex_) == 0;
}
class MutexScopedLocker
{
public:
    MutexScopedLocker(Mutex &mutex, bool initialLock = true) : mutex_(mutex), locked_(false)
    {
        if (initialLock)
        {
            Lock();
        }
    }
    ~MutexScopedLocker()
    {
        Unlock();
    }
    void Lock()
    {
        if (!locked_)
        {
            mutex_.Lock();
            locked_ = true;
        }
    }
    void Unlock()
    {
        if (locked_)
        {
            mutex_.Unlock();
            locked_ = false;
        }
    }
private:
    Mutex	&mutex_;
    bool	locked_;
};
class Thread;
class Runnable
{
public:
    Runnable();
    virtual ~Runnable();
    virtual void Run(Thread *thread) = 0;
};
class Thread
{
public:
    enum
    {
        PRIORITY_REALTIME = 49,
        PRIORITY_HIGH = 30,
        PRIORITY_NORMAL = 10,
        PRIORITY_LOW = 1
    };
    Thread();
    virtual ~Thread();
    static void Sleep(int milliseconds);
    void Interrupt();
    void Kill();
    void Join();
    bool IsInterrupted() const;
    template <typename T>
    bool Run(void (T::*method)(Thread *thread), T *instance, int priority = Thread::PRIORITY_NORMAL);
    bool IsAlive() const;
private:
    bool interrupted_;
    bool alive_;
    pthread_t thread_;
    Runnable *runnable_;
    void Run();
    static void *ThreadProc(void *arg);
};
inline void Thread::Sleep(int milliseconds)
{
    usleep(milliseconds * 1000);
}
inline void Thread::Interrupt()
{
    interrupted_ = true;
}
inline bool Thread::IsInterrupted() const
{
    return interrupted_;
}
inline bool Thread::IsAlive() const
{
    return alive_;
}
template <typename T>
class RunnableMethod : public Runnable
{
public:
    RunnableMethod(void (T::*method)(Thread *), T *instance);
    void Run(Thread *thread);
private:
    void (T::*method_)(Thread *);
    T *instance_;
};
template <typename T>
RunnableMethod<T>::RunnableMethod(void (T::*method)(Thread *), T *instance)
    : method_(method)
    , instance_(instance)
{
}
template <typename T>
void RunnableMethod<T>::Run(Thread *thread)
{
    (instance_->*method_)(thread);
}
template <typename T>
bool Thread::Run(void (T::*method)(Thread *thread), T *instance, int priority/* = Thread::PRIORITY_NORMAL*/)
{
    if (alive_)
    {
        return false;
    }
    if (runnable_ != NULL)
    {
        delete runnable_;
    }
    runnable_ = new RunnableMethod<T>(method, instance);
    alive_ = true;
    interrupted_ = false;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setinheritsched(&attr, PTHREAD_EXPLICIT_SCHED);
#ifndef MOCK_RUN
    pthread_attr_setschedpolicy(&attr, SCHED_FIFO);
#endif
    sched_param param;
    param.sched_priority = priority;
    pthread_attr_setschedparam(&attr, &param);
    if (pthread_create(&thread_, &attr, ThreadProc, this) != 0)
    {
        //LOG_FATAL("Thread", "pthread_create failed");
        alive_ = false;
    }
    pthread_attr_destroy(&attr);
    int policy;
    if (pthread_getschedparam(thread_, &policy, &param) != 0)
    {
        //LOG_ERROR("Thread", "pthread_getschedparam failed");
    } else {
       // LOG_DEBUG("Thread", "new thread:%ul;policy:%d;priority:%d", thread_, policy, param.sched_priority);
    }
    return alive_;
}
```

2.**thread.cpp**

```c++
//thread.cpp
#include "thread.h"
#include <signal.h>
Mutex::Mutex(bool init/* = false*/)
    : initialized_(false)
{
    if (init)
    {
        Init();
    }
}
Mutex::~Mutex()
{
    Destroy();
}
Runnable::Runnable()
{
}
Runnable::~Runnable()
{
}
Thread::Thread()
    : interrupted_(false)
    , alive_(false)
    , thread_(0)
    , runnable_(NULL)
{
}
Thread::~Thread()
{
    Join();
    if (runnable_ != NULL)
    {
        delete runnable_;
    }
}
void Thread::Kill()
{
    if (alive_)
    {
        pthread_kill(thread_, 0);
    }
    alive_ = false;
}
void Thread::Join()
{
    if (alive_)
    {
        void *result = NULL;
        pthread_join(thread_, &result);
        pthread_detach(thread_);
        thread_ = 0;
    }
    alive_ = false;
}
void Thread::Run()
{
    runnable_->Run(this);
}
void *Thread::ThreadProc(void *arg)
{
    ((Thread *)arg)->Run();
    return NULL;
}
```
