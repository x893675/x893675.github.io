---
layout:     post
title:      OpenStack 
subtitle:   " \"OpenStack安装部署\""
date:       2018-02-10 12:00:00
author:     "Hanamichi"
header-img: "img/spacex-5.jpg"
catalog: true
tags:
    - openstack
    - 云计算

---
# openstack环境搭建

openstack版本:ocata

## 使用devstack搭建

### 系统安装

安装 Ubuntu 16.04，并配置 eth0 的 IP：

* devstack-controller  192.168.104.10
* devstak-compute    192.168.104.11

ip根据自己的环境更改

### 下载代码

1. apt-get install git -y
2. git clone https://git.openstack.org/openstack-dev/devstack -b stable/ocata

### 创建stack用户

1. mv devstack /opt/stack
2. chown -R stack:stack /opt/stack/devstack
3. ./devstack/tools/create-stack-user.sh
4. su – stack
5. cd devstack

### 编写配置文件

在 /opt/stack/devstack 目录下，创建 local.conf

#### *devstack-controller*

```bash
[[local|localrc]]

MULTI_HOST=true
HOST_IP=192.168.1.10
LOGFILE=/opt/stack/logs/stack.sh.log


ADMIN_PASSWORD=admin
MYSQL_PASSWORD=secret
RABBIT_PASSWORD=secret
SERVICE_PASSWORD=secret
SERVICE_TOKEN=abcdefghijklmnopqrstuvwxyz

disable_service n-net
enable_service q-svc,q-agt,q-dhcp,q-l3,q-meta,neutron,q-lbaas,q-fwaas,q-vpn
Q_AGENT=linuxbridge
ENABLE_TENANT_VLANS=True
TENANT_VLAN_RANGE=3001:4000
PHYSICAL_NETWORK=default

LOG_COLOR=False
LOGDIR=$DEST/logs
SCREEN_LOGDIR=$LOGDIR/screen

GIT_BASE=http://git.trystack.cn
NOVNC_REPO=http://git.trystack.cn/kanaka/noVNC.git
SPICE_REPO=http://git.trystack.cn/git/spice/spice-html5.git
```

#### *devstack-compute*

```bash
[[local|localrc]]

MULTI_HOST=true
HOST_IP=192.168.1.11


ADMIN_PASSWORD=admin
MYSQL_PASSWORD=secret
RABBIT_PASSWORD=secret
SERVICE_PASSWORD=secret
SERVICE_TOKEN=abcdefghijklmnopqrstuvwxyz


SERVICE_HOST=192.168.1.10
MYSQL_HOST=$SERVICE_HOST
RABBIT_HOST=$SERVICE_HOST
GLANCE_HOSTPORT=$SERVICE_HOST:9292
Q_HOST=$SERVICE_HOST
KEYSTONE_AUTH_HOST=$SERVICE_HOST
KEYSTONE_SERVICE_HOST=$SERVICE_HOST

CEILOMETER_BACKEND=mongodb
DATABASE_TYPE=mysql

ENABLED_SERVICE=n-cpu,q-agt,neutron
Q_AGENT=linuxbridge
ENABLE_TENANT_VLANS=True
TENANT_VLAN_RANGE=3001:4000
PHYSICAL_NETWORK=default

NOVA_VNC_ENABLED=True
NOVNCPROXY_URL="http://$SERVICE_HOST:6080/vnc_auto.html"
VNCSERVER_LISTEN=$HOST_IP
VNCSERVER_PROXYCLIENT_ADDRESS=$VNCSERVER_LISTEN

LOG_COLOR=False
LOGDIR=$DEST/logs
SCREEN_LOGDIR=$LOGDIR/screen


GIT_BASE=http://git.trystack.cn
NOVNC_REPO=http://git.trystack.cn/kanaka/noVNC.git
SPICE_REPO=http://git.trystack.cn/git/spice/spice-html5.git
```

### 开始部署

在两个节点上分别执行`./stack.sh`

## Centos7 Ocata单节点部署

**系统信息**：centos7, 3.10.0-514.el7.x86_64

**配置信息**：2核，4g内存虚拟机

**网络配置**：

1. 内部ip:10.0.2.4/24(虚拟机nat网卡，openstack专用)
2. 外部ip:192.168.1.254/24(虚拟机桥接网卡，远端访问虚拟机用)

### 配置hosts

1. `vim /etc/hosts`,添加以下内容：

   ```bash
   10.0.2.4   openstack-test
   ```


2. `hostnamectl set-hostname openstack-test`

### 安装和配置NTP服务

1. `yum install chrony`

2. `vim  /etc/chrony.conf`，添加以下内容：

   ```bash
   server 10.0.2.4 iburst

   allow  10.0.0.0/243.
   ```

3. `systemctl enable chronyd.service`

4. `systemctl start chronyd.service`

5. `chronyc sources`

### 安装openstack软件包

1. `yum install centos-release-openstack-ocata`
2. `yum upgrade`
3. `yum install python-openstackclient`
4. `yum install openstack-selinux`

### SQL数据库安装配置

1. `yum install mariadb mariadb-server python2-PyMySQL`

2. `vim /etc/my.cnf.d/openstack.cnf`,添加以下内容:

   ```bash
   [mysqld]
   bind-address = 10.0.2.4

   default-storage-engine = innodb
   innodb_file_per_table = on
   max_connections = 4096
   collation-server = utf8_general_ci
   character-set-server = utf8
   ```

3. `systemctl enable mariadb.service`

4. `systemctl start mariadb.service`

5. `mysql_secure_installation`


### 消息队列安装配置

1. `yum install rabbitmq-server -y`
2. `systemctl enable rabbitmq-server.service`
3. `systemctl start rabbitmq-server.service`
4. `rabbitmqctl add_user openstack RABBIT_PASS`,  替换RABBIT_PASS
5. `rabbitmqctl set_permissions openstack ".*" ".*" ".*"`

### MemCached安装配置

1. `yum install memcached python-memcached -y`

2. `vim /etc/sysconfig/memcached`, 更改**OPTION**的值:

   ```bash
   OPTIONS="-l 127.0.0.1,::1,openstack-test"
   ```

3. `systemctl enable memcached.service`

4. `systemctl start memcached.service`

### 安装配置keystone服务

#### *安装keystone服务*

1. 登陆mysql,创建keystone表，然后配置权限信息

   ```sql
   mysql -u root -p

   CREATE DATABASE keystone;

   GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'openstack-test' \ 
   IDENTIFIED BY 'KEYSTONE_DBPASS';

   GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' \
   IDENTIFIED BY 'KEYSTONE_DBPASS';

   # 替换KEYSTONE_DBPASS的值
   ```

2. `yum install openstack-keystone httpd mod_wsgi -y`

3. `vim /etc/keystone/keystone.conf`

   1. 更改**[database]**字段,`connection = mysql+pymysql://keystone:KEYSTONE_DBPASS@openstack-test/keystone`
   2. 更改[**token]**字段，`provider = fernet`

4. `su -s /bin/sh -c "keystone-manage db_sync" keystone`

5. `keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone`

6. `keystone-manage credential_setup --keystone-user keystone --keystone-group keystone`

7. `keystone-manage bootstrap --bootstrap-password 0000 --bootstrap-admin-url http://openstack-test:35357/v3/ --bootstrap-internal-url http://openstack-test:5000/v3/ --bootstrap-public-url http://openstack-test:5000/v3/ --bootstrap-region-id RegionOne`

8. `vim /etc/httpd/conf/httpd.conf`

   1. 更改**ServerName**,`ServerName openstack-test`

9. `ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/`

10. `systemctl enable httpd.service`

11. `systemctl start httpd.service`

12. `vim admin-openrc`

    ```bash
    export OS_USERNAME=admin
    export OS_PASSWORD=0000
    export OS_PROJECT_NAME=admin
    export OS_USER_DOMAIN_NAME=Default
    export OS_PROJECT_DOMAIN_NAME=Default
    export OS_AUTH_URL=http://openstack-test:35357/v3
    export OS_IDENTITY_API_VERSION=3
    ```

13. `openstack project create --domain default --description "Service Project" service`

    ```bash
    +-------------+----------------------------------+
    | Field       | Value                            |
    +-------------+----------------------------------+
    | description | Service Project                  |
    | domain_id   | default                          |
    | enabled     | True                             |
    | id          | 03d72654a51f46e6bcded324c435aba0 |
    | is_domain   | False                            |
    | name        | service                          |
    | parent_id   | default                          |
    +-------------+----------------------------------+
    ```

14. `openstack project create --domain default --description "Demo Project" demo`

    ```bash
    +-------------+----------------------------------+
    | Field       | Value                            |
    +-------------+----------------------------------+
    | description | Demo Project                     |
    | domain_id   | default                          |
    | enabled     | True                             |
    | id          | 4535eaa96f7e486cb7ed76ccdba3b299 |
    | is_domain   | False                            |
    | name        | demo                             |
    | parent_id   | default                          |
    +-------------+----------------------------------+
    ```

15. `openstack user create --domain default --password-prompt demo`

    ```bash
    User Password:
    Repeat User Password:
    +---------------------+----------------------------------+
    | Field               | Value                            |
    +---------------------+----------------------------------+
    | domain_id           | default                          |
    | enabled             | True                             |
    | id                  | 86d3be005e3446f296031e2676681254 |
    | name                | demo                             |
    | options             | {}                               |
    | password_expires_at | None                             |
    +---------------------+----------------------------------+
    ```

16. `openstack role create user`

    ```bash
    +-----------+----------------------------------+
    | Field     | Value                            |
    +-----------+----------------------------------+
    | domain_id | None                             |
    | id        | 54efbbb24eb6423f890433cd8c7c32e4 |
    | name      | user                             |
    +-----------+----------------------------------+
    ```

17. `openstack role add --project demo --user demo user`


#### *验证keystone服务配置*

1. `vim /etc/keystone/keystone-paste.ini`

   1. 在**[pipeline:public_api]**，**[pipeline:admin_api]**，**[pipeline:api_v3]**三个字段中删除**admin_token_auth**

2. `unset OS_AUTH_URL OS_PASSWORD`

3. `openstack --os-auth-url http://openstack-test:35357/v3 --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin token issue`

   ```bash
   Password:
   +------------+------------------------------------------------------------------------+
   | Field      | Value                                                                                               |
   +------------+------------------------------------------------------------------------+
   | expires    | 2018-01-30T03:55:16+0000                                                                            |
   | id         | gAAAAABab96UP3Z6xiskBWYBmxC2GqzqyJSYrMS2lwh4d7wUahw4ZgUtmLRuisOonOM7UwuIgVXNc8McplbYjCT4U0fgli8Wxoe |
   |            | mlX5G3KMDp5P2gl8MVzRJlNc0ICcXvTIWl8HuFh06g-yHWP6VNEWeTrDraXUopQ2s6vXJlRAwhPAK2DbRRMQ                |
   | project_id | 054c9f9780b646e084d0072abc8b51e4                                                                    |
   | user_id    | 8185efd192444c7180cca5c481f41f1e                                                                    |
   +------------+-----------------------------------------------------------------------------------------------------+
   ```

4. `openstack --os-auth-url http://openstack-test:5000/v3 --os-project-domain-name default --os-user-domain-name default  --os-project-name demo --os-username demo token issue`

   ```bash
   +------------+--------------------------------------------------------------------------------------------------------------------+
   | Field      | Value                                                                                                              |
   +------------+--------------------------------------------------------------------------------------------------------------------+
   | expires    | 2018-01-30T03:57:52+0000                                                                                           |
   | id         | gAAAAABab98wlr0bUa4KfG6lzl5qE1vbk5PL7_qUAwqwzm1IqJzWo2h4nQkX4UevslLVwYL_v9zNoqwyNd0UNRy_I3NYaErFe6ysSDyVxV_L1AP66G |
   |            | JjCY1lr1Vht3p0su7EU5kQedDecB_CEIr9AFJZhIP2Vonw4A042PajHaL7a_1-6cUmLMg                                              |
   | project_id | 4535eaa96f7e486cb7ed76ccdba3b299                                                                                   |
   | user_id    | 86d3be005e3446f296031e2676681254                                                                                   |
   +------------+--------------------------------------------------------------------------------------------------------------------+
   ```

#### *创建用户环境变量脚本*

1. `vim admin-openrc`

   ```bash
   export OS_PROJECT_DOMAIN_NAME=Default
   export OS_USER_DOMAIN_NAME=Default
   export OS_PROJECT_NAME=admin
   export OS_USERNAME=admin
   export OS_PASSWORD=0000
   export OS_AUTH_URL=http://openstack-test:35357/v3
   export OS_IDENTITY_API_VERSION=3
   export OS_IMAGE_API_VERSION=2
   ```

2. `vim demo-openrc`

   ```bash
   export OS_PROJECT_DOMAIN_NAME=Default
   export OS_USER_DOMAIN_NAME=Default
   export OS_PROJECT_NAME=demo
   export OS_USERNAME=demo
   export OS_PASSWORD=0000
   export OS_AUTH_URL=http://openstack-test:5000/v3
   export OS_IDENTITY_API_VERSION=3
   export OS_IMAGE_API_VERSION=2
   ```

### 安装配置Glance服务

#### *安装glance服务*

1. 登陆mysql,创建glance表，然后配置权限信息

   ```sql
   $ mysql -u root -p

   CREATE DATABASE glance;

   GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'openstack-test' \
     IDENTIFIED BY 'GLANCE_DBPASS';
     
   GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' \
     IDENTIFIED BY 'GLANCE_DBPASS';
     
   # 替换KEYSTONE_DBPASS的值
   ```

2. `. admin-openrc`

3. `openstack user create --domain default --password-prompt glance`

   ```bash
   User Password:
   Repeat User Password:
   +---------------------+----------------------------------+
   | Field               | Value                            |
   +---------------------+----------------------------------+
   | domain_id           | default                          |
   | enabled             | True                             |
   | id                  | 61f4b72b7a364d52a9635322fe549fb9 |
   | name                | glance                           |
   | options             | {}                               |
   | password_expires_at | None                             |
   +---------------------+----------------------------------+
   ```

4. `openstack role add --project service --user glance admin`

5. `openstack service create --name glance --description "OpenStack Image" image`

   ```bash
   +-------------+----------------------------------+
   | Field       | Value                            |
   +-------------+----------------------------------+
   | description | OpenStack Image                  |
   | enabled     | True                             |
   | id          | ca4ab53cc3234a109f14dc854cae4bd3 |
   | name        | glance                           |
   | type        | image                            |
   +-------------+----------------------------------+
   ```

6. `openstack endpoint create --region RegionOne image public http://openstack-test:9292`

   ```bash
   +--------------+----------------------------------+
   | Field        | Value                            |
   +--------------+----------------------------------+
   | enabled      | True                             |
   | id           | 1b5f90daaa64461c9852905e21a78bd6 |
   | interface    | public                           |
   | region       | RegionOne                        |
   | region_id    | RegionOne                        |
   | service_id   | ca4ab53cc3234a109f14dc854cae4bd3 |
   | service_name | glance                           |
   | service_type | image                            |
   | url          | http://openstack-test:9292       |
   +--------------+----------------------------------+
   ```

7. `openstack endpoint create --region RegionOne image internal http://openstack-test:9292`

   ```bash
   +--------------+----------------------------------+
   | Field        | Value                            |
   +--------------+----------------------------------+
   | enabled      | True                             |
   | id           | 81457290701c413a9268173ce7b3abb6 |
   | interface    | internal                         |
   | region       | RegionOne                        |
   | region_id    | RegionOne                        |
   | service_id   | ca4ab53cc3234a109f14dc854cae4bd3 |
   | service_name | glance                           |
   | service_type | image                            |
   | url          | http://openstack-test:9292       |
   +--------------+----------------------------------+
   ```

8. `openstack endpoint create --region RegionOne image admin http://openstack-test:9292`

   ```bash
   +--------------+----------------------------------+
   | Field        | Value                            |
   +--------------+----------------------------------+
   | enabled      | True                             |
   | id           | f2a13d5804f1407e88f216e9b294a87c |
   | interface    | admin                            |
   | region       | RegionOne                        |
   | region_id    | RegionOne                        |
   | service_id   | ca4ab53cc3234a109f14dc854cae4bd3 |
   | service_name | glance                           |
   | service_type | image                            |
   | url          | http://openstack-test:9292       |
   +--------------+----------------------------------+
   ```

9. `yum install openstack-glance`

10. `vim /etc/glance/glance-api.conf`

   ```bash
   [database]
   # ````
   connection = mysql+pymysql://glance:0000@openstack-test/glance

   [keystone_authtoken]
   # ...
   auth_uri = http://openstack-test:5000
   auth_url = http://openstack-test:35357
   memcached_servers = openstack-test:11211
   auth_type = password
   project_domain_name = default
   user_domain_name = default
   project_name = service
   username = glance
   password = 0000

   [paste_deploy]
   # ...
   flavor = keystone

   [glance_store]
   # ...
   stores = file,http
   default_store = file
   filesystem_store_datadir = /var/lib/glance/images/
   ```

10. `vim /etc/glance/glance-registry.conf`

    ```bash
    [database]
    # ...
    connection = mysql+pymysql://glance:0000@openstack-test/glance

    [keystone_authtoken]
    # ...
    auth_uri = http://openstack-test:5000
    auth_url = http://openstack-test:35357
    memcached_servers = openstack-test:11211
    auth_type = password
    project_domain_name = default
    user_domain_name = default
    project_name = service
    username = glance
    password = 0000

    [paste_deploy]
    # ...
    flavor = keystone
    ```

11. `su -s /bin/sh -c "glance-manage db_sync" glance`

12. `systemctl enable openstack-glance-api.service openstack-glance-registry.service`

13. `systemctl start openstack-glance-api.service openstack-glance-registry.service`

#### *验证glance服务配置*

1. `. admin-openrc`

2. `wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img`

3. `openstack image create "cirros"  --file cirros-0.3.5-x86_64-disk.img --disk-format qcow2 --container-format bare --public`

   ```bash
   +------------------+------------------------------------------------------+
   | Field            | Value                                                |
   +------------------+------------------------------------------------------+
   | checksum         | f8ab98ff5e73ebab884d80c9dc9c7290                     |
   | container_format | bare                                                 |
   | created_at       | 2018-01-30T03:37:36Z                                 |
   | disk_format      | qcow2                                                |
   | file             | /v2/images/48381267-1261-47da-9abe-8314957a2190/file |
   | id               | 48381267-1261-47da-9abe-8314957a2190                 |
   | min_disk         | 0                                                    |
   | min_ram          | 0                                                    |
   | name             | cirros                                               |
   | owner            | 054c9f9780b646e084d0072abc8b51e4                     |
   | protected        | False                                                |
   | schema           | /v2/schemas/image                                    |
   | size             | 13267968                                             |
   | status           | active                                               |
   | tags             |                                                      |
   | updated_at       | 2018-01-30T03:37:36Z                                 |
   | virtual_size     | None                                                 |
   | visibility       | public                                               |
   +------------------+------------------------------------------------------+
   ```

4. `openstack image list`

   ```bash
   +--------------------------------------+--------+--------+
   | ID                                   | Name   | Status |
   +--------------------------------------+--------+--------+
   | 48381267-1261-47da-9abe-8314957a2190 | cirros | active |
   +--------------------------------------+--------+--------+
   ```

### 安装配置Nova服务

#### *安装nova服务*

1. 登陆mysql,创建nova 相关表，然后配置权限信息

   ```sql
   mysql -u root -p

   CREATE DATABASE nova_api;
   CREATE DATABASE nova;
   CREATE DATABASE nova_cell0;

   GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'openstack-test' IDENTIFIED BY '0000';
   GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '0000';

   GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'openstack-test' IDENTIFIED BY '0000';
   GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '0000';

   GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'openstack-test' IDENTIFIED BY '0000';
   GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '0000';
   ```

2. `. admin-openrc`

3. `openstack user create --domain default --password-prompt nova`

4. `openstack role add --project service --user nova admin`

5. `openstack service create --name nova --description "OpenStack Compute" compute`

6. `openstack endpoint create --region RegionOne compute public http://openstack-test:8774/v2.1`

7. `openstack endpoint create --region RegionOne compute internal http://openstack-test:8774/v2.1`

8. `openstack endpoint create --region RegionOne compute admin http://openstack-test:8774/v2.1`

9. `openstack user create --domain default --password-prompt placement`

10. `openstack role add --project service --user placement admin`

11. `openstack service create --name placement --description "Placement API" placement`

12. `openstack endpoint create --region RegionOne placement public http://openstack-test:8778`

13. `openstack endpoint create --region RegionOne placement internal http://openstack-test:8778`

14. `openstack endpoint create --region RegionOne placement admin http://openstack-test:8778`

15. `yum install openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler openstack-nova-placement-api openstack-nova-compute`

16. `vim /etc/nova/nova.conf`

    ```bash
    [DEFAULT]
    # ...
    enabled_apis = osapi_compute,metadata
    transport_url = rabbit://openstack:0000@openstack-test
    my_ip = 10.0.2.4
    use_neutron = True
    firewall_driver = nova.virt.firewall.NoopFirewallDriver

    [api_database]
    # ...
    connection = mysql+pymysql://nova:0000@openstack-test/nova_api

    [database]
    # ...
    connection = mysql+pymysql://nova:0000@openstack-test/nova

    [api]
    # ...
    auth_strategy = keystone

    [keystone_authtoken]
    # ...
    auth_uri = http://controller:5000
    auth_url = http://controller:35357
    memcached_servers = controller:11211
    auth_type = password
    project_domain_name = default
    user_domain_name = default
    project_name = service
    username = nova
    password = NOVA_PASS

    [vnc]
    enabled = true
    # ...
    vncserver_listen = $my_ip
    vncserver_proxyclient_address = $my_ip
    novncproxy_base_url = http://openstack-test:6080/vnc_auto.html

    [glance]
    # ...
    api_servers = http://openstack-test:9292

    [oslo_concurrency]
    # ...
    lock_path = /var/lib/nova/tmp

    [placement]
    # ...
    os_region_name = RegionOne
    project_domain_name = Default
    project_name = service
    auth_type = password
    user_domain_name = Default
    auth_url = http://openstack-test:35357/v3
    username = placement
    password = 0000

    # 如果cpu支持kvm，可以不用更改此项
    [libvirt]
    # ...
    virt_type = qemu
    ```

17. `vim  /etc/httpd/conf.d/00-nova-placement-api.conf`

    ```bash
    <Directory /usr/bin>
       <IfVersion >= 2.4>
          Require all granted
       </IfVersion>
       <IfVersion < 2.4>
          Order allow,deny
          Allow from all
       </IfVersion>
    </Directory>
    ```

18. `systemctl restart httpd`

19. `su -s /bin/sh -c "nova-manage api_db sync" nova`

20. `su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova`

21. `su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova`

22. `su -s /bin/sh -c "nova-manage db sync" nova`

23. `nova-manage cell_v2 list_cells`

24. `systemctl enable openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service libvirtd.service openstack-nova-compute.service`

25. `systemctl start openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service libvirtd.service openstack-nova-compute.service`

26. `openstack hypervisor list`

27. `su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova`

**注意**：如果启动openstack-nova-compute服务失败，检查`/var/log/nova/nova-compute.log`文件

#### *验证nova服务*

1. `. admin-openrc`

2. `openstack compute service list`

   ```bash
   +----+------------------+----------------+----------+---------+-------+----------------------------+
   | ID | Binary           | Host           | Zone     | Status  | State | Updated At                 |
   +----+------------------+----------------+----------+---------+-------+----------------------------+
   |  1 | nova-consoleauth | openstack-test | internal | enabled | up    | 2018-01-30T07:20:46.000000 |
   |  2 | nova-conductor   | openstack-test | internal | enabled | up    | 2018-01-30T07:20:45.000000 |
   |  4 | nova-scheduler   | openstack-test | internal | enabled | up    | 2018-01-30T07:20:47.000000 |
   |  7 | nova-compute     | openstack-test | nova     | enabled | up    | 2018-01-30T07:20:44.000000 |
   +----+------------------+----------------+----------+---------+-------+----------------------------+
   ```

3. `openstack catalog list`

   ```bash
   +-----------+-----------+---------------------------------------------+
   | Name      | Type      | Endpoints                                   |
   +-----------+-----------+---------------------------------------------+
   | keystone  | identity  | RegionOne                                   |
   |           |           |   public: http://openstack-test:5000/v3/    |
   |           |           | RegionOne                                   |
   |           |           |   internal: http://openstack-test:5000/v3/  |
   |           |           | RegionOne                                   |
   |           |           |   admin: http://openstack-test:35357/v3/    |
   |           |           |                                             |
   | placement | placement | RegionOne                                   |
   |           |           |   public: http://openstack-test:8778        |
   |           |           | RegionOne                                   |
   |           |           |   admin: http://openstack-test:8778         |
   |           |           | RegionOne                                   |
   |           |           |   internal: http://openstack-test:8778      |
   |           |           |                                             |
   | nova      | compute   | RegionOne                                   |
   |           |           |   internal: http://openstack-test:8774/v2.1 |
   |           |           | RegionOne                                   |
   |           |           |   public: http://openstack-test:8774/v2.1   |
   |           |           | RegionOne                                   |
   |           |           |   admin: http://openstack-test:8774/v2.1    |
   |           |           |                                             |
   | glance    | image     | RegionOne                                   |
   |           |           |   public: http://openstack-test:9292        |
   |           |           | RegionOne                                   |
   |           |           |   internal: http://openstack-test:9292      |
   |           |           | RegionOne                                   |
   |           |           |   admin: http://openstack-test:9292         |
   |           |           |                                             |
   +-----------+-----------+---------------------------------------------+
   ```

4. `openstack image list`

   ```bash
   +--------------------------------------+--------+--------+
   | ID                                   | Name   | Status |
   +--------------------------------------+--------+--------+
   | 48381267-1261-47da-9abe-8314957a2190 | cirros | active |
   +--------------------------------------+--------+--------+
   ```

5. `nova-status upgrade check`

   ```bash
   +---------------------------+
   | Upgrade Check Results     |
   +---------------------------+
   | Check: Cells v2           |
   | Result: Success           |
   | Details: None             |
   +---------------------------+
   | Check: Placement API      |
   | Result: Success           |
   | Details: None             |
   +---------------------------+
   | Check: Resource Providers |
   | Result: Success           |
   | Details: None             |
   +---------------------------+
   ```

### 安装配置Neutron服务

#### *安装neutron服务*

1. 登陆mysql,创建neutron表，然后配置权限信息

   ```sql
   mysql -u root -p

   CREATE DATABASE neutron;

   GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'openstack-test' IDENTIFIED BY '0000';

   GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '0000';
   ```

2. `. admin-openrc`

3. `openstack user create --domain default --password-prompt neutron`

   ```bash
   User Password:
   Repeat User Password:
   +---------------------+----------------------------------+
   | Field               | Value                            |
   +---------------------+----------------------------------+
   | domain_id           | default                          |
   | enabled             | True                             |
   | id                  | d10fe9b2426b4607bbca57a0a1b88704 |
   | name                | neutron                          |
   | options             | {}                               |
   | password_expires_at | None                             |
   +---------------------+----------------------------------+
   ```

4. `openstack role add --project service --user neutron admin`

5. `openstack service create --name neutron --description "OpenStack Networking" network`

   ```bash
   +-------------+----------------------------------+
   | Field       | Value                            |
   +-------------+----------------------------------+
   | description | OpenStack Networking             |
   | enabled     | True                             |
   | id          | 7e7dc098ef994db9b01c139d2a69cb08 |
   | name        | neutron                          |
   | type        | network                          |
   +-------------+----------------------------------+
   ```

6. `openstack endpoint create --region RegionOne network public http://openstack-test:9696`

   ```bash
   +--------------+----------------------------------+
   | Field        | Value                            |
   +--------------+----------------------------------+
   | enabled      | True                             |
   | id           | 3ff54d8605774f6fad5064f55ae01ed2 |
   | interface    | public                           |
   | region       | RegionOne                        |
   | region_id    | RegionOne                        |
   | service_id   | 7e7dc098ef994db9b01c139d2a69cb08 |
   | service_name | neutron                          |
   | service_type | network                          |
   | url          | http://openstack-test:9696       |
   +--------------+----------------------------------+
   ```

7. `openstack endpoint create --region RegionOne network internal http://openstack-test:9696`

   ```bash
   +--------------+----------------------------------+
   | Field        | Value                            |
   +--------------+----------------------------------+
   | enabled      | True                             |
   | id           | 6298b4986e6f455b9c07775520907e0e |
   | interface    | internal                         |
   | region       | RegionOne                        |
   | region_id    | RegionOne                        |
   | service_id   | 7e7dc098ef994db9b01c139d2a69cb08 |
   | service_name | neutron                          |
   | service_type | network                          |
   | url          | http://openstack-test:9696       |
   +--------------+----------------------------------+
   ```

8. `openstack endpoint create --region RegionOne network admin http://openstack-test:9696`

   ```bash
   +--------------+----------------------------------+
   | Field        | Value                            |
   +--------------+----------------------------------+
   | enabled      | True                             |
   | id           | 2622aed626ae4261ab54299a5cd7d317 |
   | interface    | admin                            |
   | region       | RegionOne                        |
   | region_id    | RegionOne                        |
   | service_id   | 7e7dc098ef994db9b01c139d2a69cb08 |
   | service_name | neutron                          |
   | service_type | network                          |
   | url          | http://openstack-test:9696       |
   +--------------+----------------------------------+
   ```

9. **Self-service networks**部署

   1. `yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge ebtables`

   2. `vim /etc/neutron/neutron.conf`

      ```bash
      [database]
      # ...
      connection = mysql+pymysql://neutron:0000@openstack-test/neutron

      [DEFAULT]
      # ...
      core_plugin = ml2
      service_plugins = router
      allow_overlapping_ips = true
      transport_url = rabbit://openstack:0000@openstack-test
      auth_strategy = keystone

      [keystone_authtoken]
      # ...
      auth_uri = http://openstack-test:5000
      auth_url = http://openstack-test:35357
      memcached_servers = openstack-test:11211
      auth_type = password
      project_domain_name = default
      user_domain_name = default
      project_name = service
      username = neutron
      password = 0000
      notify_nova_on_port_status_changes = true
      notify_nova_on_port_data_changes = true

      [nova]
      # ...
      auth_url = http://openstack-test:35357
      auth_type = password
      project_domain_name = default
      user_domain_name = default
      region_name = RegionOne
      project_name = service
      username = nova
      password = 0000

      [oslo_concurrency]
      # ...
      lock_path = /var/lib/neutron/tmp
      ```

   3. `vim /etc/neutron/plugins/ml2/ml2_conf.ini`

      ```bash
      [ml2]
      # ...
      type_drivers = flat,vlan,vxlan
      tenant_network_types = vxlan
      mechanism_drivers = linuxbridge,l2population
      extension_drivers = port_security

      [ml2_type_flat]
      # ...
      flat_networks = provider

      [ml2_type_vxlan]
      # ...
      vni_ranges = 1:1000

      [ml2_type_vxlan]
      # ...
      vni_ranges = 1:1000
      ```

   4. `vim /etc/neutron/plugins/ml2/linuxbridge_agent.ini`

      ```bash
      [linux_bridge]
      physical_interface_mappings = provider:enp0s8

      [vxlan]
      enable_vxlan = true
      local_ip = openstack-test
      l2_population = true

      [securitygroup]
      # ...
      enable_security_group = true
      firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
      ```

   5. `vim /etc/neutron/l3_agent.ini`

      ```bash
      [DEFAULT]
      # ...
      interface_driver = linuxbridge
      ```

   6. `vim /etc/neutron/dhcp_agent.ini`

      ```bash
      [DEFAULT]
      # ...
      interface_driver = linuxbridge
      dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
      enable_isolated_metadata = true
      ```

10. `vim /etc/neutron/metadata_agent.ini`

    ```bash
    [DEFAULT]
    # ...
    nova_metadata_ip = openstack-test
    metadata_proxy_shared_secret = 0000
    ```

11. `vim /etc/nova/nova.conf`

    ```bash
    [neutron]
    # ...
    url = http://openstack-test:9696
    auth_url = http://openstack-test:35357
    auth_type = password
    project_domain_name = default
    user_domain_name = default
    region_name = RegionOne
    project_name = service
    username = neutron
    password = 0000
    service_metadata_proxy = true
    metadata_proxy_shared_secret = 0000
    ```

12. `ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini`

13. `su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron`

14. `systemctl restart openstack-nova-api.service`

15. `systemctl enable neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service`

16. `systemctl start neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service`

17. `systemctl enable neutron-l3-agent.service`

18. `systemctl start neutron-l3-agent.service`

#### *验证neutron服务*

1. `. admin-openrc`

2. `openstack extension list --network`

   ```bash
   +--------------------------------------------------+---------------------------+--------------------------------------------------+
   | Name                                             | Alias                     | Description                                      |
   +--------------------------------------------------+---------------------------+--------------------------------------------------+
   | Default Subnetpools                              | default-subnetpools       | Provides ability to mark and use a subnetpool as |
   |                                                  |                           | the default                                      |
   | Network IP Availability                          | network-ip-availability   | Provides IP availability data for each network   |
   |                                                  |                           | and subnet.                                      |
   | Network Availability Zone                        | network_availability_zone | Availability zone support for network.           |
   | Auto Allocated Topology Services                 | auto-allocated-topology   | Auto Allocated Topology Services.                |
   | Neutron L3 Configurable external gateway mode    | ext-gw-mode               | Extension of the router abstraction for          |
   |                                                  |                           | specifying whether SNAT should occur on the      |
   |                                                  |                           | external gateway                                 |
   | Port Binding                                     | binding                   | Expose port bindings of a virtual port to        |
   |                                                  |                           | external application                             |
   | agent                                            | agent                     | The agent management extension.                  |
   | Subnet Allocation                                | subnet_allocation         | Enables allocation of subnets from a subnet pool |
   | L3 Agent Scheduler                               | l3_agent_scheduler        | Schedule routers among l3 agents                 |
   | Tag support                                      | tag                       | Enables to set tag on resources.                 |
   | Neutron external network                         | external-net              | Adds external network attribute to network       |
   |                                                  |                           | resource.                                        |
   | Neutron Service Flavors                          | flavors                   | Flavor specification for Neutron advanced        |
   |                                                  |                           | services                                         |
   | Network MTU                                      | net-mtu                   | Provides MTU attribute for a network resource.   |
   | Availability Zone                                | availability_zone         | The availability zone extension.                 |
   | Quota management support                         | quotas                    | Expose functions for quotas management per       |
   |                                                  |                           | tenant                                           |
   | HA Router extension                              | l3-ha                     | Add HA capability to routers.                    |
   | Provider Network                                 | provider                  | Expose mapping of virtual networks to physical   |
   |                                                  |                           | networks                                         |
   | Multi Provider Network                           | multi-provider            | Expose mapping of virtual networks to multiple   |
   |                                                  |                           | physical networks                                |
   | Address scope                                    | address-scope             | Address scopes extension.                        |
   | Neutron Extra Route                              | extraroute                | Extra routes configuration for L3 router         |
   | Subnet service types                             | subnet-service-types      | Provides ability to set the subnet service_types |
   |                                                  |                           | field                                            |
   | Resource timestamps                              | standard-attr-timestamp   | Adds created_at and updated_at fields to all     |
   |                                                  |                           | Neutron resources that have Neutron standard     |
   |                                                  |                           | attributes.                                      |
   | Neutron Service Type Management                  | service-type              | API for retrieving service providers for Neutron |
   |                                                  |                           | advanced services                                |
   | Router Flavor Extension                          | l3-flavors                | Flavor support for routers.                      |
   | Port Security                                    | port-security             | Provides port security                           |
   | Neutron Extra DHCP opts                          | extra_dhcp_opt            | Extra options configuration for DHCP. For        |
   |                                                  |                           | example PXE boot options to DHCP clients can be  |
   |                                                  |                           | specified (e.g. tftp-server, server-ip-address,  |
   |                                                  |                           | bootfile-name)                                   |
   | Resource revision numbers                        | standard-attr-revisions   | This extension will display the revision number  |
   |                                                  |                           | of neutron resources.                            |
   | Pagination support                               | pagination                | Extension that indicates that pagination is      |
   |                                                  |                           | enabled.                                         |
   | Sorting support                                  | sorting                   | Extension that indicates that sorting is         |
   |                                                  |                           | enabled.                                         |
   | security-group                                   | security-group            | The security groups extension.                   |
   | DHCP Agent Scheduler                             | dhcp_agent_scheduler      | Schedule networks among dhcp agents              |
   | Router Availability Zone                         | router_availability_zone  | Availability zone support for router.            |
   | RBAC Policies                                    | rbac-policies             | Allows creation and modification of policies     |
   |                                                  |                           | that control tenant access to resources.         |
   | Tag support for resources: subnet, subnetpool,   | tag-ext                   | Extends tag support to more L2 and L3 resources. |
   | port, router                                     |                           |                                                  |
   | standard-attr-description                        | standard-attr-description | Extension to add descriptions to standard        |
   |                                                  |                           | attributes                                       |
   | Neutron L3 Router                                | router                    | Router abstraction for basic L3 forwarding       |
   |                                                  |                           | between L2 Neutron networks and access to        |
   |                                                  |                           | external networks via a NAT gateway.             |
   | Allowed Address Pairs                            | allowed-address-pairs     | Provides allowed address pairs                   |
   | project_id field enabled                         | project-id                | Extension that indicates that project_id field   |
   |                                                  |                           | is enabled.                                      |
   | Distributed Virtual Router                       | dvr                       | Enables configuration of Distributed Virtual     |
   |                                                  |                           | Routers.                                         |
   +--------------------------------------------------+---------------------------+--------------------------------------------------+
   ```

3. `openstack network agent list`

   ```bash
   +-----------------------+--------------------+----------------+-------------------+-------+-------+------------------------+
   | ID                    | Agent Type         | Host           | Availability Zone | Alive | State | Binary                 |
   +-----------------------+--------------------+----------------+-------------------+-------+-------+------------------------+
   | 422bf003-b450-4795-83 | DHCP agent         | openstack-test | nova              | True  | UP    | neutron-dhcp-agent     |
   | 28-f385403e58e9       |                    |                |                   |       |       |                        |
   | 7615b003-89cf-419d-   | L3 agent           | openstack-test | nova              | True  | UP    | neutron-l3-agent       |
   | a88f-8da340f3a72b     |                    |                |                   |       |       |                        |
   | 7eaa090d-e136-4b3c-   | Metadata agent     | openstack-test | None              | True  | UP    | neutron-metadata-agent |
   | a5b4-1c0f284dec36     |                    |                |                   |       |       |                        |
   | 9a73b4b4-0ba5-4c64-a5 | Linux bridge agent | openstack-test | None              | True  | UP    | neutron-linuxbridge-   |
   | 72-a30e5270c950       |                    |                |                   |       |       | agent                  |
   +-----------------------+--------------------+----------------+-------------------+-------+-------+------------------------+
   ```

