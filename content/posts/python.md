---
title: python code gist
date: 2018-06-30T14:21:26+08:00
lastmod: 2018-06-30T14:21:26+08:00
author: hanamichi
cover: /img/python.jpg
categories: ['编程语言学习']
tags: ['python']
---

记录一些python的代码片段

<!--more-->

- [python并发长连接程序](#python并发长连接程序)
  - [server](#server)
  - [client](#client)

## python并发长连接程序

### server
```python
# server.py
import time
import gevent
from gevent import socket,monkey
monkey.patch_all()

def server(port):
    s = socket.socket()
    s.bind(('0.0.0.0', port))
    s.listen(500)
    while True:
        cli, addr = s.accept()
        gevent.spawn(handle_request, cli)

def handle_request(conn):
    try:
        while True:
            data = conn.recv(1024)
            print("recv:", data)
            conn.send(data)
            if not data:
                conn.shutdown(socket.SHUT_WR)
    except Exception as ex:
        print (ex)
    finally:
        conn.close()

if __name__ == '__main__':
    server(8001)
```

### client

```python
#client.py
import time
import gevent

from gevent import socket,monkey
monkey.patch_all()

def handle_request(i):
    s = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
    s.connect(('localhost',8001))
    while True:
        msg = "client " + str(i) + " send msg\n"
        s.sendall(msg)
        data = s.recv(1024)
        print ('Received', repr(data))
        time.sleep(5)
    s.close()

if __name__ == '__main__':
    threads = [gevent.spawn(handle_request,i) for i in range(10)]
    gevent.joinall(threads)
```