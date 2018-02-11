---
layout:     post
title:      "OpenStack Glance"
subtitle:   " \"Glance 源码分析\""
date:       2018-02-09 12:00:00
author:     "Hanamichi"
header-img: "img/spacex-5.jpg"
catalog: true
tags:
    - openstack
    - 云计算
---

## 整体概述

**源码版本**：glance-14.0.0，glance_store-0.20.0(openstack ocata版本)

glance源码使用了wsgi、evenlet、webob、paste等类库，需要了解这些类库的简单使用

**glance服务架构**:

![glance架构](/img/in-post/post-glance-souce/architecture.png)

glance架构是标准的c/s结构，通过restfulAPI交互。

1. client：任何应用程序都可以通过rest api访问glance服务
2. Glance Domain Controller: 作为中间件执行glance的各种功能(auth,notifier,policy,quota,location,db)，代码中通过代理类实现
3. glance store ：用来与后端存储进行交互

**glance层次图**：

![glance层次图](/img/in-post/post-glance-souce/glance_layers.png)

从层次图可以看到，客户端程序发送的所有请求都会路由到具体的处理函数，经过身份验证后进行一系列处理，其中location模块与glance store交互，连接到具体的存储后端，在与数据库交互中，registry模块的功能是可选的（暂时还不清楚，目前感觉与镜像服务的主要功能关联不大）。

## 源码具体分析

glance-api服务在glance.cmd.api的main函数中初始化，具体代码如下：

```python
def main():
    try:
        config.parse_args()
        config.set_config_defaults()
        wsgi.set_eventlet_hub()
        logging.setup(CONF, 'glance')
        notifier.set_defaults()

        if cfg.CONF.profiler.enabled:
            _notifier = osprofiler.notifier.create("Messaging",
                                                   oslo_messaging, {},
                                                   notifier.get_transport(),
                                                   "glance", "api",
                                                   cfg.CONF.bind_host)
            osprofiler.notifier.set(_notifier)
            osprofiler.web.enable(cfg.CONF.profiler.hmac_keys)
        else:
            osprofiler.web.disable()

        server = wsgi.Server(initialize_glance_store=True)
        server.start(config.load_paste_app('glance-api'), default_port=9292)
        server.wait()
    except KNOWN_EXCEPTIONS as e:
        fail(e)
```

main函数会启动一个wsgi服务器，这个服务器会加载`glance-api-paste.conf`文件的glance-api服务，并且服务器监听的默认端口是9292。

其中**initialize_glance_store**值为true，会在wsgi服务器执行start时初始化后端存储。具体代码如下：

```python
def start(self, application, default_port):
    self.application = application
    self.default_port = default_port
    self.configure()
    self.start_wsgi()
    
def configure(self, old_conf=None, has_changed=None):
    """
    other code
    """
    if self.initialize_glance_store:
        initialize_glance_store()
        
def initialize_glance_store():
    """Initialize glance store."""
    glance_store.register_opts(CONF)
    glance_store.create_stores(CONF)
    glance_store.verify_default_store()
```

glance会根据配置文件中的**stores**和**default_store**两个段初始化存储

现在从`glance/api/v2/router.py`中看API请求是如何路由的:

```python

class API(wsgi.Router):

    """WSGI router for Glance v2 API requests."""

    def __init__(self, mapper):
        custom_image_properties = images.load_custom_properties()
        reject_method_resource = wsgi.Resource(wsgi.RejectMethodController())
        
        """ other code """
        
        image_data_resource = image_data.create_resource()
        mapper.connect('/images/{image_id}/file',
                       controller=image_data_resource,
                       action='download',
                       conditions={'method': ['GET']},
                       body_reject=True)
        mapper.connect('/images/{image_id}/file',
                       controller=image_data_resource,
                       action='upload',
                       conditions={'method': ['PUT']})
        mapper.connect('/images/{image_id}/file',
                       controller=reject_method_resource,
                       action='reject',
                       allowed_methods='GET, PUT')
        
        """ other code """
        
        super(API, self).__init__(mapper)
```

从api类可以看出，每一个api请求，都会绑定到具体的controller上，action是controller中实现的函数名，这个函数就是api的响应函数,以upload操作来看:

```python
"""glance/api/v2/image_data.py"""

class ImageDataController(object):
    def __init__(self, db_api=None, store_api=None,
                 policy_enforcer=None, notifier=None,
                 gateway=None):
        if gateway is None:
            db_api = db_api or glance.db.get_api()
            store_api = store_api or glance_store
            policy = policy_enforcer or glance.api.policy.Enforcer()
            notifier = notifier or glance.notifier.Notifier()
            gateway = glance.gateway.Gateway(db_api, store_api,
                                             notifier, policy)
        self.gateway = gateway
        
        """other code"""
        
            @utils.mutating
    def upload(self, req, image_id, data, size):
        image_repo = self.gateway.get_repo(req.context)
        image = None
        refresher = None
        cxt = req.context
            
        image = image_repo.get(image_id)
        image.status = 'saving'
        
        """ other code """
        
        image_repo.save(image, from_state='queued')
        image.set_data(data, size)
        
        """ other code"""
        
        image_repo.save(image, from_state='saving')
        
        """ other code"""
```

上面的代码段只保留了几个关键函数，可以看到，上传镜像操作先是根据请求获取了镜像仓库(image_repo，创建了与数据库交互的imagerepo类和存储相关的类等，下文会提到)，再根据image_id从数据库中获取镜像的信息，之后改变状态，更新数据库，再上传数据，上传成功后再更新数据库。

其中比较重要的是对`image_repo = self.gateway.get_repo(req.context)`的理解,具体代码如下：

```python
"""glance/gateway.py"""

def get_repo(self, context):
    image_repo = glance.db.ImageRepo(context, self.db_api)
    store_image_repo = glance.location.ImageRepoProxy(
        image_repo, context, self.store_api, self.store_utils)
    quota_image_repo = glance.quota.ImageRepoProxy(
        store_image_repo, context, self.db_api, self.store_utils)
    policy_image_repo = policy.ImageRepoProxy(
        quota_image_repo, context, self.policy)
    notifier_image_repo = glance.notifier.ImageRepoProxy(
        policy_image_repo, context, self.notifier)
    if property_utils.is_property_protection_enabled():
        property_rules = property_utils.PropertyRules(self.policy)
        pir = property_protections.ProtectedImageRepoProxy(
            notifier_image_repo, context, property_rules)
        authorized_image_repo = authorization.ImageRepoProxy(
            pir, context)
    else:
        authorized_image_repo = authorization.ImageRepoProxy(
            notifier_image_repo, context)
    return authorized_image_repo
```

`glance.db.ImageRepo`类主要功能是与镜像数据库相关操作有关，**location**,**quota**,**policy**,**notifier**,**authori-zation**等模块都实现了镜像仓库代理类`ImageRepoProxy`,这些代理类都继承自`glance.domain.proxy.Repo`类，该类借用`Helper`类来将具体的函数调用定位到具体的代理类中的方法。下面以**location**模块举例，具体代码如下:

```python
"""glance/location.py"""

class ImageRepoProxy(glance.domain.proxy.Repo):

    def __init__(self, image_repo, context, store_api, store_utils):
        self.context = context
        self.store_api = store_api
        proxy_kwargs = {'context': context, 'store_api': store_api,
                        'store_utils': store_utils}
        super(ImageRepoProxy, self).__init__(image_repo,
                                             item_proxy_class=ImageProxy,
                                             item_proxy_kwargs=proxy_kwargs)

        self.db_api = glance.db.get_api()
        
     """other function"""
 
class ImageProxy(glance.domain.proxy.Image):

    locations = _locations_proxy('image', 'locations')

    def __init__(self, image, context, store_api, store_utils):
        self.image = image
        self.context = context
        self.store_api = store_api
        self.store_utils = store_utils
        proxy_kwargs = {
            'context': context,
            'image': self,
            'store_api': store_api,
        }
        super(ImageProxy, self).__init__(
            image, member_repo_proxy_class=ImageMemberRepoProxy,
            member_repo_proxy_kwargs=proxy_kwargs)
        
    def delete(self):
        """other code"""
        
    def set_data(self, data, size=None):
        """other code"""
        
    def get_data(self, offset=0, chunk_size=None):
        """other code"""
        
"""glance/domain/proxy.py"""

class Repo(object):
    def __init__(self, base, item_proxy_class=None, item_proxy_kwargs=None):
        self.base = base
        self.helper = Helper(item_proxy_class, item_proxy_kwargs)

    def get(self, item_id):
        return self.helper.proxy(self.base.get(item_id))

    def list(self, *args, **kwargs):
        items = self.base.list(*args, **kwargs)
        return [self.helper.proxy(item) for item in items]

    def add(self, item):
        base_item = self.helper.unproxy(item)
        result = self.base.add(base_item)
        return self.helper.proxy(result)

    def save(self, item, from_state=None):
        base_item = self.helper.unproxy(item)
        result = self.base.save(base_item, from_state=from_state)
        return self.helper.proxy(result)

    def remove(self, item):
        base_item = self.helper.unproxy(item)
        result = self.base.remove(base_item)
        return self.helper.proxy(result)
      
class Helper(object):
    def __init__(self, proxy_class=None, proxy_kwargs=None):
        self.proxy_class = proxy_class
        self.proxy_kwargs = proxy_kwargs or {}

    def proxy(self, obj):
        if obj is None or self.proxy_class is None:
            return obj
        return self.proxy_class(obj, **self.proxy_kwargs)

    def unproxy(self, obj):
        if obj is None or self.proxy_class is None:
            return obj
        return obj.base
      

```

`ImageRepoProxy`类初始化函数中执行超类的初始化时传入了`image_repo`实例和**location**模块的ImageProxy类，`ImageProxy`类继承自`glance.domain.proxy.Image`类，其他功能模块与**location**模块一样，都实现了相应的代理类，这些代理类是对具体镜像的具体实现。

回到上传镜像**upload**函数的具体调用中，先初始化了各个模块的相应代理类，然后根据`image_id`从数据库中获取镜像信息，返回image的过程中也同时进行了各个模块的镜像代理`ImageProxy`类的初始化。之后上传镜像数据`set_data`由location模块的`ImageProxy`中的`set_data`函数实际执行。

接下来我们分析location模块中的set_data函数，具体代码如下:

```python
    def set_data(self, data, size=None):
        if size is None:
            size = 0  # NOTE(markwash): zero -> unknown size

        """other code"""
        location, size, checksum, loc_meta = self.store_api.add_to_backend(
            CONF,
            self.image.image_id,
            utils.LimitingReader(utils.CooperativeReader(data),
                                 CONF.image_size_cap),
            size,
            context=self.context,
            verifier=verifier)

        """other code"""

        self.image.locations = [{'url': location, 'metadata': loc_meta,
                                 'status': 'active'}]
        self.image.size = size
        self.image.checksum = checksum
        self.image.status = 'active'
```

从给出的代码段中可以看出最终调用了`sotre_api.add_to_backend`实现上传数据，`store_api`实际代表的是**glance_store**模块。glance_store模块使用统一的借口调用不同的存储后端。glance_store中有一个基类`Store`,每个具体的存储后端都继承它。

接下俩我们看一下它的具体实现:

```python
"""glance_store/backend.py"""

def add_to_backend(conf, image_id, data, size, scheme=None, context=None,
                   verifier=None):
    if scheme is None:
        scheme = conf['glance_store']['default_store']
    store = get_store_from_scheme(scheme)
    return store_add_to_backend(image_id, data, size, store, context,
                                verifier)

def store_add_to_backend(image_id, data, size, store, context=None,
                         verifier=None):
    (location, size, checksum, metadata) = store.add(image_id,
                                                     data,
                                                     size,
                                                     context=context,
                                                     verifier=verifier)
    """other code"""
    return (location, size, checksum, metadata)
```

`add_to_backend`函数会先从scheme中获取当前的存储后端实例，然后继续向下调用，最终通过`store.add`这个具体的方法实现上传数据，每个存储后端都会实现基类的`add`函数。

现在通过filesystem和cinder两个存储后端类来详细说明:

```python
"""glance_store/_drivers/filesystem.py"""

class Store(glance_store.driver.Store):

    _CAPABILITIES = (capabilities.BitMasks.READ_RANDOM |
                     capabilities.BitMasks.WRITE_ACCESS |
                     capabilities.BitMasks.DRIVER_REUSABLE)
    OPTIONS = _FILESYSTEM_CONFIGS
    READ_CHUNKSIZE = 64 * units.Ki
    WRITE_CHUNKSIZE = READ_CHUNKSIZE
    FILESYSTEM_STORE_METADATA = None

    """other code"""
    
    @capabilities.check
    def add(self, image_id, image_file, image_size, context=None,
            verifier=None):

        datadir = self._find_best_datadir(image_size)
        filepath = os.path.join(datadir, str(image_id))

        if os.path.exists(filepath):
            raise exceptions.Duplicate(image=filepath)

        checksum = hashlib.md5()
        bytes_written = 0
        try:
            with open(filepath, 'wb') as f:
                for buf in utils.chunkreadable(image_file,
                                               self.WRITE_CHUNKSIZE):
                    bytes_written += len(buf)
                    checksum.update(buf)
                    if verifier:
                        verifier.update(buf)
                    f.write(buf)
        """other code"""

        checksum_hex = checksum.hexdigest()
        metadata = self._get_metadata(filepath)

        """other code"""

        return ('file://%s' % filepath, bytes_written, checksum_hex, metadata)
```

