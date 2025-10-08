--- 模块功能：数据链路激活、SOCKET管理(创建、连接、数据收发、状态维护)
-- @module socket
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.9.25
require "link"
require "utils"
module(..., package.seeall)

local req = ril.request

local valid = {"0", "1", "2", "3", "4", "5", "6", "7"}
local validSsl = {"0", "1", "2", "3", "4", "5", "6", "7"}
local sockets = {}
local socketsSsl = {}
-- 单次发送数据最大值
local SENDSIZE = 1460
-- 缓冲区最大下标
local INDEX_MAX = 49

--用户自定义的DNS解析器
local dnsParser
local dnsParserToken = 0

--- SOCKET 是否有可用
-- @return 可用true,不可用false
socket.isReady = link.isReady


local function isSocketActive(ssl)
    for _, c in pairs(ssl and socketsSsl or sockets) do
        if c.connected then
            return true
        end
    end
end

local function socketStatusNtfy()
    sys.publish("SOCKET_ACTIVE", isSocketActive() or isSocketActive(true))
end

local function stopConnectTimer(tSocket, id)
    if id and tSocket[id] and tSocket[id].co and coroutine.status(tSocket[id].co) == "suspended"
        and (tSocket[id].wait == "+SSLCONNECT" or (tSocket[id].protocol == "UDP" and tSocket[id].wait == "+CIPSTART")) then
        sys.timerStop(coroutine.resume, tSocket[id].co, false, "TIMEOUT")
    end
end

local function errorInd(error)
    for k, v in pairs({sockets, socketsSsl}) do
        --if #v ~= 0 then
        for _, c in pairs(v) do -- IP状态出错时，通知所有已连接的socket
            --if c.connected or c.created then
            if error == 'CLOSED' and not c.ssl then c.connected = false socketStatusNtfy() end
            c.error = error
            if c.co and coroutine.status(c.co) == "suspended" then
                stopConnectTimer(v, c.id)
                coroutine.resume(c.co, false)
            end
        --end
        end
    --end
    end
end

sys.subscribe("IP_ERROR_IND", function()errorInd('IP_ERROR_IND') end)
sys.subscribe('IP_SHUT_IND', function()errorInd('CLOSED') end)

--订阅rsp返回的消息处理函数
local function onSocketURC(data, prefix)
    local tag, id, result = string.match(data, "([SSL]*)[&]*(%d), *([%u :%d]+)")
    tSocket = (tag == "SSL" and socketsSsl or sockets)
    if not id or not tSocket[id] then
        log.error('socket: urc on nil socket', data, id, tSocket[id], socketsSsl[id])
        return
    end
    
    if result == "CONNECT OK" or result:match("CONNECT ERROR") or result:match("CONNECT FAIL") then
        if tSocket[id].wait == "+CIPSTART" or tSocket[id].wait == "+SSLCONNECT" then
            stopConnectTimer(tSocket, id)
            coroutine.resume(tSocket[id].co, result == "CONNECT OK")
        else
            log.error("socket: error urc", tSocket[id].wait)
        end
        return
    end
    
    if tag == "SSL" and string.find(result, "ERROR:") == 1 then return end
    
    if string.find(result, "ERROR") or result == "CLOSED" then
        if result == 'CLOSED' and not tSocket[id].ssl then tSocket[id].connected = false socketStatusNtfy() end
        tSocket[id].error = result
        stopConnectTimer(tSocket, id)
        coroutine.resume(tSocket[id].co, false)
    end
end
-- 创建socket函数
local mt = {}
mt.__index = mt
local function socket(protocol, cert)
    local ssl = protocol:match("SSL")
    local id = table.remove(ssl and validSsl or valid)
    if not id then
        log.warn("socket.socket: too many sockets")
        return nil
    end
    
    local co = coroutine.running()
    if not co then
        log.warn("socket.socket: socket must be called in coroutine")
        return nil
    end
    -- 实例的属性参数表
    local o = {
        id = id,
        protocol = protocol,
        ssl = ssl,
        cert = cert,
        co = co,
        input = {},
        output = {},
        wait = "",
        connected = false,
        iSubscribe = false,
    }
    
    tSocket = (ssl and socketsSsl or sockets)
    tSocket[id] = o
    
    return setmetatable(o, mt)
end
--- 创建基于TCP的socket对象
-- @bool[opt=nil] ssl，是否为ssl连接，true表示是，其余表示否
-- @table[opt=nil] cert，ssl连接需要的证书配置，只有ssl参数为true时，才参数才有意义，cert格式如下：
-- {
--     caCert = "ca.crt", --CA证书文件(Base64编码 X.509格式)，如果存在此参数，则表示客户端会对服务器的证书进行校验；不存在则不校验
--     clientCert = "client.crt", --客户端证书文件(Base64编码 X.509格式)，服务器对客户端的证书进行校验时会用到此参数
--     clientKey = "client.key", --客户端私钥文件(Base64编码 X.509格式)
--     clientPassword = "123456", --客户端证书文件密码[可选]
-- }
-- @return client，创建成功返回socket客户端对象；创建失败返回nil
-- @usage
-- c = socket.tcp()
-- c = socket.tcp(true)
-- c = socket.tcp(true, {caCert="ca.crt"})
-- c = socket.tcp(true, {caCert="ca.crt", clientCert="client.crt", clientKey="client.key"})
-- c = socket.tcp(true, {caCert="ca.crt", clientCert="client.crt", clientKey="client.key", clientPassword="123456"})
function tcp(ssl, cert)
    return socket("TCP" .. (ssl == true and "SSL" or ""), (ssl == true) and cert or nil)
end
--- 创建基于UDP的socket对象
-- @return client，创建成功返回socket客户端对象；创建失败返回nil
-- @usage c = socket.udp()
function udp()
    return socket("UDP")
end

local sslInited
local tSslInputCert, sSslInputCert = {}, ""

local function sslInit()
    if not sslInited then
        sslInited = true
        req("AT+SSLINIT")
    end
    
    local i, item
    for i = 1, #tSslInputCert do
        item = table.remove(tSslInputCert, 1)
        req(item.cmd, item.arg)
    end
    tSslInputCert = {}
end

local function sslTerm()
    if sslInited then
        if not isSocketActive(true) then
            sSslInputCert, sslInited = ""
            req("AT+SSLTERM")
        end
    end
end

local function sslInputCert(t, f)
    if sSslInputCert:match(t .. f .. "&") then return end
    if not tSslInputCert then tSslInputCert = {} end
    local s = io.readFile((f:sub(1, 1) == "/") and f or ("/ldata/" .. f))
    if not s then log.error("inputcrt err open", path) return end
    table.insert(tSslInputCert, {cmd = "AT+SSLCERT=0,\"" .. t .. "\",\"" .. f .. "\",1," .. s:len(), arg = s or ""})
    sSslInputCert = sSslInputCert .. t .. f .. "&"
end

--- 连接服务器
-- @string address 服务器地址，支持ip和域名
-- @param port string或者number类型，服务器端口
-- @return bool result true - 成功，false - 失败
-- @usage  c = socket.tcp(); c:connect();
function mt:connect(address, port)
    assert(self.co == coroutine.running(), "socket:connect: coroutine mismatch")
    
    if not link.isReady() then
        log.info("socket.connect: ip not ready")
        return false
    end
    
    if cc and cc.anyCallExist() then
        log.info("socket:connect: call exist, cannot connect")
        return false
    end
    
    if self.ssl then
        local tConfigCert, i = {}
        if self.cert then
            if self.cert.caCert then
                sslInputCert("cacrt", self.cert.caCert)
                table.insert(tConfigCert, "AT+SSLCERT=1," .. self.id .. ",\"cacrt\",\"" .. self.cert.caCert .. "\"")
            end
            if self.cert.clientCert then
                sslInputCert("localcrt", self.cert.clientCert)
                table.insert(tConfigCert, "AT+SSLCERT=1," .. self.id .. ",\"localcrt\",\"" .. self.cert.clientCert .. "\",\"" .. (self.cert.clientPassword or "") .. "\"")
            end
            if self.cert.clientKey then
                sslInputCert("localprivatekey", self.cert.clientKey)
                table.insert(tConfigCert, "AT+SSLCERT=1," .. self.id .. ",\"localprivatekey\",\"" .. self.cert.clientKey .. "\"")
            end
        end
        
        sslInit()
        self.address = address
        req(string.format("AT+SSLCREATE=%d,\"%s\",%d", self.id, address .. ":" .. port, (self.cert and self.cert.caCert) and 0 or 1))
        self.created = true
        for i = 1, #tConfigCert do
            req(tConfigCert[i])
        end
        req("AT+SSLCONNECT=" .. self.id)
    else
        req(string.format("AT+CIPSTART=%d,\"%s\",\"%s\",%s", self.id, self.protocol, address, port))
    end
    if self.ssl or self.protocol == "UDP" then sys.timerStart(coroutine.resume, 120000, self.co, false, "TIMEOUT") end
    
    ril.regUrc((self.ssl and "SSL&" or "") .. self.id, onSocketURC)
    self.wait = self.ssl and "+SSLCONNECT" or "+CIPSTART"
    
    local r, s = coroutine.yield()
    
    if r == false and s == "DNS" then
        if self.ssl then self:sslDestroy()self.error = nil end
        
        require "http"
        --请求腾讯云免费HttpDns解析
        http.request("GET", "119.29.29.29/d?dn=" .. address, nil, nil, nil, 40000,
            function(result, statusCode, head, body)
                log.info("socket.httpDnsCb", result, statusCode, head, body)
                sys.publish("SOCKET_HTTPDNS_RESULT", result, statusCode, head, body)
            end)
        local _, result, statusCode, head, body = sys.waitUntil("SOCKET_HTTPDNS_RESULT")
        
        --DNS解析成功
        if result and statusCode == "200" and body and body:match("^[%d%.]+") then
            return self:connect(body:match("^([%d%.]+)"), port)
        --DNS解析失败
        else
            if dnsParser then
                dnsParserToken = dnsParserToken + 1
                dnsParser(address, dnsParserToken)
                local result, ip = sys.waitUntil("USER_DNS_PARSE_RESULT_" .. dnsParserToken, 40000)
                if result and ip and ip:match("^[%d%.]+") then
                    return self:connect(ip:match("^[%d%.]+"), port)
                end
            end
        end
    end
    
    if r == false then
        if self.ssl then self:sslDestroy() end
        return false
    end
    self.connected = true
    socketStatusNtfy()
    return true
end

--- 异步收发选择器
-- @number keepAlive,服务器和客户端最大通信间隔时间,也叫心跳包最大时间,单位秒
-- @string pingreq,心跳包的字符串
-- @return boole,false 失败，true 表示成功
function mt:asyncSelect(keepAlive, pingreq)
    assert(self.co == coroutine.running(), "socket:asyncSelect: coroutine mismatch")
    if self.error then
        log.warn('socket.client:asyncSelect', 'error', self.error)
        return false
    end
    
    self.wait = "SOCKET_SEND"
    while #self.output ~= 0 do
        local data = table.concat(self.output)
        self.output = {}
        for i = 1, string.len(data), SENDSIZE do
            -- 按最大MTU单元对data分包
            local stepData = string.sub(data, i, i + SENDSIZE - 1)
            --发送AT命令执行数据发送
            req(string.format("AT+" .. (self.ssl and "SSL" or "CIP") .. "SEND=%d,%d", self.id, string.len(stepData)), stepData)
            self.wait = self.ssl and "+SSLSEND" or "+CIPSEND"
            if not coroutine.yield() then
                if self.ssl then self:sslDestroy() end
                return false
            end
        end
    end
    self.wait = "SOCKET_WAIT"
    sys.publish("SOCKET_SEND", self.id)
    sys.timerStart(self.asyncSend, (keepAlive or 300) * 1000, self, pingreq or "\0")
    return coroutine.yield()
end
--- 异步发送数据
-- @string data 数据
-- @return result true - 成功，false - 失败
-- @usage  c = socket.tcp(); c:connect(); c:asyncSend("12345678");
function mt:asyncSend(data)
    if self.error then
        log.warn('socket.client:asyncSend', 'error', self.error)
        return false
    end
    table.insert(self.output, data or "")
    if self.wait == "SOCKET_WAIT" then coroutine.resume(self.co, true) end
    return true
end
--- 异步接收数据
-- @return nil, 表示没有收到数据
-- @return data 如果是UDP协议，返回新的数据包,如果是TCP,返回所有收到的数据,没有数据返回长度为0的空串
-- @usage c = socket.tcp(); c:connect()
-- @usage data = c:asyncRecv()
function mt:asyncRecv()
    if #self.input == 0 then return "" end
    if self.protocol == "UDP" then
        return table.remove(self.input)
    else
        local s = table.concat(self.input)
        self.input = {}
        return s
    end
end

--- 发送数据
-- @string data 数据
-- @return result true - 成功，false - 失败
-- @usage  c = socket.tcp(); c:connect(); c:send("12345678");
function mt:send(data)
    assert(self.co == coroutine.running(), "socket:send: coroutine mismatch")
    if self.error then
        log.warn('socket.client:send', 'error', self.error)
        return false
    end
    if self.id == nil then
        log.warn('socket.client:send', 'closed')
        return false
    end
    
    for i = 1, string.len(data), SENDSIZE do
        -- 按最大MTU单元对data分包
        local stepData = string.sub(data, i, i + SENDSIZE - 1)
        --发送AT命令执行数据发送
        req(string.format("AT+" .. (self.ssl and "SSL" or "CIP") .. "SEND=%d,%d", self.id, string.len(stepData)), stepData)
        self.wait = self.ssl and "+SSLSEND" or "+CIPSEND"
        if not coroutine.yield() then
            if self.ssl then self:sslDestroy() end
            return false
        end
    end
    return true
end
--- 接收数据
-- @number[opt=0] timeout 可选参数，接收超时时间，单位毫秒
-- @string[opt=nil] msg 可选参数，控制socket所在的线程退出recv阻塞状态
-- @return result 数据接收结果，true表示成功，false表示失败
-- @return data 如果成功的话，返回接收到的数据；超时时返回错误为"timeout"；msg控制退出时返回msg的字符串
-- @return param 如果是msg返回的false，则data的值是msg，param的值是msg的参数
-- @usage c = socket.tcp(); c:connect()
-- @usage result, data = c:recv()
-- @usage false,msg,param = c:recv(60000,"publish_msg")
function mt:recv(timeout, msg)
    assert(self.co == coroutine.running(), "socket:recv: coroutine mismatch")
    if self.error then
        log.warn('socket.client:recv', 'error', self.error)
        return false
    end
    if msg and not self.iSubscribe then
        self.iSubscribe = true
        sys.subscribe(msg, function(data)
            table.insert(self.output, data or "")
            if self.wait == "+RECEIVE" then coroutine.resume(self.co, false) end
        end)
    end
    if #self.output ~= 0 then sys.publish(msg) end
    if #self.input == 0 then
        self.wait = self.ssl and "+SSL RECEIVE" or "+RECEIVE"
        if timeout and timeout > 0 then
            local r, s = sys.wait(timeout)
            -- if not r then
            --     return false, "timeout"
            -- elseif r and r == msg then
            --     return false, r, s
            -- else
            --     if self.ssl and not r then self:sslDestroy() end
            --     return r, s
            -- end
            if r == nil then
                return false, "timeout"
            elseif r == false then
                local dat = table.concat(self.output)
                self.output = {}
                return false, msg, dat
            else
                if self.ssl and not r then self:sslDestroy() end
                return r, s
            end
        else
            return coroutine.yield()
        end
    end
    
    if self.protocol == "UDP" then
        return true, table.remove(self.input)
    else
        local s = table.concat(self.input)
        self.input = {}
        return true, s
    end
end

function mt:sslDestroy()
    assert(self.co == coroutine.running(), "socket:sslDestroy: coroutine mismatch")
    if self.ssl and (self.connected or self.created) then
        self.connected = false
        self.created = false
        req("AT+SSLDESTROY=" .. self.id)
        self.wait = "+SSLDESTROY"
        coroutine.yield()
        socketStatusNtfy()
    end
end
--- 销毁一个socket
-- @return nil
-- @usage  c = socket.tcp(); c:connect(); c:send("123"); c:close()
function mt:close()
    assert(self.co == coroutine.running(), "socket:close: coroutine mismatch")
    if self.connected or self.created then
        self.connected = false
        self.created = false
        req((self.ssl and "AT+SSLDESTROY=" or "AT+CIPCLOSE=") .. self.id)
        self.wait = self.ssl and "+SSLDESTROY" or "+CIPCLOSE"
        coroutine.yield()
        socketStatusNtfy()
    end
    if self.id ~= nil then
        ril.deRegUrc((self.ssl and "SSL&" or "") .. self.id, onSocketURC)
        table.insert((self.ssl and validSsl or valid), 1, self.id)
        if self.ssl then
            socketsSsl[self.id] = nil
        else
            sockets[self.id] = nil
        end
        self.id = nil
    end
end
local function onResponse(cmd, success, response, intermediate)
    local prefix = string.match(cmd, "AT(%+%u+)")
    local id = string.match(cmd, "AT%+%u+=(%d)")
    if response == '+PDP: DEACT' then sys.publish('PDP_DEACT_IND') end -- cipsend 如果正好pdp deact会返回+PDP: DEACT作为回应
    local tSocket = prefix:match("SSL") and socketsSsl or sockets
    if not tSocket[id] then
        log.warn('socket: response on nil socket', cmd, response)
        return
    end
    
    if cmd:match("^AT%+SSLCREATE") then
        tSocket[id].createResp = response
    end
    if tSocket[id].wait == prefix then
        if (prefix == "+CIPSTART" or prefix == "+SSLCONNECT") and success then
            -- CIPSTART,SSLCONNECT 返回OK只是表示被接受
            return
        end
        if (prefix == '+CIPSEND' or prefix == "+SSLSEND") and response:match("%d, *([%u%d :]+)") ~= 'SEND OK' then
            success = false
        end
        
        local reason, address
        if not success then
            if prefix == "+CIPSTART" then
                address = cmd:match("AT%+CIPSTART=%d,\"%a+\",\"(.+)\",%d+")
            elseif prefix == "+SSLCONNECT" and (tSocket[id].createResp or ""):match("SSL&%d+,CREATE ERROR: 4") then
                address = tSocket[id].address or ""
            end
            if address and not address:match("^[%d%.]+$") then
                reason = "DNS"
            end
        end
        
        if not reason and not success then tSocket[id].error = response end
        stopConnectTimer(tSocket, id)
        coroutine.resume(tSocket[id].co, success, reason)
    end
end

local function onSocketReceiveUrc(urc)
    local tag, id, len = string.match(urc, "([SSL]*) *RECEIVE,(%d), *(%d+)")
    tSocket = (tag == "SSL" and socketsSsl or sockets)
    len = tonumber(len)
    if len == 0 then return urc end
    local cache = {}
    local function filter(data)
        --剩余未收到的数据长度
        if string.len(data) >= len then -- at通道的内容比剩余未收到的数据多
            -- 截取网络发来的数据
            table.insert(cache, string.sub(data, 1, len))
            -- 剩下的数据扔给at进行后续处理
            data = string.sub(data, len + 1, -1)
            if not tSocket[id] then
                log.warn('socket: receive on nil socket', id)
            else
                sys.publish("SOCKET_RECV", id)
                local s = table.concat(cache)
                if tSocket[id].wait == "+RECEIVE" or tSocket[id].wait == "+SSL RECEIVE" then
                    coroutine.resume(tSocket[id].co, true, s)
                else -- 数据进缓冲区，缓冲区溢出采用覆盖模式
                    if #tSocket[id].input > INDEX_MAX then tSocket[id].input = {} end
                    table.insert(tSocket[id].input, s)
                end
            end
            return data
        else
            table.insert(cache, data)
            len = len - string.len(data)
            return "", filter
        end
    end
    return filter
end

ril.regRsp("+CIPCLOSE", onResponse)
ril.regRsp("+CIPSEND", onResponse)
ril.regRsp("+CIPSTART", onResponse)
ril.regRsp("+SSLDESTROY", onResponse)
ril.regRsp("+SSLCREATE", onResponse)
ril.regRsp("+SSLSEND", onResponse)
ril.regRsp("+SSLCONNECT", onResponse)
ril.regUrc("+RECEIVE", onSocketReceiveUrc)
ril.regUrc("+SSL RECEIVE", onSocketReceiveUrc)

function printStatus()
    log.info('socket.printStatus', 'valid id', table.concat(valid), table.concat(validSsl))
    
    for m, n in pairs({sockets, socketsSsl}) do
        for _, client in pairs(n) do
            for k, v in pairs(client) do
                log.info('socket.printStatus', 'client', client.id, k, v)
            end
        end
    end
end

--- 设置TCP层自动重传的参数
-- @number[opt=4] retryCnt，重传次数；取值范围0到12
-- @number[opt=16] retryMaxTimeout，限制每次重传允许的最大超时时间(单位秒)，取值范围1到16
-- @return nil
-- @usage
-- setTcpResendPara(3,8)
-- setTcpResendPara(4,16)
function setTcpResendPara(retryCnt, retryMaxTimeout)
    req("AT+TCPUSERPARAM=6," .. (retryCnt or 4) .. ",7200," .. (retryMaxTimeout or 16))
    ril.setDataTimeout(((retryCnt or 4) * (retryMaxTimeout or 16) + 60) * 1000)
end

--- 设置用户自定义的DNS解析器.
-- 通过域名连接服务器时，DNS解析的过程如下：
-- 1、使用core中提供的方式，连接运营商DNS服务器解析，如果解析成功，则结束；如果解析失败，走第2步
-- 2、使用脚本lib中提供的免费腾讯云HttpDns解析，如果解析成功，则结束；如果解析失败，走第3步
-- 3、如果存在用户自定义的DNS解析器，则使用此处用户自定义的DNS解析器去解析
-- @function[opt=nil] parserFnc，用户自定义的DNS解析器函数，函数的调用形式为：
--      parserFnc(domainName,token)，调用接口后会等待解析结果的消息通知或者40秒超时失败
--          domainName：string类型，表示域名，例如"www.baidu.com"
--          token：string类型，此次DNS解析请求的token，例如"1"
--      解析结束后，要publish一个消息来通知解析结果，消息参数中的ip地址最多返回一个，sys.publish("USER_DNS_PARSE_RESULT_"..token,ip)，例如：
--          sys.publish("USER_DNS_PARSE_RESULT_1","115.239.211.112")
--              表示解析成功，解析到1个IP地址115.239.211.112
--          sys.publish("USER_DNS_PARSE_RESULT_1")
--              表示解析失败
-- @return nil
-- @usage socket.setDnsParser(parserFnc)
function setDnsParser(parserFnc)
    dnsParser = parserFnc
end

setTcpResendPara(4, 16)
