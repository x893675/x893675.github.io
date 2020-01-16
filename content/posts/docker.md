---
title: 常用容器服务构建
date: 2018-03-20T14:21:26+08:00
lastmod: 2018-03-20T14:21:26+08:00
author: hanamichi
cover: /img/docker.jpg
categories: ['容器']
tags: ['docker']
---

记录一些容器镜像的构建或服务部署

<!--more-->

- [搭建centos ssh容器](#搭建centos-ssh容器)
- [centos容器使用ss代理](#centos容器使用ss代理)
- [搭建drone服务](#搭建drone服务)

## 搭建centos ssh容器

1. `docker run -it centos bash`

2. `yum -y install openssh-server openssh-clients`

3. `ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ""`

4. `ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ""`

5. `ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""`

6. `vi /etc/ssh/sshd_config`,

   ```bash
   UsePAM no
   #UsePAM yes
   ```

7. `passwd root`

8. `docker commit containerid imagename`

9. ` docker run -d -p 10022:22 imagename /usr/sbin/sshd -D`(也可以使用-v 挂载目录到容器)

10. `ssh root@localhost -p 10022`

Dockerfile文件如下:

```dockerfile
FROM centos:7

LABEL name="work container for centos" \
      vendor="hanamichi" \
      email="x893675@gmail.com"

RUN yum -y install git && yum clean all \
    && rm -rf /var/cache/yum \
    && rm -rf /etc/yum.repos.d/*.repo \
    && cd /root && git clone https://gitee.com/x893675/dotfiles.git \
    && cp -v /root/dotfiles/centos/yum/*.repo /etc/yum.repos.d/

RUN yum -y install openssh-server openssh-clients vim wget which epel-release

RUN cd /root/dotfiles/tmux/ && bash /root/dotfiles/tmux/setup.sh \
    && cd /root/dotfiles/zsh && bash /root/dotfiles/zsh/setup.sh \
    && yum install -y the_silver_searcher && yum clean all && rm -rf /var/cache/yum

RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N "" \
    && ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N "" \
    && ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""

RUN sed -i "s/\(UsePAM \)\S*/\1yes/" /etc/ssh/sshd_config && echo "1234" | passwd --stdin root

CMD ["/usr/sbin/sshd","-D"]
```

使用dockerfile文件构建的镜像启动命令:`docker run -d -p 10022:22 imagename`

## centos容器使用ss代理

1. `yum install python python-pip -y`

2. `pip install shadowsocks`

3. 写ss代理的配置文件`vi ss.json`:

   ```json
   {
       "server":"server.....",
       "server_port":11518,
       "local_address": "127.0.0.1",
       "local_port":1080,
       "password":"password",
       "timeout":600,
       "method":"aes-256-cfb"
   }
   ```

4. `sslocal -c ss.json -d start`

5. 安装privoxy，从www.privoxy.org下载源码

6. `yum install gcc make autoconf -y`

7. 解压源码，进入源码目录

8. `useradd privoxy`

9. `autoheader && autoconf`

10.  `./configure`

11. `make && make install`

12. `vi /usr/local/etc/privoxy/config`

    ```bash
    去掉forward-socks5t那行的注视，修改地址为ss运行的本地地址，一般改为127.0.0.1:1080
    ```

13. `privoxy --user privoxy /usr/local/etc/privoxy/config`

14. `export http_proxy='http://127.0.0.1:8118'`

15. `export https_proxy='https://127.0.0.1:8118'`

16. `curl www.google.com` 有输出则表示正常

17. 也可通过`curl ip.gs`查看当前网络的代理是否正常

## 搭建drone服务

使用docker-compose.yml文件启动drone相关容器

```yaml
version: '2'

services:
  drone-server:
    image: drone/drone:0.8

    ports:
      - 8000:8000
      - 9000:9000
    volumes:
      - /root/docker/drone:/var/lib/drone/
    restart: always
    environment:
      - DRONE_OPEN=true
      - DRONE_HOST=http://localhost
      - DRONE_GOGS=true
      - DRONE_GOGS_URL=http://172.29.101.81:3000
      - DRONE_SECRET=dronepw

  drone-agent1:
    image: drone/agent:0.8

    command: agent
    restart: always
    depends_on:
      - drone-server
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DRONE_SERVER=drone-server:9000
      - DRONE_SECRET=dronepw
      
  drone-agent2:
    image: drone/agent:0.8

    command: agent
    restart: always
    depends_on:
      - drone-server
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DRONE_SERVER=drone-server:9000
      - DRONE_SECRET=dronepw
```
