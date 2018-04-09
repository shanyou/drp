--- loadbalance servcie
-- @copyright Copyright 2016-2018 YunLu Inc. All rights reserved.
-- @license [GPL V3](https://opensource.org/licenses/gpl-3.0.html)
-- @module drp.model


local Object = require "drp.utils.classic"

local fmt = string.format
local new_tab
do
  local ok
  ok, new_tab = pcall(require, "table.new")
  if not ok then
    new_tab = function(narr, nrec) return {} end
  end
end
--- Service Class
local Service = Object:extend()

function Service:new(name, ip, port)
    self.name = name
    self.ip = ip
    self.port = port
end

return Service
