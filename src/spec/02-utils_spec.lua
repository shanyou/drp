describe("utils module test", function()
    it('uuid4 test', function()
        local uuid4 = require "drp.utils.uuid4"
        local u = uuid4.getUUID()
        ngx.say(u)
        assert.is_not_nil(u)
    end)
end)
