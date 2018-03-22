实验动态负载均衡
===

通过openresty中的loadbalancer Lua模块结合`Consul`对后端服务器进行动态的负载管理。

# 实验准备
## 服务器
> 1. Consul 172.17.50.199
由一个虚拟机安装三个docker服务来模拟。其中docker中的docker0 ip是 172.18.0.2
> 2. RealServer1(172.17.50.203), RealServer2(172.17.50.204) 分别安装了Redis实例
> 3. openresty 主要负载均衡的网关，相关代码在`resty`目录中

## consul
通过docker container来配置Consul
```bash
# get official image of consul
docker pull consul
# run
# datacenter是"yunlu_office"
docker run \
    --name dev-consul-1 \
    -d \
    -e CONSUL_CLIENT_INTERFACE=eth0 \
    -e CONSUL_BIND_INTERFACE=eth0 \
    -p 8600:8600/udp \
    -p 8600:8600/tcp \
    -p 8500:8500 \
    -e CONSUL_LOCAL_CONFIG='{
    "datacenter":"yunlu_office",
    "server":true,
    "enable_debug":true
    }' \
    consul agent -server -bootstrap-expect=1
# another consul
docker run --name dev-consul-2 -d \
    -e CONSUL_CLIENT_INTERFACE=eth0 \
    -e CONSUL_BIND_INTERFACE=eth0 \
    -e CONSUL_LOCAL_CONFIG='{
     "datacenter":"yunlu_office",
     "server":true,
     "enable_debug":true
     }' \
     consul agent -dev -join=172.18.0.2

docker run --name dev-consul-3 -d \
    -e CONSUL_CLIENT_INTERFACE=eth0 \
    -e CONSUL_BIND_INTERFACE=eth0 \
    -e CONSUL_LOCAL_CONFIG='{
    "datacenter":"yunlu_office",
    "server":true,
    "enable_debug":true
    }' \
    consul agent -dev -join=172.18.0.2
```

## RealServer
RealServer安装Redis实例
```bash
# start rs1 with docker
docker run --name rs1 -p 6379:6379 -d redis
# start rs2 with docker
docker run --name rs2 -p 6379:6379 -d redis
```

## 在Consul中注册服务
定义payload_rs1.json

```json
{
  "ID": "rs1",
  "Name": "redis",
  "Tags": [
    "primary",
    "v1"
  ],
  "Address": "172.17.50.203",
  "Port": 6379,
  "EnableTagOverride": false,
  "check": {
    "id": "redis",
    "name": "redis port 6379",
    "tcp": "172.17.50.203:6379",
    "interval": "10s",
    "timeout": "1s"
  }
}
```
定义payload_rs2.json
```json
{
  "ID": "rs2",
  "Name": "redis",
  "Tags": [
    "slave",
    "v1"
  ],
  "Address": "172.17.50.204",
  "Port": 6379,
  "EnableTagOverride": false,
  "check": {
    "id": "redis",
    "name": "redis port 6379",
    "tcp": "172.17.50.204:6379",
    "interval": "10s",
    "timeout": "1s"
  }
}
```
注册服务
```bash
curl \
   --request PUT \
   --data @payload_rs1.json \
   http://172.17.50.199:8500/v1/agent/service/register

curl \
  --request PUT \
  --data @payload_rs2.json \
  http://172.17.50.199:8500/v1/agent/service/register
```

DNS验证方法
```bash
dig @172.17.50.199 -p 8600 redis.service.yunlu_office.consul. SRV
```
返回结果如下：
```bash
; <<>> DiG 9.9.4-RedHat-9.9.4-51.el7_4.2 <<>> @localhost -p 8600 redis.service.yunlu_office.consul. SRV
; (2 servers found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 54485
;; flags: qr aa rd; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 3
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;redis.service.yunlu_office.consul. IN  SRV

;; ANSWER SECTION:
redis.service.yunlu_office.consul. 0 IN SRV     1 1 6379 ac1132cc.addr.yunlu_office.consul.
redis.service.yunlu_office.consul. 0 IN SRV     1 1 6379 ac1132cb.addr.yunlu_office.consul.

;; ADDITIONAL SECTION:
ac1132cc.addr.yunlu_office.consul. 0 IN A       172.17.50.204
ac1132cb.addr.yunlu_office.consul. 0 IN A       172.17.50.203

;; Query time: 2 msec
;; SERVER: ::1#8600(::1)
;; WHEN: Thu Mar 22 14:02:47 CST 2018
;; MSG SIZE  rcvd: 200
```
## 部署openresty
将resty目录下的配置文件放入openresty执行环境中覆盖默认的conf。具体原理如下：

resty通过`init_worker_by_lua_block` 初始化一个timer去跟consul解析相关DNS SRV记录。解析后存储全局共享的字典中。
```lua
local upstreams = {}
for i, ans in ipairs(answers) do
    table.insert(upstreams, ans)
end
ngx.shared.consul_list:set("redis", cjson.encode(upstreams))
```
这里为了防止多个进程读写共享内存区，没有通过锁机制，而是只让worker0进程去工作。
当用户调用proxy的时候触发`balancer_by_lua_block`
```lua
local balancer = require "ngx.balancer"
local cjson = require("cjson")
local up_str = ngx.shared.consul_list:get("redis")
ngx.log(ngx.ERR, "current ans is "..up_str)
local upstreams = cjson.decode(ngx.shared.consul_list:get("redis"))
local host = nil
local port = 6379

for i, ans in ipairs(upstreams) do
    if ans.address ~= nil then
        host = ans.address
        break
    end
end

local ok, err = balancer.set_current_peer(host, port)
if not ok then
    ngx.log(ngx.ERR, "failed to set the current peer: ", err)
    return ngx.exit(ngx.ERR)
end
```
## 测试
通过停止RealServer1, RealServer2的docker服务。可以调用proxy来判断程序是否正常工作。

## 遗留问题
> 1. SRV记录需要进一步解析名字和端口号
```json
[
{
"class":1,
"name":"redis.service.yunlu_office.consul",
"target":"ac1132cc.addr.yunlu_office.consul",
"priority":1,
"port":6379,
"weight":1,
"ttl":0,
"section":1,
"type":33
},
{
"class":1,
"name":"redis.service.yunlu_office.consul",
"target":"ac1132cb.addr.yunlu_office.consul",
"priority":1,
"port":6379,
"weight":1,
"ttl":0,
"section":1,
"type":33
},
{
"address":"172.17.50.204",
"class":1,
"ttl":0,
"name":"ac1132cc.addr.yunlu_office.consul",
"section":3,
"type":1
},
{
"address":"172.17.50.203",
"class":1,
"ttl":0,
"name":"ac1132cb.addr.yunlu_office.consul",
"section":3,
"type":1
}
]
```

# 参考
[使用Nginx实现HTTP动态负载均衡—《亿级流量网站架构核心技术》](http://www.10tiao.com/html/164/201703/2652898370/1.html)

[OpenResty 最佳实践 缓存](http://wiki.jikexueyuan.com/project/openresty/ngx_lua/cache.html)
[如何只启动一个 timer 工作？](https://moonbingbing.gitbooks.io/openresty-best-practices/ngx_lua/how_one_instance_time.html)
