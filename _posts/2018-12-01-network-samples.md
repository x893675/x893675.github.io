---
layout:     post
title:      "tcp理解记录"
subtitle:   " \"tcp小程序例子\""
date:       2018-12-01 12:00:00
author:     "Hanamichi"
header-img: "img/post-bg-2015.jpg"
catalog: true
tags:
    - network
---

## 长链接理解

todo...


### python并发长连接程序

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

