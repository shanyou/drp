drp
===
Using resty as dynamic reverse proxy

resty 通过lua模块`ngx.balancer`中的`set_current_peer`功能，可以方便的在反向代理`balancer_by_lua_block`中自定义后端代理。结合Consul和Etcd这样的自动服务发现功能可以实现nginx负载均衡后端的动态修改。

根据这个原理网上有很类似的解决方案
> * [使用Nginx实现HTTP动态负载均衡—《亿级流量网站架构核心技术》](http://www.10tiao.com/html/164/201703/2652898370/1.html)
> * [使用balancer_by_lua_block做应用层负载均衡](http://blog.csdn.net/lubber__land/article/details/53287244)

最近又看了许多基于Resty的API网关方案
> * [Kong](https://getkong.org/)
> * [VeryNginx](https://github.com/alexazhou/VeryNginx)
> * [Orange](http://orange.sumory.com)

决定自己参考尝试做一个动态负载均衡的网关。主要功能列表如下:
> 1. 以服务为核心，支持多个动态的服务的反向代理
> 2. TCP/HTTP三七层两种工作模式
> 3. 结合第三方工具(Elasticsearch)跟踪代理访问情况
