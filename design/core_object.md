核心对象设计
===
# Service
代表后端服务，有服务名称作为唯一标识，服务器IP地址和端口号列表作为服务内容。通过Consul或者Etcd等动态的修改列表内容。在实际负载代理时根据一定算法提供代理服务。

# ProxyPolicy
代理算法，类似Hash RoundRobin等算法来处理后端服务列表提供一个代理服务。

# ServiceProvider
服务发现提供者，如Consul、Etcd、Zookeeper等。
