程序代码实现
===

# 开发环境搭建
## 一、准备虚拟机
## 二、安装openresty
## 三、安装luarocks
下载编译
```bash
wget https://luarocks.org/releases/luarocks-2.4.4.tar.gz
tar xzvf luarocks-2.4.4.tar.gz
cd luarocks-2.4.4
./configure --prefix=/data/openresty/luajit/ \
    --with-lua=/data/openresty/luajit/ \
    --lua-suffix=jit \
    --with-lua-include=/data/openresty/luajit//include/luajit-2.1
make build && make install
```
编译完成后luarocks就在resty的luajit上运行了。然后安装单元测试工具`busted`
```bash
luarocks install busted
```
添加`busted`bin文件
```shell
#!/data/openresty/bin/resty
#
# description   :test launch script add custom search path
# author        :shanyou
# date          :2018/4/9
if ngx ~= nil then
  ngx.exit = function()end
end
local search_path='/data/openresty/nginx/lib'
package.path = package.path .. ";" .. search_path .. "/?.lua;;"
-- Busted command-line runner
require 'busted.runner'({ standalone = false })
```
