---
title: client-go详解
date: 2020-10-07T14:21:26+08:00
lastmod: 2021-02-28T12:00:00+08:00
author: hanamichi
cover: /img/client-go.jpg
categories: ['云原生']
tags: ['kubernetes']
---

client-go中informer list&watch机制

<!--more-->

- [clien-go结构原理图示](#clien-go结构原理图示)
- [informer](#informer)
  - [informer组件](#informer组件)
  - [informer 整体工作流程](#informer-整体工作流程)
  - [流程实例](#流程实例)
- [controller工作流程](#controller工作流程)
- [kubernetes API 约定](#kubernetes-api-约定)
  - [Spec and Status](#spec-and-status)
  - [**Primitive types**](#primitive-types)

## clien-go结构原理图示

![](/img/inpost/client-go/client-go-1.png)

![](/img/inpost/client-go/client-go-2.jpeg)

kubernetes里面的apiserver的只负责数据的CRUD接口实现，并不负责业务逻辑的处理，所以k8s中就通过外挂controller通过对应资源的控制器来负责事件的处理。而controller和apiserver之前的桥梁就是 informer

apiserver本质上就是一个http的rest接口实现，watch机制则也是基于http协议，不过不同于一般的get其通过chunk机制，来实现消息的通知。

![](/img/inpost/client-go/client-go-3.png)

![](/img/inpost/client-go/client-go-4.png)

## informer

Informer模块是Kubernetes中的基础组件，负责各组件与Apiserver的资源与事件同步。

List/Watch机制是Kubernetes中实现集群控制模块最核心的设计之一，它采用统一的异步消息处理机制，保证了消息的实时性、可靠性、顺序性和性能等，为声明式风格的API奠定了良好的基础。

Informer依赖Kubernetes的List/Watch API。 通过Lister()对象来List/Get对象时，Informer不会去请求Kubernetes API，而是直接查询本地缓存，减少对Kubernetes API的直接调用。

Informer 只会调用 Kubernetes List 和 Watch 两种类型的 API。Informer 在初始化的时，先调用 Kubernetes List API 获得某种 resource 的全部 Object，缓存在内存中; 然后，调用 Watch API 去 watch 这种 resource，去维护这份缓存; 最后，Informer 就不再调用 Kubernetes 的任何 API。

### informer组件

- Controller:  并不是 Kubernetes Controller，这两个 Controller 并没有任何联系
- Reflector：通过Kubernetes Watch API监听resource下的所有事件
- Lister：用来被调用List/Get方法
- Processor：记录并触发回调函数, Processor 中记录了所有的回调函数实例(即 ResourceEventHandler 实例)
- DeltaFIFO: 一个增量队列，将 Reflector 监控变化的对象形成一个 FIFO 队列，此处的 Delta 就是变化；
- LocalStore: 就是 informer 的 cache，这里面缓存的是 apiserver 中的对象(其中有一部分可能还在DeltaFIFO 中)，此时使用者再查询对象的时候就直接从 cache 中查找，减少了 apiserver 的压力，LocalStore 只会被 Lister 的 List/Get 方法访问。

### informer 整体工作流程

- Reflector使用ListAndWatch方法，先从apiserver中list某类资源的所有实例，拿到对象的最新版本，然后用watch方法监听该resourceversion之后的所有变化，*若中途出现异常，reflector则会从断开的resourceversion处重新监听所有变化* 一旦有Add、Del、Update动作，Reflector会收到更新通知，该事件及它所对应的API对象这个组合，被称为增量Delta,它会被放进DeltaFIFO中
- Informer会不断从这个DeltaFIFO中读取增量，每拿出一个对象，Informer就会判断这个增量的事件类型，然后创建或更新本地的缓存。
- DeltaFIFO再pop这个事件到controller中，controller会调用事先注册到ResourceEventHandler回调函数进行处理。

![informer](/img/inpost/client-go/informer.png)

在k8s中一些控制器可能会关注多种资源，比如Deployment可能会关注Pod和replicaset，replicaSet可能还会关注Pod，为了避免每个控制器都独立的去与apiserver建立链接，k8s中抽象了sharedInformer的概念，即共享的informer, 针对同一资源只建立一个链接。由工厂方法 sharedInformerFactor 创建，内部维护了一个informer的map， 当存在某种资源的 informer 时，会直接返回。

因为彼此共用informer,但是每个组件的处理逻辑可能各不相同，在informer中通过观察者模式，各个组件可以注册一个EventHandler来实现业务逻辑的注入

![](/img/inpost/client-go/client-go-5.png)

### 流程实例

以 Pod 为例，详细说明一下 Informer 的关键逻辑：

1. Informer 在初始化时，Reflector 会先 List API 获得所有的 Pod
2. Reflect 拿到全部 Pod 后，会将全部 Pod 放到 Store 中
3. 如果有人调用 Lister 的 List/Get 方法获取 Pod， 那么 Lister 会直接从 Store 中拿数据
4. Informer 初始化完成之后，Reflector 开始 Watch Pod，监听 Pod 相关 的所有事件;如果此时 pod_1 被删除，那么 Reflector 会监听到这个事件
5. Reflector 将 pod_1 被删除 的这个事件发送到 DeltaFIFO
6. DeltaFIFO 首先会将这个事件存储在自己的数据结构中(实际上是一个 queue)，然后会直接操作 Store 中的数据，删除 Store 中的 pod_1
7. DeltaFIFO 再 Pop 这个事件到 Controller 中
8. Controller 收到这个事件，会触发 Processor 的回调函数

![](/img/inpost/client-go/client-go-6.png)

## controller工作流程

1. 创建一个控制器
   * 为控制器创建 workqueue
   * 创建 informer, 为 informer 添加 callback 函数，创建 lister
2. 启动控制器
   * 启动 informer
   * 等待本地 cache sync 完成后， 启动 workers
3. 当收到变更事件后，执行 callback 
   * 等待事件触发
   * 从事件中获取变更的 Object
   * 做一些必要的检查
   * 生成 object key，一般是 namespace/name 的形式
   * 将 key 放入 workqueue 中
4. worker loop
   * 等待从 workqueue 中获取到 item，一般为 object key
   * 用 object key 通过 lister 从本地 cache 中获取到真正的 object 对象
   * 做一些检查
   * 执行真正的业务逻辑
   * 处理下一个 item

## kubernetes API 约定

### Spec and Status

- Spec 表示系统希望到达的状态，Status 表示系统目前观测到的状态。
- PUT 和 POST 的请求中应该把 Status 段的数据忽略掉，Status 只能由系统组件来修改。
- 有一些对象可能跟 Spec 和 Status 模型相去甚远，可以吧 Spec 改成更加适合的名字。
- 如果对象符合 Spec 和 Status 的标准的话，那么除了 type，object metadata 之外不应该有其他顶级的字段。
- Status 中 phase 已经是 deprecated。因为 pahse 本质上是状态机的枚举类型，它不太符合 Kubernetes 系统设计原则， 并且阻碍系统发展，因为每当你需要往里面加一个新的 pahse 的时候你总是很难做到向后兼容性，建议使用 Condition 来代替。

### **Primitive types**

- 避免使用浮点数，永远不要在 Spec 中使用它们，浮点数不好规范化，在不同的语言和计算机体系结构中有 不同的精度和表示。
- 在 JavaScript 和其他的一部分语言中，所有的数字都会被转换成 float，所以数字超过了一定的大小最好使 用 string。
- 不要使用 unsigned integers，因为不同的语言和库对它的支持不一样。
- 不要使用枚举类型，建立一个 string 的别名类型。
- API 中所有的 integer 都必须明确使用 Go（int32, int64）, 不要使用 int，在32位和64位的操作系统中他们的位数不一样。
- 谨慎地使用 bool 类型的字段，很多时候刚开始做 API 的时候是 true or false，但是随着系统的扩张，它可能 有多个可选值，多为未来打算。
- 对于可选的字段，使用指针来表示，比如 *string *int32 , 这样就可以用 nil 来判断这个值是否设置了， 因为 Go 语言中string int 这些类型都有零值，你无法判断他们是没被设置还是被设置了零值。