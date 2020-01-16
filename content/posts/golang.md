---
title: golang学习笔记
date: 2019-01-30T14:21:26+08:00
lastmod: 2019-01-30T14:21:26+08:00
author: hanamichi
cover: /img/golang.jpg
categories: ['编程语言学习']
tags: ['golang']
---

golang学习笔记及知识点记录

<!--more-->

- [golang主要特点](#golang主要特点)
- [常见应用](#常见应用)
- [可见性](#可见性)
- [import机制](#import机制)
- [指针](#指针)
- [值传递&amp;引用传递](#值传递amp引用传递)
- [数组](#数组)
- [切片](#切片)
  - [reslice](#reslice)
  - [slice常用操作](#slice常用操作)
- [map](#map)
  - [map操作](#map操作)
- [函数式编程](#函数式编程)
  - [函数变量](#函数变量)
  - [匿名函数](#匿名函数)
  - [自定义类型](#自定义类型)
  - [闭包](#闭包)
  - [接口](#接口)
- [面相对象](#面相对象)
  - [方法](#方法)
  - [接口](#接口-1)

## golang主要特点

- 类型安全 和 内存安全；
- 以非常直观和极低代价的方案实现高并发；
- 高效的垃圾回收机制（内置 runtime）；
- 快速编译（同时解决 C 语言中头文件太多的问题）；
- 为多核计算机提供性能提升的方案；
- UTF-8 编码支持；

## 常见应用

- 服务器编程：处理日志、数据打包、文件系统等；
- 分布式系统：数据库处理器，中间件等；
- 网络编程：目前使用最多最广泛的一块，Web 应用、API 应用等；
- 云平台：目前云平台逐步采用 Go 实现；

## 可见性

Go 语言中，使用大小写来决定该常量、变量、类型、接口、结构是否可以被外部所调用

* 首字母 小写 即为 `private`，
* 首字母 大写 即为 `public`。

## import机制

* 如果导入包之后未调用其中的函数或类型将会报编译错误；

* 如果一个 `main` 包导入其他包，包将被顺序导入；

* 如果导入的包依赖其他包（如：包 B）,会首先导入包 B，然后初始化包 B 中的常量和变量，最后如果包 B 中有`init` 函数，将会自动执行 `init` 函数；

* 所有包导入完成后才会对 `main` 中变量和常量进行初始化，然后执行 `main` 的 `init` 函数（如果存在），最后才会执行 `main` 函数；

* 如果一个包被导入多次，则该包只会被导入一次；

* 别名:

  ```go
  package main
  
  import io "fmt"
  
  func main(){
  	io.Println("Hello Golang")
  }
  ```

* 下划线（`_`）标识符导入包时，并不是导入整个包，而是执行该包中的 `init` 函数，因此无法通过包名来调用包中的其他函或属性。**使用下划线（`_`）操作通常是未来注册包里的引擎，外部可以方便的使用**；

## 指针

Go 语言虽然有指针，但是没有指针运算，不能对其进行加减，但可以把指针值赋给另一个指针。这也就是 Golang 中的指针与 C++ 中指针的最大区别。

> 可以通过将 `unsafe.Pointer` 转换为 `uintptr`，然后做变相指针运算。 `uintptr` 可以转换为整数。

## 值传递&引用传递

在学习引用类型语言时，我们首先要搞清楚，当给一个函数/方法传参的时候，使用的是指传递还是引用传递。实际上，大部分引用类型语言，参数为基本类型时，使用的是值传递。也就是另外复制了一份参数到当前的函数调用栈。参数为高级类型时，使用的是引用传递。这个主要是因为虚拟机的内存管理导致的。

内存管理中的内存区域一般包括 堆(heap) 和 栈(stack) 主要用来存储当前调用栈用到的简单数据类型：string、boolean、int、float 等。这些类型的内存占用小，容易回收，基本上它们的值和指针占用的空间差不多，因此可以直接复制，GC 也比较容易做针对性的优化。复杂的高级类型占用的内存往往相对较大，存储在 堆(heap) 中，GC 回收率相对较低，代价也较大，因此传 引用/指针 可以避免进行成本较高的复制操作，并且节省内存，提高程序运行效率。

因此，在以下情况下可以考虑使用指针：

1. 需要改变参数的值；
2. 避免复制操作；
3. 节省内存；

而在 Golang 中，具体到高级类型 struct，slice，map 也各有不同。实际上，只有 struct 的使用有点复杂，slice，map，chan 都可以直接使用，不用考虑是值还是指针。

## 数组

* 定义数组的格式：`var  [n]`, 其中 n >= 0；

  ```go
  package main
  
  import "fmt"
  
  func main(){
  	
  	// 定义指定长度的数组
  	var arr1 [5]int
  	fmt.Println(arr1) // [0 0 0 0 0]
  	
  	// 不设置数组长度
  	arr2 := [...]int{}
  	fmt.Println(arr2) // []
  	
  	// 定义指定长度的数组，并赋值
  	arr3 := [2]int{ 1, 5 }
  	fmt.Println(arr3) // [1 5]
  }
  ```

* 通过 `new` 关键字声明数组，返回一个指向该数组的指针；

  ```go
  package main
  
  import "fmt"
  
  func main(){
  	
  	// 通过 new 声明数组 ，返回一个指向该数组的指针
  	arr1 := new([5]int)
  	fmt.Println(arr1) // &[0 0 0 0 0]
  }
  ```

* 数组长度也是数组类型的一部分，因此具有不同长度的数组为不同类型。

* 数组是值类型: **Go 语言中的数组是值类型的，也就意味着两个相同类型的数组可以使用 `==` 或 `!=` 运算符判断两个数组是否相等，但是不能使用 `<` 或 `>` 运算符；**

  ```go
  package main
  
  import "fmt"
  
  func main(){
  	arr1 := [5]int{1, 3, 5}
  	arr2 := [5]int{2, 4, 6}
  	
  	fmt.Println(arr1 == arr2) // false
  	fmt.Println(arr1 != arr2) // true
  }
  ```

* 多维数组

  ```go
  package main
  
  import "fmt"
  
  func main() {
  	array := [2][3]int{
  		{1, 3, 5},
  		{2, 4, 6},
  	}
  	fmt.Println(array) // [[1 3 5] [2 4 6]]
  }
  ```

* 一般不直接使用数组，而是使用切片。

## 切片

`slice` 是一个通过指向数组底层，来进行变长数组的实现。

* 定义切片的格式：`var <sliceName> []<type>`

  ```go
  package main
  
  import "fmt"
  
  func main(){
      
      // 定义一个空 slice
      var slice1 []int
      fmt.Println(slice1) // []
  
      // 定义一个 slice 并赋初始值
      slice2 := []int{ 1, 3, 4 }
      fmt.Println(slice2) // [1 3 4]
  }
  ```

* 通过 `make([], len, cap)` 格式来创建 `slice`。其中，`len` 表示 `slice` 的长度，`cap` 表示 `slice` 的容量；**`cap` 的值默认情况下与 `len` 相等，`cap` 可以省略**；

  ```go
  package main
  
  import "fmt"
  
  // 通过 make 声明 切片
  func main() {
      var slice1 = make([]int, 6)
      fmt.Println(slice1) // [0 0 0 0 0 0]
      
      fmt.Println("len(slice1) = ", len(slice1)) // len(slice1) =  6
      fmt.Println("cap(slice1) = ", cap(slice1)) // cap(slice1) =  6
  }
  ```

### reslice

`reslice` 表示将一个 `slice` 再次 `slice`。

- `reslice` 与 `slice` 都是指向同一底层数组；
- `reslice` 的索引以 `slice` 的索引为准，其最大容量（cap）为 `slice` 的容量；
- 索引越界不会导致底层数组的重新分配，而是引发错误。

```go
package main

import "fmt"

func main() {
    array := [...]int{0, 1, 2, 3, 4, 5, 6, 7, 8, 9}
    
    slice1 := array[2:5]
    slice2 := slice1[0:6]

    fmt.Println("array=", array, "len=", len(array), "cap=", cap(array)) // array= [0 1 2 3 4 5 6 7 8 9] len= 10 cap= 10
    fmt.Println("slice1=", slice1, "len=", len(slice1), "cap=", cap(slice1)) // slice1= [2 3 4] len= 3 cap= 8
    fmt.Println("slice2=", slice2, "len=", len(slice2), "cap=", cap(slice2)) // slice2= [2 3 4 5 6 7] len= 6 cap= 8
}
```

### slice常用操作

* append

  * `append()` 用于在 `slice` 后最追加新的元素，这些元素保存到底层数组，并不会影响原 `slice`z，它返回变更后新的 `slice` 对象。
  * 如果追加的元素超出之前的 `slice` 容量，则重新分配数组并拷贝原数据，并不影响底层数组。

  ```go
  package main
  
  import "fmt"
  
  func main() {
      array := [...]int{0, 1, 2, 3}
  
      slice := array[:2]
      fmt.Printf("%p %v, cap = %d\n", slice, slice, cap(slice)) // 0xc42001c160 [0 1], cap = 4
      
      slice = append(slice, 10)
      fmt.Printf("%p %v\n", &array, array) // 0xc42001c160 [0 1 10 3] cap = 4
      fmt.Printf("%p %v, cap = %d\n", slice, slice, cap(slice)) // 0xc42001c160 [0 1 10], cap = 4
      
      slice = append(slice, 15, 20)
      fmt.Printf("%p %v cap = %d \n", &array, array, cap(array)) // 0xc42001c160 [0 1 10 3] cap = 4
      fmt.Printf("%p %v, cap = %d\n", slice, slice, cap(slice)) // 0xc420012240 [0 1 10 15 20], cap = 8
  }
  
  ```

* copy

  *  `copy(目标 slice， 被拷贝的 slice)`，用于拷贝 `slice`，返回值为拷贝的个数。

  ```go
  package main
  
  import "fmt"
  
  func main() {
      sliceA := []int{1, 2, 3, 4, 5}
      sliceB := []int{5, 4}
      
      copyCount := copy(sliceA, sliceB)
      
      fmt.Println(copyCount) // 2
      
      fmt.Println(sliceA) // [5 4 3 4 5]
      fmt.Println(sliceB) // [5 4]
  }
  ```

## map

`map` 是一个无序的键值对数据集合，通过 `key` 快速检索数据。

* 通过 `map[keyType]valueType` 格式声明 `Map`；

  ```go
  package main
  
  import "fmt"
  
  func main(){
      // 声明一个空的 map
      m1 := map[int]string{}
      fmt.Println(m1) // map[]
  
      // 声明一个 map 并赋初始值
      m2 := map[int]string{ 0: "Java", 1: "C#", 2: "Python", 3: "Golang" }
      fmt.Println(m2) // map[3:Golang 0:Java 1:C# 2:Python]
  }
  ```

* 通过 `make(map[keyType]ValueType, cap)` 格式声明 `Map`；**其中 `cap` 表示容量，可以省略，当 `Map` 超过设置的容量时，会自动扩展**；

  ```go
  package main
  
  import "fmt"
  
  func main() {
  	m := make(map[int]string, 3)
  	m[0] = "Java"
  	m[1] = "C#"
  	m[2] = "Python"
  
  	fmt.Println(m, len(m)) // map[1:C# 2:Python 0:Java] 3
  
  	m[3] = "Golang"
  	fmt.Println(m, len(m)) // map[0:Java 1:C# 2:Python 3:Golang] 4
  }
  ```

* `map` 的 `key` 必须是支持 `==` 或 `!=` 比较运算符的数据类型。

* 遍历map

  ```go
  func main() {
      m2 := map[int]string{0: "Java", 1: "C#", 2: "Python", 3: "Golang"}
      
      for key, value := range m2 {
          fmt.Println(key, ":", value)
      }
  }
  ```

* 嵌套map

  ```go
  func main() {
      var array = [...]string{"Java", "C#", "Python", "Golang"}
      
     // 声明一个 嵌套 map 父级 key  类型为 int，value 为map
      m := make(map[int]map[string]int)
      
      for i, value := range array {
         // 判断嵌套的 map 是否初始化
          _, isMake := m[i][value]
          if !isMake {
              // 对嵌套的 map 初始化
              m[i] = make(map[string]int)
          }
          m[i][value] = i
      }
      
      fmt.Println(m) // map[0:map[Java:0] 1:map[C#:1] 2:map[Python:2] 3:map[Golang:3]]
  }
  ```

### map操作

* 取值

  * 可以直接通过 `map[key]` 的方式取 `Map` 中的值，当 `key` 值不存在时，则会返回一个 `value` 的初始值；

  ```go
  func main() {
      m1 := map[string]int{"Golang": 20, "Java": 30, "C#": 40}
      fmt.Println(m1["Python"]) // 0
  }
  ```

  * 实际上， `map[key]` 有两个返回值，一个是根据 `key` 返回的值，另一个则是用于判断 `key` 是否存在

  ```go
  func main() {
      m1 := map[string]int{"Golang": 20, "Java": 30, "C#": 40}
      if _, isExist := m1["Python"]; !isExist {
      	m1["Python"] = 10
      }
      fmt.Println(m1) // map[C#:40 Python:10 Golang:20 Java:30]
  }
  ```

* 删除map数据

  * 使用 `delete(map, key)` 方法删除 `Map` 中的数据

  ```go
  func main(){
      m1 := map[string]int{"Golang": 20, "Java": 30, "C#": 40}
      fmt.Println(m1) // map[Golang:20 Java:30 C#:40] 
      delete(m1, "Java")
      fmt.Println(m1) // map[Golang:20 C#:40]
  }
  ```

## 函数式编程

在 Go 语言中函数是一等公民，它作为一个变量、类型、参数、返回值，甚至可以去实现一个接口,但是 Go 语言中函数不支持重载、嵌套和默认参数。

### 函数变量

```go
func test(){
    // 函数体
}

funcTest := test

fmt.Println(funcTest())
```

### 匿名函数

```go
test := func(){
    // 函数体
}
```

### 自定义类型

```go
package main

import "fmt"

type iAdder func(int, int) int

func main(){
	var adder iAdder = func(a int, b int) int {
		return a + b
	}
	
	fmt.Println(adder(1,2)) // 3
}
```

### 闭包

```go
package main

import "fmt"

// 使用 闭包实现 斐波那契数列
func fibonacci() func() int {
	a, b := 0, 1

	return func() int {
		a, b = b, a +b
		return a
	}
}

func main(){
	f := fibonacci()

	fmt.Println(f()) // 1
	fmt.Println(f()) // 1
	fmt.Println(f()) // 2
	fmt.Println(f()) // 3
	fmt.Println(f()) // 5
}
```

### 接口

```go
package main

import (
	"fmt"
	"io"
	"bufio"
	"strings"
)

// 使用 闭包实现 斐波那契数列
func fibonacci() intGen {
	a, b := 0, 1
	return  func() int {
		a, b = b, a + b
		return a
	}
}

// 定义一个类型
type intGen func() int

// 实现一个 Reader 接口
func (g intGen) Read(p []byte) (n int, err error) {
	// 获取下一个元素值
	next := g()
	if next > 10000 {
		return  0, io.EOF
	}
	// 将一个数值转为字符串
	s := fmt.Sprintf("%d/n", next)
	return strings.NewReader(s).Read(p)
}

// 使用 Reader 读取的方法
func printFileContents(reader io.Reader){
	scanner := bufio.NewScanner(reader)
	for scanner.Scan()  {
		fmt.Println(scanner.Text())
	}
}


func main(){
	f := fibonacci()
	
	printFileContents(f)
}
```

## 面相对象

Go 语言的面向对象非常简单，**仅支持封装，不支持继承和多态。继承和多态是在接口中实现的。**

Go 语言中没有 `class`，而是通过 `struct（结构体）` 对相同类型或不同类型的数据进行封装。

### 方法

Go 语言中的方法从某种意义上来说就是函数的语法糖，`receiver` 作为方法的第一个强制类型参数传入，这也就是 `Method Value` 与 `Method Expression` 的区别。

```go
package main

import "fmt"

type Student struct {
	Name string
}

// receiver 定义结构方法
func (student Student) SayHi(){
	fmt.Println("Hello! My name's", student.Name)
}

func main(){

	student := Student{"test"}

	// 使用 Method Value 方式调用方法
	student.SayHi() // Hello! My name's test
	
	// 使用 Method Expression 方法调用方法
	(Student).SayHi(student) // Hello! My name's test
}
```

因此想通过方法去改变结构体的值，仍然需要传递指针；

```go
package main

import "fmt"

type User struct {
	Name     string
	Age      int
	IsActive bool
}

func (user *User) setName(name string){
	user.Name = name
}

func main(){
	test := User{Name: "jason", Age: 18, IsActive: true}
	fmt.Println(test.Name) // jason
	
	test.setName("test")
	fmt.Println(test.Name) // test
}
```

- Go 中不存在方法重载；
- 如果外部结构和内嵌结构存在同名方法，则优先调用外部结构的方法；

### 接口

接口就是方法签名的集合，接口只有声明，没有实现，没有数据字段。

* **只要某个类型拥有了该接口的所有方法，即该类型就算实现了该接口**，无需显式声明实现了哪个接口，这被称为 `Structurol Typing`；
* **Go 允许不带任何方法签名的接口，这种类型的接口被称为 `empty interface`**，按照第一条结论，**只要某个类型拥有了某个接口的所有方法，那么该类型就实现了该接口**，所以所有类型都实现了 `empty interface`；
* **当对象赋值给接口时，会发生拷贝。接口内部存储的是指向这个复制品的指针，无法修改其状态，也无法获取指针**；
* 接口可以作为任何类型数据的容器。
