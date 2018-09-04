---
layout:     post
title:      "Gitlab and Drone"
subtitle:   " \"阿里云搭建gitlab CICD实践\""
date:       2018-09-01 12:00:00
author:     "Hanamichi"
header-img: "img/post-bg-2015.jpg"
catalog: true
tags:
    - CICD
    - devops
---

> git.hanamichi.wiki
>
> drone.hanamichi.wiki

## 环境准备

* 阿里云服务器: 2核4g

* docker服务以及docker-compose

* gitlab镜像: twang2218/gitlab-ce-zh

* drone镜像: drone:0.8和drone-agent:0.8

* 阿里云服务器设置安全组，开通80,8000,9000,443,2222端口

* 二级域名两个及证书，本人使用万网域名和万网申请的免费证书：`git.hanamichi.wiki`和`drone.hanamichi.wiki`

* 对域名设置A解析，地址为云服务器公网地址

* 云服务器打开相应端口

  ```bash
  iptables -I INPUT -p tcp --dport 80 -j ACCEPT
  iptables -I INPUT -p tcp --dport 8000 -j ACCEPT
  iptables -I INPUT -p tcp --dport 9000 -j ACCEPT
  ```

## 运行及配置

### 启动gitlab服务

```bash
docker run --detach \
    --hostname git.hanamichi.wiki \
    --publish 443:443 --publish 80:80 --publish 2222:22 \
    --name gitlab \
    --restart always \
    --volume /opt/gitlab/config:/etc/gitlab \
    --volume /opt/gitlab/logs:/var/log/gitlab \
    --volume /opt/gitlab/opt:/var/opt/gitlab \
    --volume /etc/localtime:/etc/localtime \
    twang2218/gitlab-ce-zh:latest
```

特别说明:

* 443作为https使用的端口
* 80作为web访问端口
* 2222作为ssh端口
* 映射的目录根据自己的情况修改
* 初次登陆会设置管理员账号

### 配置使用https

1. 进入gitlab容器

   `docker exec -it gitlab bash`

2. 下载域名的https证书

3. 创建ssl目录

   `mkdir -pv /etc/gitlab/ssl`

4. 讲https证书移动到`/etc/gitlab/ssl`目录

5. 编辑gitlab.rb

   ```bash
   vim /etc/gitlab/gitlab.rb
   ```

6. 在gitlab.rb中加入以下设置:

   ```bash
   external_url 'https://git.hanamichi.wiki'
   nginx['redirect_http_to_https'] = true
   nginx['ssl_certificate'] = "/etc/gitlab/ssl/214954167080416.pem"
   nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/214954167080416.key"
   ```

7. 更新配置

   `gitlab-ctl reconfigure`

### 配置gitlab系统邮箱

1. 使用管理员账户登陆gitlab

2. 在系统设置中开启注册邮箱验证功能

3. 进入gitlab容器

   `docker exec -it gitlab bash`

4. 编辑gitlab.rb并加入以下设置:

   ```bash
   gitlab_rails['smtp_enable'] = true
   gitlab_rails['smtp_address'] = "smtp.exmail.qq.com"
   gitlab_rails['smtp_port'] = 465
   gitlab_rails['smtp_user_name'] = "xxx@xxx"
   gitlab_rails['smtp_password'] = "xxx"
   gitlab_rails['smtp_authentication'] = "login"
   gitlab_rails['smtp_enable_starttls_auto'] = true
   gitlab_rails['smtp_tls'] = true
   gitlab_rails['gitlab_email_from'] = 'xxxx'
   gitlab_rails['smtp_domain'] = "exmail.qq.com"
   ```

   我是用的是腾讯企业邮箱，如使用其他邮箱，可操考[SMTP设置](https://docs.gitlab.com/omnibus/settings/smtp.html)

5. `gitlab-ctl reconfigure`

### 配置drone

1. 使用管理员账户登陆gitlab

2. 添加系统应用,位置如下图所示

   ![gitlab app](/img/in-post/post-gitlab/gitlab1.png)

   名称为应用名称drone，可自定义

   重定向url为`https://drone.hanamichi.wiki/authorize`

   Scopes选择api

3. 提交后会生成一个drone应用的id和密钥，如下图所示:

   ![gitlab app client](/img/in-post/post-gitlab/gitlab2.png)

4. 进入gitlab容器

5. 下载drone的域名证书到`/etc/gitlab/ssl/`

6. 创建nginx目录

   `mkdir -pv /etc/gitlab/nginx`

7. 创建drone的nginx配置

   `vim /etc/gitlab/nginx/drone.conf`

   ```nginx
   upstream drone{
       server 172.31.123.33:8000;
   }
   server {
       listen 80;
       listen [::]:80;
       server_name drone.hanamichi.wiki;
   
       # Redirect all HTTP requests to HTTPS with a 301 Moved Permanently response.
       return 301 https://$host$request_uri;
   }
   
   server {
       listen 443 ssl http2;
       listen [::]:443 ssl http2;
       server_name drone.hanamichi.wiki;
   
       ssl_certificate /etc/gitlab/ssl/drone.pem;
       ssl_certificate_key /etc/gitlab/ssl/drone.key;
     
       ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
   
       # HSTS (ngx_http_headers_module is required) (15768000 seconds = 6 months)
       add_header Strict-Transport-Security max-age=15768000;
   
       # OCSP Stapling ---
       # fetch OCSP records from URL in ssl_certificate and cache them
       ssl_stapling on;
       ssl_stapling_verify on;
   
       ## verify chain of trust of OCSP response using Root CA and Intermediate certs
       #ssl_trusted_certificate /etc/nginx/ssl/mritd-ca.cer;
   
       #resolver <IP DNS resolver>;
   
       location / {
   
           log_not_found on;
   
           proxy_set_header X-Forwarded-For $remote_addr;
           proxy_set_header X-Forwarded-Proto $scheme;
           proxy_set_header Host $http_host;
   
           proxy_pass http://drone;
           proxy_redirect off;
           proxy_http_version 1.1;
           proxy_buffering off;
   
           chunked_transfer_encoding off;
       }
   }
   ```

   **server的ip为阿里云服务器内网地址**

8. `gitlab-ctl reconfigure`

### 启动drone服务

使用docker-compose运行

编辑docker-compose.yml文件：

```yaml
version: '2'

services:
  drone-server:
    image: drone/drone:0.8
    container_name: drone-server
    ports:
      - 8000:8000
      - 9000:9000
    volumes:
      - /opt/drone:/var/lib/drone/
    restart: always
    environment:
      - DRONE_OPEN=true
      - DRONE_ADMIN=root,xxx,xxx
      - DRONE_HOST=https://drone.hanamichi.wiki
      - DRONE_GITLAB=true
      - DRONE_GITLAB_URL=https://git.hanamichi.wiki
      - DRONE_GITLAB_CLIENT=07261d3e62axxxxxxxxxf3213672eb88c01959
      - DRONE_GITLAB_SECRET=752137ebeb0ae6614xxxxxx65261c02788b3710e938ae2599
      - DRONE_SECRET=CYlfAtUbGesHe4O

  drone-agent:
    image: drone/agent:0.8
    container_name: drone-agent
    depends_on:
      - drone-server
    command: agent
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DRONE_SERVER=drone-server:9000
      - DRONE_SECRET=CYlfAtUbGesHe4O
```

## 验证

创建hello-world仓库，登陆drone服务，打开仓库的按钮。

在仓库中添加**.drone.yml**文件，内容如下:

```yaml
pipeline:
  build-devel:
    image: docker.io/golang:latest
    commands:
      - echo "test" 
    when:
      event: push
```

提交，在drone服务上观察结果,结果如图：

![drone](/img/in-post/post-gitlab/gitlab3.png)

