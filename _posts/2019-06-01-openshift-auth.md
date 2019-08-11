---
layout:     post
title:      "openshift认证模块"
subtitle:   " \"openshift认证对接\""
date:       2019-06-01 12:00:00
author:     "Hanamichi"
header-img: "img/spacex-1.jpg"
catalog: true
tags:
    - openshift
    - k8s
---

## openshift认证系统

### openshift对接ldap

#### ldap

什么是 LDAP：[https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol](https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol)

OpenShift LDAP 认证（登录）过程：

1. 通过已配置的 LDAP url 中的 attribute 和 filter 部分和登录时用户提供的用户名生成搜索过滤器。
2. 使用搜索过滤器来搜索路径，如果没有找到匹配的记录，拒绝访问。
3. 尝试使用搜索得到的记录的 DN 和登录时用户提供的密码来绑定 LDAP 服务器。
4. 如果绑定失败，拒绝访问。
5. 绑定成功的话，将生成一个 user。

LDAP url 语法：`ldap://host:port/basedn?attribute?scope?filter`

| URL 组成部分 | 描述 |
| --- | --- |
| ldap/ldaps | 协议，和 HTTP 类似 |
| host:port | LDAP 服务器，端口默认为 389 |
| basedn | 搜索路径，起码是路径树的顶端，比如 dc=sh,dc=99cloud,dc=net |
| attribute | 想要搜索的记录的字段（属性），默认为 uid |
| scope | 搜索范围，
| filter | LDAP 搜索过滤器，默认 (objectClass=*) |

#### LDAP 服务器

**需要提前部署好 LDAP 服务器。**

* basedn（搜索路径）为 sh.99cloud.net/test：

    ```bash
    $ ldapsearch -x -h ldap_host -p 389 -b "ou=test,dc=sh,dc=99cloud,dc=net" -D "cn=admin,dc=sh,dc=99cloud,dc=net" -w password
    # extended LDIF
    #
    # LDAPv3
    # base <ou=test,dc=sh,dc=99cloud,dc=net> with scope subtree
    # filter: (objectclass=*)
    # requesting: ALL
    #

    # test, sh.99cloud.net
    dn: OU=test,DC=sh,DC=99cloud,DC=net
    objectClass: top
    objectClass: organizationalUnit
    ou: test
    distinguishedName: OU=test,DC=sh,DC=99cloud,DC=net
    instanceType: 4
    whenCreated: 20190801011557.0Z
    whenChanged: 20190801011557.0Z
    uSNCreated: 401679
    uSNChanged: 401680
    name: test
    objectGUID:: jJ46A+rR/kqBJwhM4ti84A==
    objectCategory: CN=Organizational-Unit,CN=Schema,CN=Configuration,DC=sh,DC=99c
    loud,DC=net
    dSCorePropagationData: 20190801011557.0Z
    dSCorePropagationData: 16010101000000.0Z

    # tester, test, sh.99cloud.net
    dn: CN=tester,OU=test,DC=sh,DC=99cloud,DC=net
    objectClass: top
    objectClass: person
    objectClass: organizationalPerson
    objectClass: user
    cn: tester
    sn: tester
    distinguishedName: CN=tester,OU=test,DC=sh,DC=99cloud,DC=net
    instanceType: 4
    whenCreated: 20190801013314.0Z
    whenChanged: 20190801013847.0Z
    displayName: tester
    uSNCreated: 401703
    uSNChanged: 401710
    name: tester
    objectGUID:: kQQ3U/uvwUe+o6mXVOsy6w==
    userAccountControl: 66048
    badPwdCount: 0
    codePage: 0
    countryCode: 0
    badPasswordTime: 0
    lastLogoff: 0
    lastLogon: 0
    pwdLastSet: 132090967948554687
    primaryGroupID: 513
    objectSid:: AQUAAAAAAAUVAAAAa+S9POY2SRrmi5qo8QUAAA==
    accountExpires: 9223372036854775807
    logonCount: 0
    sAMAccountName: tester
    sAMAccountType: 805306368
    userPrincipalName: tester@sh.99cloud.net
    objectCategory: CN=Person,CN=Schema,CN=Configuration,DC=sh,DC=99cloud,DC=net
    dSCorePropagationData: 16010101000000.0Z
    lastLogonTimestamp: 132090971274804687

    # search result
    search: 2
    result: 0 Success

    # numResponses: 3
    # numEntries: 2
    ```

* basedn（搜索路径）为 sh.99cloud.net/99cloud/sh

    ```bash
    ldapsearch -x -h ldap_host -p 389 -b "ou=sh,ou=99cloud,dc=sh,dc=99cloud,dc=net" -D "cn=admin,dc=sh,dc=99cloud,dc=net" -w password
    ```

* basedn（搜索路径）为 sh.99cloud.net/99cloud/wx

    ```bash
    ldapsearch -x -h ldap_host -p 389 -b "ou=wx,ou=99cloud,dc=sh,dc=99cloud,dc=net" -D "cn=admin,dc=sh,dc=99cloud,dc=net" -w password
    ```

#### 对接 OpenShift

1. 修改 master api 和 controllers 配置文件 /etc/origin/master/master-config.yaml

    ```yaml
    oauthConfig:
    ...
    identityProviders:
    - name: "my_ldap_provider"
        challenge: true
        login: true
        mappingMethod: claim
        provider:
        apiVersion: v1
        kind: LDAPPasswordIdentityProvider
        attributes:
            id:
            - dn
            email:
            - mail
            name:
            - cn
            preferredUsername:
            - uid
        bindDN: "cn=admin,dc=sh,dc=99cloud,dc=net"
        bindPassword: "password"
        ca: ""
        insecure: false
        url: "ldap://ldap_host:389/dc=sh,dc=99cloud,dc=net?mail"
    ```

    * 需要 admin 账号 DN （cn=admin,cn=admin,dc=sh,dc=99cloud,dc=net）与密码
    * 如果使用邮箱登录，url 的 attribute 部分使用 `mail`；如果使用姓名（张三）登录，url 的 attribute 部分使用 `cn`。
1. 重启 master api 和 controllers

    ```bash
    master-restart api
    master-restart controllers
    ```

1. 测试登录

    ```bash
    oc login -u foo.bar@99cloud.net -p password
    ```

#### 参考文档

* [https://docs.openshift.com/container-platform/3.11/install_config/configuring_authentication.html#LDAPPasswordIdentityProvider](https://docs.openshift.com/container-platform/3.11/install_config/configuring_authentication.html#LDAPPasswordIdentityProvider)
* [https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol](https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol)
* [LDAP概念和原理介绍](https://www.cnblogs.com/wilburxu/p/9174353.html)
* [https://docs.oracle.com/cd/E19957-01/816-6402-10/url.htm](https://docs.oracle.com/cd/E19957-01/816-6402-10/url.htm)

### openshift对接keystone

todo...



### openshift对接第三方认证

todo...