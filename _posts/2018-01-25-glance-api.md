---
layout:     post
title:      OpenStack Glance
subtitle:   " \"Glace API 整理\""
date:       2018-01-25 12:00:00
author:     "Hanamichi"
header-img: "img/post-bg-2015.jpg"
catalog: true
tags:
    - openstack
    - 云计算

---


#OpenStack Glance API整理

## 特别说明

本文作为Glance镜像服务的快速上手指南，假设读者已经掌握OpenStack认证相关内容，并已取得认证令牌(OS_TOKEN)以及各资源的入口地址，文中以curl演示各个接口的调用方法，实际开发中可灵活选用任意RESTful工具或函数库。

参考文章：

* https://developer.openstack.org/api-ref/image/v2/index.html
* https://developer.openstack.org/api-ref/image/v2/metadefs-index.html

OpenStack版本：Ocata

部署方式：devstack

资源入口：

* Keystone:http://192.168.1.10/identity
* Glance:http://192.168.1.10/image

获取token：

```bash
curl -v -s \ 
     -X POST $OS_AUTH_URL/v3/auth/tokens?nocatalog \
     -H "Content-Type: application/json" 
     -d '{
     "auth":
     {
     	"identity":
     	{
     		"methods":["password"],
     		"password":
     		{
     			"user":
     			{
     				"domain":{"name":"default"},
     				"name":"admin",
     				"password":"admin"
     			}
     		}
     	},
     	"scope":
     	{
     		"project":
     		{
     			"domain":{"name":"default"},
     			"name":"admin"
     		}
     	}
     }}' | python -m json.tool

# 将返回的X-Auth-Token值存入OS_TOKEN环境变量
```

URL请求返回值含义：

```yaml
# Success Codes

200:
  default: |
    Request was successful.
201:
  default: |
    Resource was created and is ready to use.
202:
  default: |
    Request was accepted for processing, but the processing has not been
    completed. A 'location' header is included in the response which contains
    a link to check the progress of the request.
204:
  default: |
    The server has fulfilled the request.
300:
  default: |
    There are multiple choices for resources. The request has to be more
    specific to successfully retrieve one of these resources.

# Error Codes

400:
  default: |
    Some content in the request was invalid.
401:
  default: |
    User must authenticate before making a request.
403:
  default: |
    Policy does not allow current user to do this operation.
404:
  default: |
    The requested resource could not be found.
405:
  default: |
    Method is not valid for this endpoint.
406:
  default: |
    The requested API version is not supported by the API.
409:
  default: |
    This operation conflicted with another operation on this resource.
413:
  default: |
    The request is larger than the server is willing or able to process.
415:
  default: |
    The request entity has a media type which the server or resource does
    not support.
500:
  default: |
    Something went wrong inside the service. This should not happen usually.
    If it does happen, it means the server has experienced some serious
    problems.
501:
  default: |
    The server either does not recognize the request method, or it lacks the
    ability to fulfill the request.
503:
  default: |
    Service is not available. This is mostly caused by service configuration
    errors which prevents the service from successful start up.

```

## 获取镜像服务api版本信息

### 第一种方式

**请求格式**：`GET  /versions`

**正常返回值**：200

**请求示例**：

`curl -v -s -H "X-Auth-Token:$OS_TOKEN" http://192.168.1.10/image/versions | python -m json.tool`

**返回示例**：

```json
{
    "versions": [
        {
            "id": "v2.5",
            "links": [
                {
                    "href": "http://192.168.1.10/image/v2/",
                    "rel": "self"
                }
            ],
            "status": "CURRENT"
        },
        {
            "id": "v2.4",
            "links": [
                {
                    "href": "http://192.168.1.10/image/v2/",
                    "rel": "self"
                }
            ],
            "status": "SUPPORTED"
        },
        {
            "id": "v2.3",
            "links": [
                {
                    "href": "http://192.168.1.10/image/v2/",
                    "rel": "self"
                }
            ],
            "status": "SUPPORTED"
        },
        {
            "id": "v2.2",
            "links": [
                {
                    "href": "http://192.168.1.10/image/v2/",
                    "rel": "self"
                }
            ],
            "status": "SUPPORTED"
        },
        {
            "id": "v2.1",
            "links": [
                {
                    "href": "http://192.168.1.10/image/v2/",
                    "rel": "self"
                }
            ],
            "status": "SUPPORTED"
        },
        {
            "id": "v2.0",
            "links": [
                {
                    "href": "http://192.168.1.10/image/v2/",
                    "rel": "self"
                }
            ],
            "status": "SUPPORTED"
        }
    ]
}
```

### 第二种方式

**请求格式**：`GET  /`

**正常返回值**：300

**请求示例**：

`curl -v -s -H "X-Auth-Token:$OS_TOKEN" http://192.168.1.10/image/ | python -m json.tool`

**返回示例**：返回结果同第一种方式

## 镜像服务API

### 显示所有镜像(list)

**请求格式**：`GET  /v2/images`

**请求参数**：limit, name, owner等参数可以对结果进行过滤和排序，因参数有很多，不一一列举

**正常返回值**：200

**错误返回值**：400, 401, 403

**请求示例**：

````bash
#显示所有镜像
curl -v -s -H "X-Auth-Token:$OS_TOKEN" http://192.168.1.10/image/v2/images | python -m json.tool
#显示镜像状态为保存中和排队中的镜像信息
curl -v -s -H "X-Auth-Token:$OS_TOKEN" http://192.168.1.10/image/v2/images?status=in:saving,queued
#对查询结果进行排序
curl -v -s -H "X-Auth-Token:$OS_TOKEN" http://192.168.1.10/image/v2/images?sort_key=name&sort_dir=asc&sort_key=status&sort_dir=desc
````

**返回示例**：

```json
{
    "first": "/v2/images",
    "images": [
        {
            "checksum": "f8ab98ff5e73ebab884d80c9dc9c7290",
            "container_format": "bare",
            "created_at": "2018-01-23T03:15:57Z",
            "disk_format": "qcow2",
            "file": "/v2/images/c1e5a7c4-040a-4ed1-97bd-17ee2767a012/file",
            "id": "c1e5a7c4-040a-4ed1-97bd-17ee2767a012",
            "min_disk": 0,
            "min_ram": 0,
            "name": "cirros-0.3.5-x86_64-disk",
            "owner": "22f8597d8a0c4d789a7024e64cc348fe",
            "protected": false,
            "schema": "/v2/schemas/image",
            "self": "/v2/images/c1e5a7c4-040a-4ed1-97bd-17ee2767a012",
            "size": 13267968,
            "status": "active",
            "tags": [],
            "updated_at": "2018-01-23T03:15:57Z",
            "virtual_size": null,
            "visibility": "public"
        }
    ],
    "schema": "/v2/schemas/images"
}
```

### 显示镜像详细信息(show)

**请求格式**：`GET  /v2/images/{image_id}`

**请求参数**：必须提供镜像的uuid

**正常返回值**：200

**错误返回值**：400, 401, 403, 404

**请求示例**：

`curl -v -s -H "X-Auth-Token:$OS_TOKEN" http://192.168.1.10/image/v2/images/{image_id} | python -m json.tool`

**返回示例**：

```json
{
    "checksum": "f8ab98ff5e73ebab884d80c9dc9c7290",
    "container_format": "bare",
    "created_at": "2018-01-23T03:15:57Z",
    "disk_format": "qcow2",
    "file": "/v2/images/c1e5a7c4-040a-4ed1-97bd-17ee2767a012/file",
    "id": "c1e5a7c4-040a-4ed1-97bd-17ee2767a012",
    "min_disk": 0,
    "min_ram": 0,
    "name": "cirros-0.3.5-x86_64-disk",
    "owner": "22f8597d8a0c4d789a7024e64cc348fe",
    "protected": false,
    "schema": "/v2/schemas/image",
    "self": "/v2/images/c1e5a7c4-040a-4ed1-97bd-17ee2767a012",
    "size": 13267968,
    "status": "active",
    "tags": [],
    "updated_at": "2018-01-23T03:15:57Z",
    "virtual_size": null,
    "visibility": "public"
}
```

### 创建镜像(create)

**请求格式**：`POST /v2/images`

**请求参数**：container_format ,disk_format,name等

**正常返回值**：201

**错误返回值**：400, 401, 403, 409, 413, 415

**请求示例**：

````bash
curl -v -s -X POST http://192.168.1.10/image/v2/images \ 
     -H "Content-Type:application/json" -H "X-Auth-Token:$OS_TOKEN" 
     -d '{"container_format":"bare","disk_format":"raw","name":"zxwtest"}' \
     | python -m json.tool
````

**返回示例**：

```json
{
    "checksum": null,
    "container_format": "bare",
    "created_at": "2018-01-24T09:04:39Z",
    "disk_format": "raw",
    "file": "/v2/images/b4680745-947f-4151-80c5-c282c990e139/file",
    "id": "b4680745-947f-4151-80c5-c282c990e139",
    "min_disk": 0,
    "min_ram": 0,
    "name": "zxwtest",
    "owner": "22f8597d8a0c4d789a7024e64cc348fe",
    "protected": false,
    "schema": "/v2/schemas/image",
    "self": "/v2/images/b4680745-947f-4151-80c5-c282c990e139",
    "size": null,
    "status": "queued",
    "tags": [],
    "updated_at": "2018-01-24T09:04:39Z",
    "virtual_size": null,
    "visibility": "shared"
}
```

### 更新镜像信息(update)

**请求格式**：`PATCH  /v2/images/{image_id}`

**请求参数**：指定Content-Type为`application/openstack-images-v2.1-json-patch`

**正常返回值**：200

**错误返回值**：400, 401, 403, 404, 409, 413, 415

**请求示例**：

```bash
curl -v -s -X PATCH http://192.168.1.10/image/v2/images/c1e5a7c4-040a-4ed1-97bd-17ee2767a012 \
	-H "Content-Type:application/openstack-images-v2.1-json-patch" \
	-H "X-Auth-Token:$OS_TOKEN" \
	-d '[{"op":"add","path":"/login-user","value":"root"}]' \
	| python -m json.tool
```

**返回示例**：

```json
{
    "checksum": "f8ab98ff5e73ebab884d80c9dc9c7290",
    "container_format": "bare",
    "created_at": "2018-01-23T03:15:57Z",
    "disk_format": "qcow2",
    "file": "/v2/images/c1e5a7c4-040a-4ed1-97bd-17ee2767a012/file",
    "id": "c1e5a7c4-040a-4ed1-97bd-17ee2767a012",
    "login-user": "root",
    "min_disk": 0,
    "min_ram": 0,
    "name": "cirros-0.3.5-x86_64-disk",
    "owner": "22f8597d8a0c4d789a7024e64cc348fe",
    "protected": false,
    "schema": "/v2/schemas/image",
    "self": "/v2/images/c1e5a7c4-040a-4ed1-97bd-17ee2767a012",
    "size": 13267968,
    "status": "active",
    "tags": [],
    "updated_at": "2018-01-24T09:41:29Z",
    "virtual_size": null,
    "visibility": "public"
}
```

### 删除镜像(delete)

**请求格式**：`  DELETE /v2/images/{image_id}`

**请求参数**：指定镜像的uuid

**正常返回值**：204

**错误返回值**：400, 401, 403, 404, 409

**请求示例**:

`curl -v -s -X DELETE -H "X-Auth-TOken:$OS_TOKEN" http://192.168.1.10/image/v2/images/b4680745-947f-4151-80c5-c282c990e139`

**注意**：

1. 不能删除protected属性为true的镜像
2. 不能删除状态为deleted的镜像
3. 用户必须有删除镜像的权限
4. 如果操作正常，不返回任何数据(content)
5. 如果该镜像在存储后端有数据，则也会删除这些数据

### 使镜像无效(Deactivate)

**请求格式**：`  POST /v2/images/{image_id}/actions/deactivate`

**请求参数**：指定镜像的uuid

**正常返回值**：204

**错误返回值**：400, 403, 404

**请求示例**:

`curl -v -s -X POST -H "X-Auth-TOken:$OS_TOKEN" http://192.168.1.10/image/v2/images/c1e5a7c4-040a-4ed1-97bd-17ee2767a012/actions/deactivate`

**注意**：

1. 默认情况下，只有管理员能执行
2. 下载不活动镜像时会返回403错误
3. 如果镜像状态不是active或者deactivated,执行此操作会返回错误
4. 如果操作正常，不返回任何数据(content)

### 使镜像恢复活动(Reactivate)

**请求格式**：`  POST /v2/images/{image_id}/actions/reactivate`

**请求参数**：指定镜像的uuid

**正常返回值**：204

**错误返回值**：400, 403, 404

**请求示例**:

`curl -v -s -X POST -H "X-Auth-TOken:$OS_TOKEN" http://192.168.1.10/image/v2/images/c1e5a7c4-040a-4ed1-97bd-17ee2767a012/actions/reactivate`

**注意**：与deactivate操作基本一致

## 镜像共享API

镜像可以通过创建成员(member)在项目(project)之间共享，镜像成员只有只读权限，只有镜像所有者才能创建成员，镜像成员可以更改自己的状态。只有镜像的可见性属性(visibility)为**shared**才能创建成员

### 显示镜像成员信息(list)

**请求格式**：`  GET /v2/images/{image_id}/members`

**请求参数**：指定镜像的uuid

**正常返回值**：200

**错误返回值**：400, 401, 403, 404

**请求示例**:

`curl -v -s -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/images/2b1e0ce8-dcda-4152-88c3-7904d95cadf9/members | python -m json.tool`

**返回示例**：

```json
{
    "members": [
        {
            "created_at": "2018-01-25T01:48:37Z",
            "image_id": "2b1e0ce8-dcda-4152-88c3-7904d95cadf9",
            "member_id": "22f8597d8a0c4d789a7024e64cc348fe",
            "schema": "/v2/schemas/member",
            "status": "pending",
            "updated_at": "2018-01-25T01:48:37Z"
        }
    ],
    "schema": "/v2/schemas/members"
}
```

### 创建镜像成员(create)

**请求格式**：`  POST /v2/images/{image_id}/members`

**请求参数**：指定镜像的uuid和成员id通常即project_id

**正常返回值**：200

**错误返回值**：400, 401, 403, 404, 409, 413

**请求示例**:

`curl -v -s -X POST -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/images/2b1e0ce8-dcda-4152-88c3-7904d95cadf9/members -d '{"member":"22f8597d8a0c4d789a7024e64cc348fe"}' | python -m json.tool`

**返回示例**：

```json
{
    "created_at": "2018-01-25T01:48:37Z",
    "image_id": "2b1e0ce8-dcda-4152-88c3-7904d95cadf9",
    "member_id": "22f8597d8a0c4d789a7024e64cc348fe",
    "schema": "/v2/schemas/member",
    "status": "pending",
    "updated_at": "2018-01-25T01:48:37Z"
}
```

### 显示镜像成员的具体信息(show)

**请求格式**：`  GET /v2/images/{image_id}/members/{member_id}`

**请求参数**：指定镜像的uuid和成员id

**正常返回值**：200

**错误返回值**：400, 401, 404

**请求示例**:

`curl -v -s -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/images/2b1e0ce8-dcda-4152-88c3-7904d95cadf9/members/22f8597d8a0c4d789a7024e64cc348fe | python -m json.tool`

**返回示例**：

```json
{
    "created_at": "2018-01-25T01:48:37Z",
    "image_id": "2b1e0ce8-dcda-4152-88c3-7904d95cadf9",
    "member_id": "22f8597d8a0c4d789a7024e64cc348fe",
    "schema": "/v2/schemas/member",
    "status": "pending",
    "updated_at": "2018-01-25T01:48:37Z"
}
```

### 更新镜像成员的信息(update)

**请求格式**：`  PUT /v2/images/{image_id}/members/{member_id}`

**请求参数**：指定镜像的uuid和成员id,需要修改的键值对

**正常返回值**：200

**错误返回值**：400, 401, 404, 403

**请求示例**:

`curl -v -s -X PUT -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/images/2b1e0ce8-dcda-4152-88c3-7904d95cadf9/members/22f8597d8a0c4d789a7024e64cc348fe -d '{"status":"accepted"}' | python -m json.tool`

**返回示例**：

```json
{
    "created_at": "2018-01-25T01:48:37Z",
    "image_id": "2b1e0ce8-dcda-4152-88c3-7904d95cadf9",
    "member_id": "22f8597d8a0c4d789a7024e64cc348fe",
    "schema": "/v2/schemas/member",
    "status": "accepted",
    "updated_at": "2018-01-25T02:00:00Z"
}
```

### 删除镜像成员(delete)

**请求格式**：`  DELETE /v2/images/{image_id}/members/{member_id}`

**请求参数**：指定镜像的uuid和成员id,需要修改的键值对

**正常返回值**：204

**错误返回值**：400, 401, 403, 404

**请求示例**:

`curl -v -s -X DELETE -H "X-Auth-Token:$OS_TOKEN" http://192.168.1.10/image/v2/images/2b1e0ce8-dcda-4152-88c3-7904d95cadf9/members/22f8597d8a0c4d789a7024e64cc348fe | python -m json.tool`

## 镜像标签API

### 添加标签(create)

**请求格式**：`  PUT /v2/images/{image_id}/tags/{tag}`

**请求参数**：指定镜像的uuid和标签值

**正常返回值**：204

**错误返回值**：400, 401, 403, 404, 413

**请求示例**:

`curl -v -s -X PUT -H "X-Auth-Token:$OS_TOKEN" http://192.168.1.10/image/v2/images/c1e5a7c4-040a-4ed1-97bd-17ee2767a012/tags/zxw | python -m json.tool`

###删除标签(delete)

**请求格式**：`  DELETE /v2/images/{image_id}/tags/{tag}`

**请求参数**：指定镜像的uuid和标签值

**正常返回值**：204

**错误返回值**：400, 401, 403, 404

**请求示例**:

`curl -v -s -X DELETE -H "X-Auth-Token:$OS_TOKEN" http://192.168.1.10/image/v2/images/c1e5a7c4-040a-4ed1-97bd-17ee2767a012/tags/zxw | python -m json.tool`

## Image Schemas API

image schemas描述了镜像实体的信息

### 获取image schemas(list)

**请求格式**：`  GET /v2/schemas/images/`

**请求参数**：无

**正常返回值**：200

**错误返回值**：400, 401

**请求示例**:

`curl -v -s -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/schemas/images | python -m json.tool`

**返回示例**：

```json
{
    "links": [
        {
            "href": "{first}",
            "rel": "first"
        },
        {
            "href": "{next}",
            "rel": "next"
        },
        {
            "href": "{schema}",
            "rel": "describedby"
        }
    ],
    "name": "images",
    "properties": {
        "first": {
            "type": "string"
        },
        "images": {
            "items": {
                "additionalProperties": {
                    "type": "string"
                },
                "links": [
                    {
                        "href": "{self}",
                        "rel": "self"
                    },
                    {
                        "href": "{file}",
                        "rel": "enclosure"
                    },
                    {
                        "href": "{schema}",
                        "rel": "describedby"
                    }
                ],
                "name": "image",
                "properties": {
                    "architecture": {
                        "description": "Operating system architecture as specified in https://docs.openstack.org/python-glanceclient/latest/cli/property-keys.html",
                        "is_base": false,
                        "type": "string"
                    },
                    "checksum": {
                        "description": "md5 hash of image contents.",
                        "maxLength": 32,
                        "readOnly": true,
                        "type": [
                            "null",
                            "string"
                        ]
                    },
                    "container_format": {
                        "description": "Format of the container",
                        "enum": [
                            null,
                            "ami",
                            "ari",
                            "aki",
                            "bare",
                            "ovf",
                            "ova",
                            "docker"
                        ],
                        "type": [
                            "null",
                            "string"
                        ]
                    },
                    "created_at": {
                        "description": "Date and time of image registration",
                        "readOnly": true,
                        "type": "string"
                    },
                    "direct_url": {
                        "description": "URL to access the image file kept in external store",
                        "readOnly": true,
                        "type": "string"
                    },
                    "disk_format": {
                        "description": "Format of the disk",
                        "enum": [
                            null,
                            "ami",
                            "ari",
                            "aki",
                            "vhd",
                            "vhdx",
                            "vmdk",
                            "raw",
                            "qcow2",
                            "vdi",
                            "iso",
                            "ploop"
                        ],
                        "type": [
                            "null",
                            "string"
                        ]
                    },
                    "file": {
                        "description": "An image file url",
                        "readOnly": true,
                        "type": "string"
                    },
                    "id": {
                        "description": "An identifier for the image",
                        "pattern": "^([0-9a-fA-F]){8}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){12}$",
                        "type": "string"
                    },
                    "instance_uuid": {
                        "description": "Metadata which can be used to record which instance this image is associated with. (Informational only, does not create an instance snapshot.)",
                        "is_base": false,
                        "type": "string"
                    },
                    "kernel_id": {
                        "description": "ID of image stored in Glance that should be used as the kernel when booting an AMI-style image.",
                        "is_base": false,
                        "pattern": "^([0-9a-fA-F]){8}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){12}$",
                        "type": [
                            "null",
                            "string"
                        ]
                    },
                    "locations": {
                        "description": "A set of URLs to access the image file kept in external store",
                        "items": {
                            "properties": {
                                "metadata": {
                                    "type": "object"
                                },
                                "url": {
                                    "maxLength": 255,
                                    "type": "string"
                                }
                            },
                            "required": [
                                "url",
                                "metadata"
                            ],
                            "type": "object"
                        },
                        "type": "array"
                    },
                    "min_disk": {
                        "description": "Amount of disk space (in GB) required to boot image.",
                        "type": "integer"
                    },
                    "min_ram": {
                        "description": "Amount of ram (in MB) required to boot image.",
                        "type": "integer"
                    },
                    "name": {
                        "description": "Descriptive name for the image",
                        "maxLength": 255,
                        "type": [
                            "null",
                            "string"
                        ]
                    },
                    "os_distro": {
                        "description": "Common name of operating system distribution as specified in https://docs.openstack.org/python-glanceclient/latest/cli/property-keys.html",
                        "is_base": false,
                        "type": "string"
                    },
                    "os_version": {
                        "description": "Operating system version as specified by the distributor",
                        "is_base": false,
                        "type": "string"
                    },
                    "owner": {
                        "description": "Owner of the image",
                        "maxLength": 255,
                        "type": [
                            "null",
                            "string"
                        ]
                    },
                    "protected": {
                        "description": "If true, image will not be deletable.",
                        "type": "boolean"
                    },
                    "ramdisk_id": {
                        "description": "ID of image stored in Glance that should be used as the ramdisk when booting an AMI-style image.",
                        "is_base": false,
                        "pattern": "^([0-9a-fA-F]){8}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){12}$",
                        "type": [
                            "null",
                            "string"
                        ]
                    },
                    "schema": {
                        "description": "An image schema url",
                        "readOnly": true,
                        "type": "string"
                    },
                    "self": {
                        "description": "An image self url",
                        "readOnly": true,
                        "type": "string"
                    },
                    "size": {
                        "description": "Size of image file in bytes",
                        "readOnly": true,
                        "type": [
                            "null",
                            "integer"
                        ]
                    },
                    "status": {
                        "description": "Status of the image",
                        "enum": [
                            "queued",
                            "saving",
                            "active",
                            "killed",
                            "deleted",
                            "pending_delete",
                            "deactivated"
                        ],
                        "readOnly": true,
                        "type": "string"
                    },
                    "tags": {
                        "description": "List of strings related to the image",
                        "items": {
                            "maxLength": 255,
                            "type": "string"
                        },
                        "type": "array"
                    },
                    "updated_at": {
                        "description": "Date and time of the last image modification",
                        "readOnly": true,
                        "type": "string"
                    },
                    "virtual_size": {
                        "description": "Virtual size of image in bytes",
                        "readOnly": true,
                        "type": [
                            "null",
                            "integer"
                        ]
                    },
                    "visibility": {
                        "description": "Scope of image accessibility",
                        "enum": [
                            "community",
                            "public",
                            "private",
                            "shared"
                        ],
                        "type": "string"
                    }
                }
            },
            "type": "array"
        },
        "next": {
            "type": "string"
        },
        "schema": {
            "type": "string"
        }
    }
}
```

### 获取member schemas(list)

**请求格式**：`  GET /v2/schemas/members/`

**请求参数**：无

**正常返回值**：200

**错误返回值**：400, 401

**请求示例**:

`curl -v -s -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/schemas/members | python -m json.tool`

**返回示例**：

```json
{
    "links": [
        {
            "href": "{schema}",
            "rel": "describedby"
        }
    ],
    "name": "members",
    "properties": {
        "members": {
            "items": {
                "name": "member",
                "properties": {
                    "created_at": {
                        "description": "Date and time of image member creation",
                        "type": "string"
                    },
                    "image_id": {
                        "description": "An identifier for the image",
                        "pattern": "^([0-9a-fA-F]){8}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){12}$",
                        "type": "string"
                    },
                    "member_id": {
                        "description": "An identifier for the image member (tenantId)",
                        "type": "string"
                    },
                    "schema": {
                        "readOnly": true,
                        "type": "string"
                    },
                    "status": {
                        "description": "The status of this image member",
                        "enum": [
                            "pending",
                            "accepted",
                            "rejected"
                        ],
                        "type": "string"
                    },
                    "updated_at": {
                        "description": "Date and time of last modification of image member",
                        "type": "string"
                    }
                }
            },
            "type": "array"
        },
        "schema": {
            "type": "string"
        }
    }
}
```

## Image data API

### 上传镜像数据(upload)

**请求格式**：`  PUT /v2/images/{image_id}/file`

**请求参数**：指定镜像uuid，指定请求头为`application/octet-stream`

**正常返回值**：204

**错误返回值**：400, 401, 403, 404, 409, 410, 413, 415, 503

**请求示例**:

`curl -v -s -X PUT -H "X-Auth-Token:$OS_TOKEN" -H "Content-Type:application/octet-stream" -d @/tmp/cirros-0.4.0-x86_64-disk.img  http://192.168.1.10/image/v2/images/2b1e0ce8-dcda-4152-88c3-7904d95cadf9/file | python -m json.tool`

**注意**:

1. 镜像状态必须为**queued**
2. 空间足够

### 下载镜像数据(download)

**请求格式**：`  GET /v2/images/{image_id}/file`

**请求参数**：指定镜像uuid

**正常返回值**：204

**错误返回值**：400, 401, 403, 404, 409, 410, 413, 415, 503

**请求示例**:

`curl -v -s -X GET -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/images/2b1e0ce8-dcda-4152-88c3-7904d95cadf9/file > /tmp/zxw.img`

**注意**:

1. 如果有数据，返回值为200，则表示下载了全部数据
2. 如果有数据，返回值为206，则表示下载了部分数据
3. 如果没有数据，返回204

## 名字空间元数据API

### 创建名字空间(create)

**请求格式**：`  POST /v2/metadefs/namespaces`

**请求参数**：namespace,display_name,description,visibility,protected

**正常返回值**：201

**错误返回值**： 400, 401, 403, 409

**请求示例**:

`curl -v -s -X POST -H "X-Auth-Token:$OS_TOKEN" http://192.168.1.10/image/v2/metadefs/namespaces -d '{"namespace":"FredCo::SomeCategory::Example","display_name":"An Example Namespace","description":"A metadata definitions namespace for example use.","visibility":"public","protected":true}' | python -m json.tool`

**返回示例**：

```json
{
    "created_at": "2018-01-25T08:36:54Z",
    "description": "A metadata definitions namespace for example use.",
    "display_name": "An Example Namespace",
    "namespace": "FredCo::SomeCategory::Example",
    "owner": "22f8597d8a0c4d789a7024e64cc348fe",
    "protected": true,
    "schema": "/v2/schemas/metadefs/namespace",
    "self": "/v2/metadefs/namespaces/FredCo::SomeCategory::Example",
    "updated_at": "2018-01-25T08:36:54Z",
    "visibility": "public"
}
```

### 显示名字空间(list)

**请求格式**：`  GET /v2/metadefs/namespaces`

**请求参数**：使用sort_key等进行排序或者过滤

**正常返回值**：200

**错误返回值**： 401, 403, 404

**请求示例**:

`curl -v -s -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces?resource_type=OS::Glance::Image | python -m json.tool`

**返回示例**：

```json
{
    "first": "/v2/metadefs/namespaces?resource_type=OS%3A%3AGlance%3A%3AImage",
    "namespaces": [
        {
            "created_at": "2018-01-23T03:13:45Z",
            "description": "When adding an image to Glance, you may specify some common image properties that may prove useful to consumers of your image.",
            "display_name": "Common Image Properties",
            "namespace": "OS::Glance::CommonImageProperties",
            "owner": "admin",
            "protected": true,
            "schema": "/v2/schemas/metadefs/namespace",
            "self": "/v2/metadefs/namespaces/OS::Glance::CommonImageProperties",
            "visibility": "private"
        },
        {
            "created_at": "2018-01-23T03:13:45Z",
            "description": "Properties related to the Nova scheduler filter AggregateIoOpsFilter. Filters aggregate hosts based on the number of instances currently changing state. Hosts in the aggregate with too many instances changing state will be filtered out. The filter must be enabled in the Nova scheduler to use these properties.",
            "display_name": "IO Ops per Host",
            "namespace": "OS::Compute::AggregateIoOpsFilter",
            "owner": "admin",
            "protected": true,
            "resource_type_associations": [
                {
                    "created_at": "2018-01-23T03:13:45Z",
                    "name": "OS::Nova::Aggregate"
                }
            ],
            "schema": "/v2/schemas/metadefs/namespace",
            "self": "/v2/metadefs/namespaces/OS::Compute::AggregateIoOpsFilter",
            "visibility": "public"
        },         
    "next": "/v2/metadefs/namespaces?marker=CIM%3A%3AStorageAllocationSettingData&resource_type=OS%3A%3AGlance%3A%3AImage",
    "schema": "/v2/schemas/metadefs/namespaces"
}
```

###显示名字空间详细信息(show)

**请求格式**：`  GET /v2/metadefs/namespaces/{namespace_name}`

**请求参数**: 名字空间名

**正常返回值**：200

**错误返回值**： 400, 401, 403, 404

**请求示例**:

`curl -v -s -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example | python -m json.tool`

**返回示例**：

```json
{
    "created_at": "2018-01-25T08:36:54Z",
    "description": "A metadata definitions namespace for example use.",
    "display_name": "An Example Namespace",
    "namespace": "FredCo::SomeCategory::Example",
    "owner": "22f8597d8a0c4d789a7024e64cc348fe",
    "protected": true,
    "schema": "/v2/schemas/metadefs/namespace",
    "self": "/v2/metadefs/namespaces/FredCo::SomeCategory::Example",
    "updated_at": "2018-01-25T08:36:54Z",
    "visibility": "public"
}
```

### 更新名字空间的信息(update)

**请求格式**：`  PUT /v2/metadefs/namespaces/{namespace_name}`

**请求参数**: 要修改的字段值，如果要修改protected的值，需要一起给出description，display_name，namespace，visibility的值

**正常返回值**：200

**错误返回值**：400, 401, 403, 404, 409

**请求示例**:

`curl -v -s -X PUT -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example -d '{"namespace":"FredCo::SomeCategory::Example","display_name":"An Example Namespace","description":"A metadata definitions namespace for example use.","visibility":"public","protected":false}' | python -m json.tool`

**返回示例**：

```json
{
    "created_at": "2018-01-25T08:36:55Z",
    "description": "A metadata definitions namespace for example use.",
    "display_name": "An Example Namespace",
    "namespace": "FredCo::SomeCategory::Example",
    "owner": "22f8597d8a0c4d789a7024e64cc348fe",
    "protected": false,
    "schema": "/v2/schemas/metadefs/namespace",
    "self": "/v2/metadefs/namespaces/FredCo::SomeCategory::Example",
    "updated_at": "2018-01-25T08:36:55Z",
}
```

### 删除名字空间(delete)

**请求格式**：` DELETE /v2/metadefs/namespaces/{namespace_name}`

**请求参数**: 如果要删除的名字空间的protected值为true，则先要更改其值为false，才能删除

**正常返回值**：204

**错误返回值**：400, 401, 403, 404

**请求示例**:

`curl -v -s -X DELETE -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example | python -m json.tool`

## 资源类型元数据API

### 显示资源类型(list)

**请求格式**：`  GET /v2/metadefs/resource_types`

**请求参数**: 无

**正常返回值**：200

**错误返回值**：400, 401, 404

**请求示例**:

`curl -v -s -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/resource_types | python -m json.tool`

**返回示例**：

```json
{
    "resource_types": [
        {
            "created_at": "2018-01-23T03:13:42Z",
            "name": "OS::Glance::Image"
        },
        {
            "created_at": "2018-01-23T03:13:42Z",
            "name": "OS::Nova::Flavor"
        },
        {
            "created_at": "2018-01-23T03:13:42Z",
            "name": "OS::Cinder::Volume"
        },
        {
            "created_at": "2018-01-23T03:13:42Z",
            "name": "OS::Nova::Aggregate"
        },
        {
            "created_at": "2018-01-23T03:13:43Z",
            "name": "OS::Nova::Server"
        },
        {
            "created_at": "2018-01-23T03:13:43Z",
            "name": "OS::Trove::Instance"
        }
    ]
}
```

###名字空间关联资源类型(create)

**请求格式**：`  POST /v2/metadefs/{namespace_name}/resource_types`

**请求参数**: namespace_name,name,prefix,properties_target 

**正常返回值**：201

**错误返回值**：400, 401, 403, 404, 409

**请求示例**:

`curl -v -s -X POST -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example/resource_types -d '{"name":"OS::Cinder::Volume","prefix":"hw_","properties_target":"image"}' | python -m json.tool`

**返回示例**：

```json
{
    "created_at": "2018-01-25T09:19:00Z",
    "name": "OS::Cinder::Volume",
    "prefix": "hw_",
    "properties_target": "image",
    "updated_at": "2018-01-25T09:19:00Z"
}
```

### 显示名字空间的资源类型(show)

**请求格式**：`  GET /v2/metadefs/{namespace_name}/resource_types`

**请求参数**: namespace_name

**正常返回值**：200

**错误返回值**：400, 401, 403, 404

**请求示例**:

`curl -v -s -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example/resource_types | python -m json.tool`

**返回示例**：

```json
{
    "resource_type_associations": [
        {
            "created_at": "2018-01-25T09:19:01Z",
            "name": "OS::Cinder::Volume",
            "prefix": "hw_",
            "properties_target": "image",
            "updated_at": "2018-01-25T09:19:01Z"
        }
    ]
}
```

### 删除名字空间关联的资源类型(delete)

**请求格式**：`DELETE  /v2/metadefs/namespaces/{namespace_name}/resource_types/{name}`

**请求参数**:  namespace_name，name,如果名字空间的protected为true，不能删除

**正常返回值**：204

**错误返回值**：400, 401, 403, 404

**请求示例**:

`curl -v -s -X DELETE -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example/resource_types/OS::Cinder::Volume | python -m json.tool`

##对象元数据API

### 名字空间中创建对象定义(create)

**请求格式**：`POST  /v2/metadefs/namespaces/{namespace_name}/objects`

**请求参数**:  namespace_name

**正常返回值**：201

**错误返回值**：400, 401, 403, 404, 409

**请求示例**:

`curl -v -s -X POST -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example/objects -d '{"description":"example","name":"example","properties":{"p1":{"description":"p1","title":"example","type":"integer"}},"required":[]}' | python -m json.tool`

**返回示例**：

```json
{
    "created_at": "2018-01-25T09:40:46Z",
    "description": "example",
    "name": "example",
    "properties": {
        "p1": {
            "description": "p1",
            "title": "example",
            "type": "integer"
        }
    },
    "required": [],
    "schema": "/v2/schemas/metadefs/object",
    "self": "/v2/metadefs/namespaces/FredCo::SomeCategory::Example/objects/example",
    "updated_at": "2018-01-25T09:40:46Z"
}
```

### 显示对象定义(list)

**请求格式**：`GET  /v2/metadefs/namespaces/{namespace_name}/objects`

**请求参数**:  namespace_name,也可以进行输出结果的过滤和排序

**正常返回值**：200

**错误返回值**：401, 403, 404

**请求示例**:

`curl -v -s  -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example/objects  | python -m json.tool`

**返回示例**：

```json
{
    "objects": [
        {
            "created_at": "2018-01-25T09:40:46Z",
            "description": "example",
            "name": "example",
            "properties": {
                "p1": {
                    "description": "p1",
                    "title": "example",
                    "type": "integer"
                }
            },
            "required": [],
            "schema": "/v2/schemas/metadefs/object",
           "self":"/v2/metadefs/namespaces/FredCo::SomeCategory::Example/objects/example",
            "updated_at": "2018-01-25T09:40:46Z"
        }
    ],
    "schema": "v2/schemas/metadefs/objects"
}
```

### 显示对象定义的详细信息(show)

**请求格式**：`GET  /v2/metadefs/namespaces/{namespace_name}/objects/{object_name}`

**请求参数**:  namespace_name,object_name

**正常返回值**：200

**错误返回值**：400, 401, 403, 404

**请求示例**:

`curl -v -s  -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example/objects/example  | python -m json.tool`

**返回示例**：

```json
{
    "created_at": "2018-01-25T09:40:46Z",
    "description": "example",
    "name": "example",
    "properties": {
        "p1": {
            "description": "p1",
            "title": "example",
            "type": "integer"
        }
    },
    "required": [],
    "schema": "/v2/schemas/metadefs/object",
    "self": "/v2/metadefs/namespaces/FredCo::SomeCategory::Example/objects/example",
    "updated_at": "2018-01-25T09:40:46Z"
}
```

###更新对象定义(update)

**请求格式**：`PUT  /v2/metadefs/namespaces/{namespace_name}/objects/{object_name}`

**请求参数**:  name,以及要更新的字段值

**正常返回值**：200

**错误返回值**：400, 401, 403, 404, 409

**请求示例**:

`curl -v -s  -X PUT -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example/objects/example -d '{"name":"example","description":"example123"}' | python -m json.tool`

**返回示例**：

```json
{
    "created_at": "2018-01-25T09:40:46Z",
    "description": "example123",
    "name": "example",
    "schema": "/v2/schemas/metadefs/object",
    "self": "/v2/metadefs/namespaces/FredCo::SomeCategory::Example/objects/example",
    "updated_at": "2018-01-25T09:40:46Z"
}
```

### 删除对象定义(delete)

**请求格式**：`DELETE  /v2/metadefs/namespaces/{namespace_name}/objects/{object_name}`

**请求参数**:  namespace_name,object_name

**正常返回值**：204

**错误返回值**：400, 401, 403, 404

**请求示例**:

`curl -v -s -X DELETE -H "X-Auth-Token:$OS_TOKEN" http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example/objects/example | python -m json.tool`

## 名字空间属性定义API

### 创建属性(create)

**请求格式**：`POST  /v2/metadefs/namespaces/{namespace_name}/properties`

**请求参数**:  namespace_name,object_name

**正常返回值**：201

**错误返回值**：400, 404

**请求示例**:

`curl -v -s -X POST  -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example/properties -d '{"description":"example properties","enum":["11","22","33"],"name":"example","title":"example type","type":"string"}' | python -m json.tool`

**返回示例**:

```json
{
    "description": "example properties",
    "enum": [
        "11",
        "22",
        "33"
    ],
    "name": "example",
    "title": "example type",
    "type": "string"
}
```

### 显示名字空间的属性(list)

**请求格式**：` GET  /v2/metadefs/namespaces/{namespace_name}/properties`

**请求参数**:  namespace_name

**正常返回值**：200

**错误返回值**：400, 401, 403, 404

**请求示例**:

`curl -v -s  -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example/properties  | python -m json.tool`

**返回示例**:

```json
{
    "properties": {
        "example": {
            "description": "example properties",
            "enum": [
                "11",
                "22",
                "33"
            ],
            "name": "example",
            "title": "example type",
            "type": "string"
        }
    }
}
```

### 显示具体属性信息(show)

**请求格式**：` GET  /v2/metadefs/namespaces/{namespace_name}/properties/{property_name}`

**请求参数**:  namespace_name,property_name

**正常返回值**：200

**错误返回值**：401, 403, 404

**请求示例**:

`curl -v -s  -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example/properties/example  | python -m json.tool`

**返回示例**:

```json
{
    "description": "example properties",
    "enum": [
        "11",
        "22",
        "33"
    ],
    "name": "example",
    "title": "example type",
    "type": "string"
}
```

### 更新属性信息(update)

**请求格式**：` PUT  /v2/metadefs/namespaces/{namespace_name}/properties/{property_name}`

**请求参数**:  namespace_name,property_name,name,title,type

**正常返回值**：200

**错误返回值**：400, 401, 403, 404, 409

**请求示例**:

`curl -v -s -X PUT  -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example/properties -d '{"description":"example properties","enum":["111","222","333"],"name":"example","title":"example type","type":"string"}' | python -m json.tool`

**返回示例**:

```json
{
    "description": "example properties",
    "enum": [
        "111",
        "222",
        "333"
    ],
    "name": "example",
    "title": "example type",
    "type": "string"
}
```

### 删除属性定义(delete)

**请求格式**：` DELETE  /v2/metadefs/namespaces/{namespace_name}/properties/{property_name}`

**请求参数**:  namespace_name,property_name,name,title,type

**正常返回值**：204

**错误返回值**：401, 403, 404

**请求示例**:

`curl -v -s -X DELETE  -H "X-Auth-Token:$OS_TOKEN"  http://192.168.1.10/image/v2/metadefs/namespaces/FredCo::SomeCategory::Example/properties/example  | python -m json.tool`

## 标签定义

标签定义与上面的几种类似，以下只给出api

```json
POST /v2/metadefs/namespaces/{namespace_name}/tags/{tag_name}

GET  /v2/metadefs/namespaces/{namespace_name}/tags/{tag_name}

PUT  /v2/metadefs/namespaces/{namespace_name}/tags/{tag_name}

DELETE  /v2/metadefs/namespaces/{namespace_name}/tags/{tag_name}

POST   /v2/metadefs/namespaces/{namespace_name}/tags

GET   /v2/metadefs/namespaces/{namespace_name}/tags

DELETE  /v2/metadefs/namespaces/{namespace_name}/tags
```