---
layout:     post
title:      "Openstack-Nova"
subtitle:   " \"Nova源码分析\""
date:       2018-03-02 12:00:00
author:     "Hanamichi"
header-img: "img/spacex-4.jpg"
catalog: true
tags:
    - openstack
    - nova
    - 云计算

---

# Nova源码流程整理

**源码版本**：nova-15.1.0, stevedore-1.20.1(openstack ocata版本)

## Nova源码脉络

**OpenStack项目的目录结构并不是根据组件严格划分，而是根据功能划分**，以Nova为例，compute目录并不是一定在nova-compute节点上运行，而主要是和compute相关(虚拟机操作相关）的功能实现，同样的，scheduler目录代码并不全在scheduler服务节点运行，但主要是和调度相关的代码。不过目录结构并不是完全没有规律，它遵循一定的套路。

通常一个服务的目录都会包含`api.py`、`rpcapi.py`、`manager.py`，这个三个是最重要的模块。

- `api.py`： 通常是供其它组件调用的封装库。换句话说，该模块通常并不会由本模块调用。比如compute目录的api.py，通常由nova-api服务的controller调用。
- rpcapi.py：这个是RPC请求的封装，或者说是RPC封装的client端，该模块封装了RPC请求调用。
- manager.py： 这个才是真正服务的功能实现，也是RPC的服务端，即处理RPC请求的入口，实现的方法通常和rpcapi实现的方法一一对应。

比如对一个虚拟机执行关机操作：

```/
API节点
nova-api接收用户请求 -> nova-api调用compute/api.py -> compute/api调用compute/rpcapi.py -> rpcapi.py向目标计算节点发起stop_instance()RPC请求

计算节点
收到stop_instance()请求 -> 调用compute/manager.py的callback方法stop_instance() -> 调用libvirt关机虚拟机
```

前面提到OpenStack项目的目录结构是按照功能划分的，而不是服务组件，因此并不是所有的目录都能有对应的组件。以Nova来说:

- cmd：这是服务的启动脚本，即所有服务的main函数。看服务怎么初始化，就从这里开始。
- db: 封装数据库访问，目前支持的driver为sqlalchemy。
- conf：Nova的配置项声明都在这里。
- locale: 本地化处理。
- image: 封装Glance调用接口。
- network: 封装网络服务接口，根据配置不同，可能调用nova-network或者neutron。
- volume: 封装数据卷访问接口，通常是Cinder的client封装。
- virt: 这是所有支持的hypervisor驱动，主流的如libvirt、xen等。
- objects: 对象模型，封装了所有实体对象的CURD操作，相对以前直接调用db的model更安全，并且支持版本控制。
- policies： policy校验实现。
- tests: 单元测试和功能测试代码。

OpenStack所有的项目基本都可以通过项目下`setup.cfg`文件中了解，其中`console_scripts`就是所有服务组件的入口，比如nova的`setup.cfg`的`console_scripts`如下:

```sheel
[entry_points]
...
console_scripts = 
	nova-api = nova.cmd.api:main
	nova-api-metadata = nova.cmd.api_metadata:main
	nova-api-os-compute = nova.cmd.api_os_compute:main
	nova-cells = nova.cmd.cells:main
	nova-cert = nova.cmd.cert:main
	nova-compute = nova.cmd.compute:main
	nova-conductor = nova.cmd.conductor:main
	nova-console = nova.cmd.console:main
	nova-consoleauth = nova.cmd.consoleauth:main
	nova-dhcpbridge = nova.cmd.dhcpbridge:main
	nova-idmapshift = nova.cmd.idmapshift:main
	nova-manage = nova.cmd.manage:main
	nova-network = nova.cmd.network:main
	nova-novncproxy = nova.cmd.novncproxy:main
	nova-policy = nova.cmd.policy_check:main
	nova-rootwrap = oslo_rootwrap.cmd:main
	nova-rootwrap-daemon = oslo_rootwrap.cmd:daemon
	nova-scheduler = nova.cmd.scheduler:main
	nova-serialproxy = nova.cmd.serialproxy:main
	nova-spicehtml5proxy = nova.cmd.spicehtml5proxy:main
	nova-status = nova.cmd.status:main
	nova-xvpvncproxy = nova.cmd.xvpvncproxy:main
...
```

## Nova API服务启动与extension加载

Openstack 在启动 nova-api service 时，会根据 Nova 配置文件 **nova.conf**中的配置项 enabled_apis = ec2,osapi_compute,metadata 来创建一个或多个 WSGI Server 。每一个 WSGI Server 负责处理一种类型的 Nova API 请求，上述的选项值表示了三种类型的 Nova API 。

**nova-api**入口`nova.cmd.api.main()`

```python
"""nova/cmd/api.py"""
def main:
    '''other code'''
    
    launcher = service.process_launcher()
    started = 0
    for api in CONF.enabled_apis:
        should_use_ssl = api in CONF.enabled_ssl_apis
        try:
            server = service.WSGIService(api, use_ssl=should_use_ssl)
            launcher.launch_service(server, workers=server.workers or 1)
            started += 1
        except exception.PasteAppNotFound as ex:
            log.warning(
                _LW("%s. ``enabled_apis`` includes bad values. "
                    "Fix to remove this warning."), ex)

    if started == 0:
        log.error(_LE('No APIs were started. '
                      'Check the enabled_apis config option.'))
        sys.exit(1)

    launcher.wait()
```

其中`server = service.WSGIService(api, use_ssl=should_use_ssl)`，假定api=osapi_compute, `service.WSGIService`类的`__init__`函数中有`self.app = self.loader.load_app(name)`，此处loader为wsgi模块中Loader的实例，初始化时提供了self.config_path,为api-paster.ini的路径，来看load_app方法：

```python
class Loader(object):
    """other code"""

    def load_app(self, name):
        """Return the paste URLMap wrapped WSGI application.

        :param name: Name of the application to load.
        :returns: Paste URLMap object wrapping the requested application.
        :raises: `nova.exception.PasteAppNotFound`

        """
        try:
            LOG.debug("Loading app %(name)s from %(path)s",
                      {'name': name, 'path': self.config_path})
            return deploy.loadapp("config:%s" % self.config_path, name=name)
        except LookupError:
            LOG.exception(_LE("Couldn't lookup app: %s"), name)
            raise exception.PasteAppNotFound(name=name, path=self.config_path)
```

这个方法调用了paste库deploy模块的deploy.loadapp方法，并提供了两个参数：加了config:前缀的api-paste.ini文件的路径以及服务名osapi_compute。

下面是api-paste.ini文件的部分内容:

```ini
#############
# OpenStack #
#############

[composite:osapi_compute]
use = call:nova.api.openstack.urlmap:urlmap_factory
/: oscomputeversions
# v21 is an exactly feature match for v2, except it has more stringent
# input validation on the wsgi surface (prevents fuzzing early on the
# API). It also provides new features via API microversions which are
# opt into for clients. Unaware clients will receive the same frozen
# v2 API feature set, but with some relaxed validation
/v2: openstack_compute_api_v21_legacy_v2_compatible
/v2.1: openstack_compute_api_v21

[composite:openstack_compute_api_v21]
use = call:nova.api.auth:pipeline_factory_v21
noauth2 = cors http_proxy_to_wsgi compute_req_id faultwrap sizelimit osprofiler noauth2 osapi_compute_app_v21
keystone = cors http_proxy_to_wsgi compute_req_id faultwrap sizelimit osprofiler authtoken keystonecontext osapi_compute_app_v21

#.....

[app:osapi_compute_app_v21]
paste.app_factory = nova.api.openstack.compute:APIRouterV21.factory

#.....
```

接下来简单介绍一下具体的实现，先看用于处理osapi_compute的nova.api.openstack.urlmap.urlmap_factory方法(以/v2.1为例)：

```python
"""nova/api/openstack/urlmap.py"""
def urlmap_factory(loader, global_conf, **local_conf):
    if 'not_found_app' in local_conf:
        not_found_app = local_conf.pop('not_found_app')
    else:
        not_found_app = global_conf.get('not_found_app')
    if not_found_app:
        not_found_app = loader.get_app(not_found_app, global_conf=global_conf)
    urlmap = URLMap(not_found_app=not_found_app)
    for path, app_name in local_conf.items():
        path = paste.urlmap.parse_path_expression(path)
        app = loader.get_app(app_name, global_conf=global_conf)
        urlmap[path] = app
    return urlmap
```

根据api-paste.ini文件的描述，当执行`app = loader.get_app(app_name, global_conf=global_conf)`这行代码时，deploy内部代码逻辑会使用nova.api.auth.pipeline_factory_v21方法：

```python
"""nova/api/auth.py"""
def pipeline_factory_v21(loader, global_conf, **local_conf):
    """A paste pipeline replica that keys off of auth_strategy."""
    return _load_pipeline(loader, local_conf[CONF.api.auth_strategy].split())

def _load_pipeline(loader, pipeline):
    filters = [loader.get_filter(n) for n in pipeline[:-1]]
    app = loader.get_app(pipeline[-1])
    filters.reverse()
    for filter in filters:
        app = filter(app)
    return app
```

这时，通过CONF.auth_strategy可以指定所使用的auth策略。假定使用keystone策略，进入**_load_pipeline**方法，这个函数会根据api-paste.ini文件中相应的pipeline取得filter,依次对app进行处理。

所有filter处理完成之后，会达到具体的app，根据配置文件可以看出，最后的处理函数是`nova.api.openstack.compute:APIRouterV21.factory`

```python
"""/nova/api/openstack/__init__.py"""
class APIRouterV21(base_wsgi.Router):
    """Routes requests on the OpenStack v2.1 API to the appropriate controller
    and method.
    """

    @classmethod
    def factory(cls, global_config, **local_config):
        """Simple paste factory, :class:`nova.wsgi.Router` doesn't have one."""
        return cls()
    """other code"""
```

返回了nova.api.openstack.compute.APIRouterV21这个类本身：

```python
"""nova/api/openstack/compute/__init__.py"""
class APIRouterV21(nova.api.openstack.APIRouterV21):
    """Routes requests on the OpenStack API to the appropriate controller
    and method.
    """
    def __init__(self):
        self._loaded_extension_info = extension_info.LoadedExtensionInfo()
        super(APIRouterV21, self).__init__()

    def _register_extension(self, ext):
        return self.loaded_extension_info.register_extension(ext.obj)

    @property
    def loaded_extension_info(self):
        return self._loaded_extension_info

"""nova/api/openstack/compute/extension_info.py"""
class LoadedExtensionInfo(object):
    """Keep track of all loaded API extensions."""

    def __init__(self):
        self.extensions = {}
    """other code"""
```

从上面的代码可以看出，首先初始化了一个`self.extensions = {}`,之后调用了父类的`__init__`：

```python
"""/nova/api/openstack/__init__.py"""
class APIRouterV21(base_wsgi.Router):
    """other code"""
    def __init__(self):
        def _check_load_extension(ext):
            return self._register_extension(ext)

        self.api_extension_manager = stevedore.enabled.EnabledExtensionManager(
            namespace=self.api_extension_namespace(),
            check_func=_check_load_extension,
            invoke_on_load=True,
            invoke_kwds={"extension_info": self.loaded_extension_info})

        mapper = ProjectMapper()

        self.resources = {}

        # NOTE(cyeoh) Core API support is rewritten as extensions
        # but conceptually still have core
        if list(self.api_extension_manager):
            # NOTE(cyeoh): Stevedore raises an exception if there are
            # no plugins detected. I wonder if this is a bug.
            self._register_resources_check_inherits(mapper)
            self.api_extension_manager.map(self._register_controllers)

        LOG.info(_LI("Loaded extensions: %s"),
                 sorted(self.loaded_extension_info.get_extensions().keys()))
        super(APIRouterV21, self).__init__(mapper)
```

首先来看这段代码:

```python
self.api_extension_manager = stevedore.enabled.EnabledExtensionManager(
            namespace=self.api_extension_namespace(),
            check_func=_check_load_extension,
            invoke_on_load=True,
            invoke_kwds={"extension_info": self.loaded_extension_info})
```

其中`stevedore.enabled.EnabledExtensionManager`类如下：

```python
"""stevedore/enabled.py"""
class EnabledExtensionManager(ExtensionManager):
    def __init__(self, namespace, check_func, invoke_on_load=False,
                 invoke_args=(), invoke_kwds={},
                 propagate_map_exceptions=False,
                 on_load_failure_callback=None,
                 verify_requirements=False,):
        self.check_func = check_func
        super(EnabledExtensionManager, self).__init__(
            namespace,
            invoke_on_load=invoke_on_load,
            invoke_args=invoke_args,
            invoke_kwds=invoke_kwds,
            propagate_map_exceptions=propagate_map_exceptions,
            on_load_failure_callback=on_load_failure_callback,
            verify_requirements=verify_requirements,
        )

    def _load_one_plugin(self, ep, invoke_on_load, invoke_args, invoke_kwds,
                         verify_requirements):
        ext = super(EnabledExtensionManager, self)._load_one_plugin(
            ep, invoke_on_load, invoke_args, invoke_kwds,
            verify_requirements,
        )
        if ext and not self.check_func(ext):
            LOG.debug('ignoring extension %r', ep.name)
            return None
        return ext
```

从上面两段代码可以看出，定义了`self.check_func`为`_check_load_extension`,这个函数的参数是`ext`,如果**ext.obj**是**extensions.V21APIExtensionBase**的实例，会对其调用**_register_extension**方法。

下面继续看调用的父类`ExtensionManager`的`__init__`:

```python
"""stevedore/extension.py"""
class ExtensionManager(object):
    def __init__(self, namespace,
                 invoke_on_load=False,
                 invoke_args=(),
                 invoke_kwds={},
                 propagate_map_exceptions=False,
                 on_load_failure_callback=None,
                 verify_requirements=False):
        self._init_attributes(
            namespace,
            propagate_map_exceptions=propagate_map_exceptions,
            on_load_failure_callback=on_load_failure_callback)
        extensions = self._load_plugins(invoke_on_load,
                                        invoke_args,
                                        invoke_kwds,
                                        verify_requirements)
        self._init_plugins(extensions)
    """other code"""
```

该函数把传入参数进行简单的赋值，重点看**_load_plugins**函数：

```python
"""stevedore/extension.py"""
class ExtensionManager(object):
    """other code"""
    def _load_plugins(self, invoke_on_load, invoke_args, invoke_kwds,
                      verify_requirements):
        extensions = []
        for ep in self.list_entry_points():
            LOG.debug('found extension %r', ep)
            try:
                ext = self._load_one_plugin(ep,
                                            invoke_on_load,
                                            invoke_args,
                                            invoke_kwds,
                                            verify_requirements,
                                            )
                if ext:
                    extensions.append(ext)
            except (KeyboardInterrupt, AssertionError):
                raise
            except Exception as err:
                if self._on_load_failure_callback is not None:
                    self._on_load_failure_callback(self, ep, err)
                else:
                    # Log the reason we couldn't import the module,
                    # usually without a traceback. The most common
                    # reason is an ImportError due to a missing
                    # dependency, and the error message should be
                    # enough to debug that.  If debug logging is
                    # enabled for our logger, provide the full
                    # traceback.
                    LOG.error('Could not load %r: %s', ep.name, err,
                              exc_info=LOG.isEnabledFor(logging.DEBUG))
        return extensions
    """other code"""
```

函数体在循环`for ep in self.list_entry_points()`中，函数代码如下:

```python
"""stevedore/extension.py"""
class ExtensionManager(object):
    """other code"""
    def list_entry_points(self):
        if self.namespace not in self.ENTRY_POINT_CACHE:
            eps = list(pkg_resources.iter_entry_points(self.namespace))
            self.ENTRY_POINT_CACHE[self.namespace] = eps
        return self.ENTRY_POINT_CACHE[self.namespace]
    """other code"""
```

**self.namespace**的值是**nova.api.openstack.compute.APIRouterV21**传入的`nova.api.v21.extensions`

使用了pkg_resources模块中iter_entry_points方法。这个方法返回一个生成器，每次返回一个EntryPoint实例，所以返回的eps值为`nova.api.v21.extensions`这个entry point section生成的entrypoint实例列表。

entrypoint组可在nova-egg中entry_points.txt中找到:

```txt
[nova.api.v21.extensions]
admin_actions = nova.api.openstack.compute.admin_actions:AdminActions
admin_password = nova.api.openstack.compute.admin_password:AdminPassword
agents = nova.api.openstack.compute.agents:Agents
aggregates = nova.api.openstack.compute.aggregates:Aggregates
assisted_volume_snapshots = nova.api.openstack.compute.assisted_volume_snapshots:AssistedVolumeSnapshots
attach_interfaces = nova.api.openstack.compute.attach_interfaces:AttachInterfaces
availability_zone = nova.api.openstack.compute.availability_zone:AvailabilityZone
baremetal_nodes = nova.api.openstack.compute.baremetal_nodes:BareMetalNodes
block_device_mapping = nova.api.openstack.compute.block_device_mapping:BlockDeviceMapping
cells = nova.api.openstack.compute.cells:Cells
certificates = nova.api.openstack.compute.certificates:Certificates
cloudpipe = nova.api.openstack.compute.cloudpipe:Cloudpipe
config_drive = nova.api.openstack.compute.config_drive:ConfigDrive
console_auth_tokens = nova.api.openstack.compute.console_auth_tokens:ConsoleAuthTokens
console_output = nova.api.openstack.compute.console_output:ConsoleOutput
consoles = nova.api.openstack.compute.consoles:Consoles
#......
```

section中定义的各列以`name=module:attr [extras]`格式，传入到EntryPoint类的`__init__`中，生成实例。 

继续看`self._load_one_plugin`：

```python
"""stevedore/extension.py"""
class ExtensionManager(object):
    """other code"""
    def _load_one_plugin(self, ep, invoke_on_load, invoke_args, invoke_kwds,
                         verify_requirements):
        # NOTE(dhellmann): Using require=False is deprecated in
        # setuptools 11.3.
        if hasattr(ep, 'resolve') and hasattr(ep, 'require'):
            if verify_requirements:
                ep.require()
            plugin = ep.resolve()
        else:
            plugin = ep.load(require=verify_requirements)
        if invoke_on_load:
            obj = plugin(*invoke_args, **invoke_kwds)
        else:
            obj = None
        return Extension(ep.name, ep, plugin, obj)
```

这段代码里面使用的方法很简单，最后获得的各变量为：

```
plugin = 扩展模块中定义为attr的类
obj = attr类的实例，其中传入了参数extension_info = self.loaded_extension_info,即nova.api.openstack.compute.extension_info中LoadedExtensionInfo类实例
```

方法最后返回了一个stevedore.extension.Extension的实例。

所以`extensions = _load_plugins()`这个方法，得到了Extension实例的列表。 
继续往下`self._init_plugins(extensions)`很简单的将实例的self.extensions赋值为上面得到的列表。

到此stevedore.enabled.EnabledExtensionManager类实例的初始化完成，并将实例赋值给了APIRouterV21的self.api_extension_manager。

继续回到APIRouterV21，`mapper = ProjectMapper()`得到的实例后续使用时分析。下面代码运行至 
`if list(self.api_extension_manager)`时，启用了代码定义的`__iter__`，检查了self.extensions列表是否为空。当不为空时，看`self._register_resources_check_inherits(mapper)`:

```python
"""/nova/api/openstack/__init__.py"""
class APIRouterV21(base_wsgi.Router):
    """other code"""
    def _register_resources_check_inherits(self, mapper):
        ext_has_inherits = []
        ext_no_inherits = []

        for ext in self.api_extension_manager:
            for resource in ext.obj.get_resources():
                if resource.inherits:
                    ext_has_inherits.append(ext)
                    break
            else:
                ext_no_inherits.append(ext)

        self._register_resources_list(ext_no_inherits, mapper)
        self._register_resources_list(ext_has_inherits, mapper)
```

ext.obj以上已经提及，是扩展类的实例。在扩展类中，都各自复写了`get_resource()`方法。当此方法返回nova.api.openstack.extensions.ResourceExtension实例，且实例参数中inherits的bool为True时，该扩展类会被添加进ext_has_inherits列表中，而不符合条件的会被添加进ext_no_inherits列表。 

接下来看`self._register_resources_list()`中的`self._register_resources(ext, mapper)`:

```python
"""/nova/api/openstack/__init__.py"""
class APIRouterV21(base_wsgi.Router):
    """other code"""
    def _register_resources(self, ext, mapper):
        handler = ext.obj
        LOG.debug("Running _register_resources on %s", ext.obj)

        for resource in handler.get_resources():
            LOG.debug('Extended resource: %s', resource.collection)

            inherits = None
            if resource.inherits:
                inherits = self.resources.get(resource.inherits)
                if not resource.controller:
                    resource.controller = inherits.controller
            wsgi_resource = wsgi.ResourceV21(resource.controller,
                                             inherits=inherits)
            self.resources[resource.collection] = wsgi_resource
            kargs = dict(
                controller=wsgi_resource,
                collection=resource.collection_actions,
                member=resource.member_actions)

            if resource.parent:
                kargs['parent_resource'] = resource.parent

            # non core-API plugins use the collection name as the
            # member name, but the core-API plugins use the
            # singular/plural convention for member/collection names
            if resource.member_name:
                member_name = resource.member_name
            else:
                member_name = resource.collection
            mapper.resource(member_name, resource.collection,
                            **kargs)

            if resource.custom_routes_fn:
                resource.custom_routes_fn(mapper, wsgi_resource)
```

可以看到在代码中循环控制中，如果`ext.obj.get_resource()`返回为空，则在此不进行任何处理。

其中重点看` wsgi_resource = wsgi.ResourceV21(resource.controller,inherits=inherits)`这个调用，查看`wsgi.ResourceV21`这个类的初始化方法，继承了父类的`__init__`：

```python
"""nova/api/openstack/wsgi.py"""
class Resource(wsgi.Application):
    support_api_request_version = False

    def __init__(self, controller, inherits=None):
        """:param controller: object that implement methods created by routes
                              lib
           :param inherits: another resource object that this resource should
                            inherit extensions from. Any action extensions that
                            are applied to the parent resource will also apply
                            to this resource.
        """

        self.controller = controller

        self.default_serializers = dict(json=JSONDictSerializer)

        # Copy over the actions dictionary
        self.wsgi_actions = {}
        if controller:
            self.register_actions(controller)

        # Save a mapping of extensions
        self.wsgi_extensions = {}
        self.wsgi_action_extensions = {}
        self.inherits = inherits
```

看其中的`self.register_actions(controller)`：

```python
"""nova/api/openstack/wsgi.py"""
class Resource(wsgi.Application):    
    def register_actions(self, controller):
        """Registers controller actions with this resource."""

        actions = getattr(controller, 'wsgi_actions', {})
        for key, method_name in actions.items():
            self.wsgi_actions[key] = getattr(controller, method_name)
     """other code"""
```

看到`actions = getattr(controller, 'wsgi_actions', {})`这行代码，发现controller里有一个wsgi_action的字典，在此其值为空。此字典如何生成在此先不详解，所以`register_actions`这个方法实际没有做操作。

那么我们就可以知道这个`ResourceV21`类的初始化只是简单的对类实例的参数进行了赋值，提供一些方法。最后我们知道wsgi_resource的值为这个类的实例。

下面在看`mapper.resource()`这个方法之前，mapper变量的值是`nova.api.openstack.ProjectMapper`这个类的实例。并且，在类中已经对`resource()`这个方法进行了重写。由于在此需要了解routes库中mapper模块。

在`mapper.resource()`中，对各个extension模块定义的方法映射路由。（这个具体参考routes模块，之后补充）

回到上层，代码走到`resource.custom_routes_fn(mapper, wsgi_resource)`,作用在此先不说明,接触相关概念时再进行回顾。

回到APIRouterV21层，`self.api_extension_manager.map(self._register_controllers)`这段，主要是将函数_register_controllers传入extension中

```python
"""/nova/api/openstack/__init__.py"""
class APIRouterV21(base_wsgi.Router):
    """other code"""
    def _register_controllers(self, ext):
        handler = ext.obj
        LOG.debug("Running _register_controllers on %s", ext.obj)

        for extension in handler.get_controller_extensions():
            ext_name = extension.extension.name
            collection = extension.collection
            controller = extension.controller

            if collection not in self.resources:
                LOG.warning(_LW('Extension %(ext_name)s: Cannot extend '
                                'resource %(collection)s: No such resource'),
                            {'ext_name': ext_name, 'collection': collection})
                continue

            LOG.debug('Extension %(ext_name)s extending resource: '
                      '%(collection)s',
                      {'ext_name': ext_name, 'collection': collection})

            resource = self.resources[collection]
            resource.register_actions(controller)
            resource.register_extensions(controller)
```

以admin_actions.py扩展模块为例，`resource = self.resource["servers"]`, 那么`controller = AdminActionsController()`。又回到了之前提到的问题：`register_actions()`方法中`actions = getattr(controller, 'wsgi_actions', {})`，这个’wsgi_actions’标签是哪里来的？我们看AdminActionsController的父类`api.openstack.wsgi.Controller`,这个类有一个装饰器:

```python
@six.add_metaclass(ControllerMetaclass)
class Controller(object):
    """other code"""
```

用six库的`add_metaclass`方法给这个类增加了一个metaclass`api.openstack.wsgi.ControllerMetaclass`。

```python
class ControllerMetaclass(type):
    def __new__(mcs, name, bases, cls_dict):
        """other code"""

        for key, value in cls_dict.items():
            if not callable(value):
                continue
            if getattr(value, 'wsgi_action', None):
                actions[value.wsgi_action] = key
            elif getattr(value, 'wsgi_extends', None):
                extensions.append(value.wsgi_extends)

        # Add the actions and extensions to the class dict
        cls_dict['wsgi_actions'] = actions
        cls_dict['wsgi_extensions'] = extensions
        if versioned_methods:
            cls_dict[VER_METHOD_ATTR] = versioned_methods

        return super(ControllerMetaclass, mcs).__new__(mcs, name, bases,
                                                       cls_dict)
```

对于由这个metaclass控制生成的class，会对controller类中定义的所有方法中尝试以`wsgi_action`及`wsgi_extends`作为key来获取value，并且以dict=(value, 方法名称str)的形式存入到controller类的wsgi_actions及wsgi_extensions属性中。 

再回到admin_actions.py中，可看到类似装饰器`@wsgi.action('resetNetwork')`,查看装饰器代码：

```python
"""nova/api/openstack/wsgi.py"""
def action(name):
    def decorator(func):
        func.wsgi_action = name
        return func
    return decorator
```

此装饰器可以给类中的方法做上wsgi_action属性，value为装饰器接收的参数。如：

```python
dict=(wsgi.action(name)装饰器接收的name， controller中对应的func.__name__)
```

下面是`@wsgi.extends`装饰器：

```python
"""nova/api/openstack/wsgi.py"""
def extends(*args, **kwargs):
    """Indicate a function extends an operation.

    Can be used as either::

        @extends
        def index(...):
            pass

    or as::

        @extends(action='resize')
        def _action_resize(...):
            pass
    """

    def decorator(func):
        # Store enough information to find what we're extending
        func.wsgi_extends = (func.__name__, kwargs.get('action'))
        return func

    # If we have positional arguments, call the decorator
    if args:
        return decorator(*args)

    # OK, return the decorator instead
    return decorator
```

wsgi_extends赋值为`(方法名， 装饰器接收的action参数的值）`的tuple，则controller类中wsgi_extensions属性为各func生成的tuple的列表。如： 

`[(controller中对应的func.__name__, wsgi.extends(action=name)中的name），...]` 

知道了参数的来源与格式，再看`register_actions`和`register_extensions`这两个方法：

```python
"""nova/api/openstack/wsgi.py"""
class Resource(wsgi.Application):
    def register_actions(self, controller):
        """Registers controller actions with this resource."""

        actions = getattr(controller, 'wsgi_actions', {})
        for key, method_name in actions.items():
            self.wsgi_actions[key] = getattr(controller, method_name)
    """other code"""
```

为resource增加了wsgi_actions属性, 内容为如下dict映射：

```
wsgi_actions[wsgi.action(name)中的name] = controller中的func
```

回到APIRouterV21层，至此APIRouterV21层初始化完毕。将mapper作为参数传入父类`nova.wsgi.Router`的初始化方法。

关于routes.middleware: <http://routes.readthedocs.io/en/latest/porting.html#routesmiddleware> 
关于webob.desc.wsgify: <http://docs.webob.org/en/latest/api/dec.html?highlight=wsgify>

## Nova API具体流程分析

### 创建虚拟机流程

#### *step1.  nova-api*

入口为nova/api/openstack/compute/servers.py的create方法，该方法检查了一堆参数以及policy后，调用`compute_api`的create方法。

```python
"""nova/api/openstack/compute/servers.py"""
class ServersController(wsgi.Controller):
    """The Server API base controller class for the OpenStack API."""
    def create(self, req, body):
        """Creates a new server for a given user."""

        context = req.environ['nova.context']
        server_dict = body['server']
        password = self._get_server_admin_password(server_dict)
        name = common.normalize_name(server_dict['name'])
        
        """....other code"""

        flavor_id = self._flavor_id_from_req_data(body)
        try:
            inst_type = flavors.get_flavor_by_flavor_id(
                    flavor_id, ctxt=context, read_deleted="no")

            (instances, resv_id) = self.compute_api.create(context,
                            inst_type,
                            image_uuid,
                            display_name=name,
                            display_description=description,
                            availability_zone=availability_zone,
                            forced_host=host, forced_node=node,
                            metadata=server_dict.get('metadata', {}),
                            admin_password=password,
                            requested_networks=requested_networks,
                            check_server_group_quota=True,
                            **create_kwargs)
        except (exception.QuotaError,
                exception.PortLimitExceeded) as error:
            raise exc.HTTPForbidden(
                explanation=error.format_message())
        """other code"""
```

这里的`compute_api`即前面说的`nova/compute/api.py`模块，找到该模块的create方法，该方法会创建数据库记录、检查参数等，最终调用`compute_task_api`的`_create_instance`方法:

```python
"""nova/compute/api.py"""
class API(base.Base):
    @hooks.add_hook("create_instance")
    def create(self, context, instance_type,
               image_href, kernel_id=None, ramdisk_id=None,
               min_count=None, max_count=None,
               display_name=None, display_description=None,
               key_name=None, key_data=None, security_groups=None,
               availability_zone=None, forced_host=None, forced_node=None,
               user_data=None, metadata=None, injected_files=None,
               admin_password=None, block_device_mapping=None,
               access_ip_v4=None, access_ip_v6=None, requested_networks=None,
               config_drive=None, auto_disk_config=None, scheduler_hints=None,
               legacy_bdm=True, shutdown_terminate=False,
               check_server_group_quota=False):
        """other code"""
        return self._create_instance(
                       context, instance_type,
                       image_href, kernel_id, ramdisk_id,
                       min_count, max_count,
                       display_name, display_description,
                       key_name, key_data, security_groups,
                       availability_zone, user_data, metadata,
                       injected_files, admin_password,
                       access_ip_v4, access_ip_v6,
                       requested_networks, config_drive,
                       block_device_mapping, auto_disk_config,
                       filter_properties=filter_properties,
                       legacy_bdm=legacy_bdm,
                       shutdown_terminate=shutdown_terminate,
                       check_server_group_quota=check_server_group_quota)
    
    def _create_instance(self, context, instance_type,
               image_href, kernel_id, ramdisk_id,
               min_count, max_count,
               display_name, display_description,
               key_name, key_data, security_groups,
               availability_zone, user_data, metadata, injected_files,
               admin_password, access_ip_v4, access_ip_v6,
               requested_networks, config_drive,
               block_device_mapping, auto_disk_config, filter_properties,
               reservation_id=None, legacy_bdm=True, shutdown_terminate=False,
               check_server_group_quota=False):
        """Verify all the input parameters regardless of the provisioning
        strategy being performed and schedule the instance(s) for
        creation.
        """
        """other code"""
        if CONF.cells.enable:
            # NOTE(danms): CellsV1 can't do the new thing, so we
            # do the old thing here. We can remove this path once
            # we stop supporting v1.
            for instance in instances:
                instance.create()
            self.compute_task_api.build_instances(context,
                instances=instances, image=boot_meta,
                filter_properties=filter_properties,
                admin_password=admin_password,
                injected_files=injected_files,
                requested_networks=requested_networks,
                security_groups=security_groups,
                block_device_mapping=block_device_mapping,
                legacy_bdm=False)
        else:
            self.compute_task_api.schedule_and_build_instances(
                context,
                build_requests=build_requests,
                request_spec=request_specs,
                image=boot_meta,
                admin_password=admin_password,
                injected_files=injected_files,
                requested_networks=requested_networks,
                block_device_mapping=block_device_mapping)
        return (instances, reservation_id)
```

`compute_task_api`即conductor的conductor.ComputeTaskAPI()实例。conductor的api并没有执行什么操作。直接调用了`conductor_compute_rpcapi`的`build_instances`方法。

该方法即是conductor RPC调用api，即`nova/conductor/rpcapi.py`模块。

```python
"""nova/conductor/api.py"""
class ComputeTaskAPI(object):
    """ComputeTask API that queues up compute tasks for nova-conductor."""
    def build_instances(self, context, instances, image, filter_properties,
            admin_password, injected_files, requested_networks,
            security_groups, block_device_mapping, legacy_bdm=True):
        self.conductor_compute_rpcapi.build_instances(context,
                instances=instances, image=image,
                filter_properties=filter_properties,
                admin_password=admin_password, injected_files=injected_files,
                requested_networks=requested_networks,
                security_groups=security_groups,
                block_device_mapping=block_device_mapping,
                legacy_bdm=legacy_bdm)
    """other code"""
    
"""nova/conductor/rpcapi.py"""
@profiler.trace_cls("rpc")
class ComputeTaskAPI(object):
    def build_instances(self, context, instances, image, filter_properties,
            admin_password, injected_files, requested_networks,
            security_groups, block_device_mapping, legacy_bdm=True):
        """other code """
        cctxt = self.client.prepare(version=version)
        cctxt.cast(context, 'build_instances', **kw)
    """other code"""
```
该模块主要代码只有两行:

```python
cctxt = self.client.prepare(version=version)
cctxt.cast(context, 'build_instances', **kw)
```

其中cast表示异步调用，`build_instances`是远程调用的方法，`kw`是传递的参数。参数是字典类型，没有复杂对象结构，因此不需要特别的序列化操作。

截至到现在，虽然目录由`api->compute->conductor`，但仍在nova-api进程中运行，直到cast方法执行，该方法由于是异步调用，因此nova-api任务完成，此时会响应用户请求，虚拟机状态为`building`。

#### *step2.  nova-conductor*

由于是向nova-conductor发起的RPC调用，而前面说了接收端肯定是`manager.py`，因此进程跳到`nova-conductor`服务，入口为`nova/conductor/manager.py`的`build_instances`方法，该方法首先调用了`_schedule_instances`方法，该方法调用了`scheduler_client`的`select_destinations`方法:

```python
"""nova/conductor/manager.py"""
@profiler.trace_cls("rpc")
class ComputeTaskManager(base.Base):
    def build_instances(self, context, instances, image, filter_properties,
            admin_password, injected_files, requested_networks,
            security_groups, block_device_mapping=None, legacy_bdm=True):
        """other code"""
        try:
            # check retry policy. Rather ugly use of instances[0]...
            # but if we've exceeded max retries... then we really only
            # have a single instance.
            request_spec = scheduler_utils.build_request_spec(
                context, image, instances)
            scheduler_utils.populate_retry(
                filter_properties, instances[0].uuid)
            hosts = self._schedule_instances(
                    context, request_spec, filter_properties)
        """other code"""
    
    def _schedule_instances(self, context, request_spec, filter_properties):
        scheduler_utils.setup_instance_group(context, request_spec,
                                             filter_properties)
        # TODO(sbauza): Hydrate here the object until we modify the
        # scheduler.utils methods to directly use the RequestSpec object
        spec_obj = objects.RequestSpec.from_primitives(
            context, request_spec, filter_properties)
        hosts = self.scheduler_client.select_destinations(context, spec_obj)
        return hosts
```

`scheduler_client`和`compute_api`以及`compute_task_api`都是一样对服务的client调用，不过scheduler没有`api.py`，而是有个单独的client目录，实现在client目录的`__init__.py`，这里仅仅是调用query.py下的SchedulerQueryClient的`select_destinations`实现，然后又很直接的调用了`scheduler_rpcapi`的`select_destinations`方法。具体代码块如下:

```python
"""nova/scheduler/client/__init__.py"""
class SchedulerClient(object):
    """Client library for placing calls to the scheduler."""
    def __init__(self):
        self.queryclient = LazyLoader(importutils.import_class(
            'nova.scheduler.client.query.SchedulerQueryClient'))
        self.reportclient = LazyLoader(importutils.import_class(
            'nova.scheduler.client.report.SchedulerReportClient'))

    @utils.retry_select_destinations
    def select_destinations(self, context, spec_obj):
        return self.queryclient.select_destinations(context, spec_obj)
"""nova/scheduler/client/query.py"""
class SchedulerQueryClient(object):
    def select_destinations(self, context, spec_obj):
        return self.scheduler_rpcapi.select_destinations(context, spec_obj)
    """other code"""
```

RPC封装同样是在scheduler的rpcapi中实现。该方法RPC调用代码如下:

```python
@profiler.trace_cls("rpc")
class SchedulerAPI(object):
    def select_destinations(self, ctxt, spec_obj):
        version = '4.3'
        msg_args = {'spec_obj': spec_obj}
        if not self.client.can_send_version(version):
            del msg_args['spec_obj']
            msg_args['request_spec'] = spec_obj.to_legacy_request_spec_dict()
            msg_args['filter_properties'
                     ] = spec_obj.to_legacy_filter_properties_dict()
            version = '4.0'
        cctxt = self.client.prepare(version=version)
        return cctxt.call(ctxt, 'select_destinations', **msg_args)
```

同样的，最重要的还是`cctxt.call(ctxt, 'select_destinations', **msg_args)`

注意这里调用的call方法，即同步RPC调用，此时nova-conductor并不会退出，而是堵塞等待直到nova-scheduler返回。因此当前状态为nova-conductor为blocked状态，等待nova-scheduler返回，nova-scheduler接管任务。

#### *step3.  nova-scheduler*

同理找到scheduler的manager.py模块的`select_destinations`方法，该方法会调用driver方法，这里的driver其实就是调度算法实现，通常用的比较多的就是`filter_scheduler`的，对应`filter_scheduler.py`模块，该模块首先通过`host_manager`拿到所有的计算节点信息，然后通过filters过滤掉不满足条件的计算节点，剩下的节点通过weigh方法计算权值，最后选择权值高的作为候选计算节点返回。最后nova-scheduler返回调度结果的hosts集合，任务结束，返回到nova-conductor服务。

```python
"""nova/schedule/manager.py"""
class SchedulerManager(manager.Manager):
    """other code"""
    @messaging.expected_exceptions(exception.NoValidHost)
    def select_destinations(self, ctxt,
                            request_spec=None, filter_properties=None,
                            spec_obj=_sentinel):
        """Returns destinations(s) best suited for this RequestSpec.

        The result should be a list of dicts with 'host', 'nodename' and
        'limits' as keys.
        """

        # TODO(sbauza): Change the method signature to only accept a spec_obj
        # argument once API v5 is provided.
        if spec_obj is self._sentinel:
            spec_obj = objects.RequestSpec.from_primitives(ctxt,
                                                           request_spec,
                                                           filter_properties)
        dests = self.driver.select_destinations(ctxt, spec_obj)
        return jsonutils.to_primitive(dests)
    
"""nova/schedule/filter_scheduler.py"""
class FilterScheduler(driver.Scheduler):
    """Scheduler that can be used for filtering and weighing."""
    """other code"""
    def select_destinations(self, context, spec_obj):
        """Selects a filtered set of hosts and nodes."""
        self.notifier.info(
            context, 'scheduler.select_destinations.start',
            dict(request_spec=spec_obj.to_legacy_request_spec_dict()))

        num_instances = spec_obj.num_instances
        selected_hosts = self._schedule(context, spec_obj)
		"""other code"""
        return dests
    def _schedule(self, context, spec_obj):
        """Returns a list of hosts that meet the required specs,
        ordered by their fitness.
        """
        elevated = context.elevated()

        hosts = self._get_all_host_states(elevated, spec_obj)

        selected_hosts = []
        num_instances = spec_obj.num_instances
        for num in range(num_instances):
            # Filter local hosts based on requirements ...
            hosts = self.host_manager.get_filtered_hosts(hosts,
                    spec_obj, index=num)
            if not hosts:
                # Can't get any more locally.
                break

            LOG.debug("Filtered %(hosts)s", {'hosts': hosts})

            weighed_hosts = self.host_manager.get_weighed_hosts(hosts,
                    spec_obj)

            LOG.debug("Weighed %(hosts)s", {'hosts': weighed_hosts})

            host_subset_size = CONF.filter_scheduler.host_subset_size
            if host_subset_size < len(weighed_hosts):
                weighed_hosts = weighed_hosts[0:host_subset_size]
            chosen_host = random.choice(weighed_hosts)

            LOG.debug("Selected host: %(host)s", {'host': chosen_host})
            selected_hosts.append(chosen_host)

            # Now consume the resources so the filter/weights
            # will change for the next instance.
            chosen_host.obj.consume_from_request(spec_obj)
            if spec_obj.instance_group is not None:
                spec_obj.instance_group.hosts.append(chosen_host.obj.host)
                # hosts has to be not part of the updates when saving
                spec_obj.instance_group.obj_reset_changes(['hosts'])
        return selected_hosts
```

#### *step4.  nova-conductor*

回到`scheduler/manager.py`的`build_instances`方法，nova-conductor等待nova-scheduler返回后，拿到调度的计算节点列表。因为可能同时启动多个虚拟机，因此循环调用了`compute_rpcapi`的`build_and_run_instance`方法。

```python
"""nova/scheduler/manager.py"""
@profiler.trace_cls("rpc")
class ComputeTaskManager(base.Base):
    """other code"""
    def build_instances(self, context, instances, image, filter_properties,
            admin_password, injected_files, requested_networks,
            security_groups, block_device_mapping=None, legacy_bdm=True):
        """other code"""
        for (instance, host) in six.moves.zip(instances, hosts):
            """other code"""

            self.compute_rpcapi.build_and_run_instance(context,
                    instance=instance, host=host['host'], image=image,
                    request_spec=request_spec,
                    filter_properties=local_filter_props,
                    admin_password=admin_password,
                    injected_files=injected_files,
                    requested_networks=requested_networks,
                    security_groups=security_groups,
                    block_device_mapping=bdms, node=host['nodename'],
                    limits=host['limits'])
            
"""nova/conpute/rpcapi.py"""
@profiler.trace_cls("rpc")
class ComputeAPI(object):
    def build_and_run_instance(self, ctxt, instance, host, image, request_spec,
            filter_properties, admin_password=None, injected_files=None,
            requested_networks=None, security_groups=None,
            block_device_mapping=None, node=None, limits=None):

        version = '4.0'
        cctxt = self.router.by_host(ctxt, host).prepare(
                server=host, version=version)
        cctxt.cast(ctxt, 'build_and_run_instance', instance=instance,
                image=image, request_spec=request_spec,
                filter_properties=filter_properties,
                admin_password=admin_password,
                injected_files=injected_files,
                requested_networks=requested_networks,
                security_groups=security_groups,
                block_device_mapping=block_device_mapping, node=node,
                limits=limits)
    """other code"""
```

对compute发送rpc请求：

```python
cctxt.cast(ctxt, 'build_and_run_instance',....)
```

由于是cast调用，因此发起的是异步RPC，因此nova-conductor任务结束，紧接着跳转到nova-compute。

#### *step5.  nova-compute*

到了nova-compute服务，入口为compute/manager.py，找到`build_and_run_instance`方法，该方法调用了driver的spawn方法，这里的driver就是各种hypervisor的实现，所有实现的driver都在virt目录下，入口为`driver.py`，比如libvirt driver实现对应为`virt/libvirt/driver.py`，找到spawn方法，该方法拉取镜像创建根磁盘、生成xml文件、define domain，启动domain等。最后虚拟机完成创建。nova-compute服务结束。

```python
"""nova/compute/manager.py"""
class ComputeManager(manager.Manager):
    """other code"""
    def _build_and_run_instance(self, context, instance, image, injected_files,
            admin_password, requested_networks, security_groups,
            block_device_mapping, node, limits, filter_properties):
        """other code"""
        self.driver.spawn(context, instance, image_meta,
                                          injected_files, admin_password,
                                          network_info=network_info,
                                          block_device_info=block_device_info)
        """other code"""

"""nova/virt/libvirt/driver.py"""
class LibvirtDriver(driver.ComputeDriver):
    """other code"""
    def spawn(self, context, instance, image_meta, injected_files,
              admin_password, network_info=None, block_device_info=None):
        disk_info = blockinfo.get_disk_info(CONF.libvirt.virt_type,
                                            instance,
                                            image_meta,
                                            block_device_info)
        injection_info = InjectionInfo(network_info=network_info,
                                       files=injected_files,
                                       admin_pass=admin_password)
        gen_confdrive = functools.partial(self._create_configdrive,
                                          context, instance,
                                          injection_info)
        self._create_image(context, instance, disk_info['mapping'],
                           injection_info=injection_info,
                           block_device_info=block_device_info)

        # Required by Quobyte CI
        self._ensure_console_log_for_instance(instance)

        xml = self._get_guest_xml(context, instance, network_info,
                                  disk_info, image_meta,
                                  block_device_info=block_device_info)
        self._create_domain_and_network(
            context, xml, instance, network_info, disk_info,
            block_device_info=block_device_info,
            post_xml_callback=gen_confdrive,
            destroy_disks_on_failure=True)
        LOG.debug("Instance is running", instance=instance)

        def _wait_for_boot():
            """Called at an interval until the VM is running."""
            state = self.get_info(instance).state

            if state == power_state.RUNNING:
                LOG.info(_LI("Instance spawned successfully."),
                         instance=instance)
                raise loopingcall.LoopingCallDone()

        timer = loopingcall.FixedIntervalLoopingCall(_wait_for_boot)
        timer.start(interval=0.5).wait()
```

### 创建虚拟机流程图

![创建虚拟机流程主要函数](/img/in-post/post-nova-src/nova-create-instance.png)