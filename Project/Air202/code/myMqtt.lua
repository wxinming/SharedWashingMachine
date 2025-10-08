module(...,package.seeall)
require"aLiYun"
require"aLiYunOta"
require"myInit"
require"myLbs"
require"algorithm"
require"net"
require"log"

--阿里云IOT产品秘钥,发送模块所有数据开关
local PRODUCT_KEY,getLocation = "CKeWl7aRY0y",true

--publishMessage的回调函数
--@param  result:发送数据的结果,成功true 失败false
--@return 无
local function publishMessageCbFnc(result)
    if result then
        log.info("myMqtt.publishMessageCbFnc","SEND MQTT MESSAGE SUCCESS")
    else
        log.info("myMqtt.publishMessageCbFnc","SEND MQTT MESSAGE FAILED");
    end
end

--发布MQTT消息
--@param  msg:table数据类型
--@return 无
function publishMessage(msg)
    local jsonData = json.encode(msg)
    aLiYun.publish("/"..PRODUCT_KEY.."/"..misc.getImei().."/post",jsonData,0,publishMessageCbFnc,nil)
end

--解析MQTT消息并做处理
--@param  paylod:收到的消息
--@return 无
local function parseMessage(qos,payload)
    if qos == 0 then
        if algorithm.recvServerHex(payload) then
            log.info("myMqtt.parseMessage","SEND UART DATA SUCCESS")
        elseif payload == "reboot" then
            rtos.restart()
        elseif payload == "get_uart_status" then
            publishMessage({id=misc.getImei(),mode="query",breakdown=tostring(myUart.uartBreakdown),
            working=tostring(myUart.uartWorking),signal=net.getRssi(),netMode=algorithm.getNetMode()})
        elseif payload == "get_gpio_status" then
            publishMessage({id=misc.getImei(),mode="query",working=tostring(myGpio.gpioWorking),
            signal=net.getRssi(),netMode=algorithm.getNetMode()})
        elseif algorithm.setConfigFile(payload) then
            rtos.restart()
        elseif payload == "get_data" then
            myLbs.reqLbsLoc()
        elseif payload == "get_net_mode" then
            publishMessage({id=misc.getImei(),mode="query",netMode=algorithm.getNetMode()})
        elseif payload:sub(1,3) == "led" then
            myGpio.displayLed(payload:sub(4,#payload))
        else
            publishMessage({id=misc.getImei(),msg="uartmsg"})
        end
    elseif qos == 1 then
        if algorithm.recvServerGpio(payload) then
            log.info("myMqtt.parseMessage","SEND GPIO DATA SUCCESS")
        else
            publishMessage({id=misc.getImei(),msg="gpiomsg"})
        end
    end
end

--数据接收的处理函数
--@string topic，UTF8编码的消息主题
--@number qos，消息质量等级
--@string payload，原始编码的消息负载
local function rcvCbFnc(topic,qos,payload)
    log.info("myMqtt.rcvCbFnc",topic,qos,payload)
    parseMessage(qos,payload)
end

--连接结果的处理函数
--@bool result，连接结果，true表示连接成功，false或者nil表示连接失败
local function connectCbFnc(result)
    log.info("myMqtt.connectCbFnc",result)
    if result then
        --订阅主题，不需要考虑订阅结果，如果订阅失败，aLiYun库中会自动重连
        aLiYun.subscribe({["/"..PRODUCT_KEY.."/"..misc.getImei().."/get"]=0,["/"..PRODUCT_KEY.."/"..misc.getImei().."/get"]=1})
        --注册数据接收的处理函数
        aLiYun.on("receive",rcvCbFnc)
        if getLocation then 
            if rtos.poweron_reason() == 0 then
                myLbs.reqLbsLoc()
            else
                publishMessage({
                    id=misc.getImei(),
                    signal=net.getRssi(),
                    version=_G.PROJECT.."_"..rtos.get_version():sub(9,10).."_".._G.VERSION,
                    reason=rtos.poweron_reason(),
                    style=myInit.style,
                    netMode=algorithm.getNetMode()
                })
            end
            getLocation = false
        end
    end
end

--misc.setSn的回调函数
--@param  result:true成功,false失败
--@return 无
local function setSnCbFnc(result)
    if result then
        rtos.restart()
    else
        log.info("myMqtt.setSnCbFnc","setSn failed")
    end
end

--获取MQTT产品秘钥的回调函数
--@param  result:true成功,false失败
--@param  prompt:状态码
--@param  head:http协议头
--@param  body:http body
--@return 无
local function getProductSecretCbFnc(result,prompt,head,body)
    log.info("myMqtt.getProductSecretCbFnc","result",result,"prompt",prompt)
    if result and prompt == "200" then
        local jsonData,result,err = json.decode(body)
        if result then
            log.info("myMqtt.getProductSecretCbFnc","jsonData[sn]",jsonData["sn"])
            log.info("myMqtt.getProductSecretCbFnc","jsonData[style]",jsonData["style"])
            log.info("myMqtt.getProductSecretCbFnc","jsonData[append]",jsonData["append"])
            if jsonData["sn"] ~= "0" and jsonData["sn"] ~= misc.getSn() then
                local append,style = jsonData["append"],jsonData["style"]
                if append then 
                    style = style.."c" 
                end

                if algorithm.setConfigStyle(style) then
                    misc.setSn(jsonData["sn"],setSnCbFnc)
                else
                    log.info("myMqtt.getProductSecretCbFnc","setConfigStyle failed",style)
                end
            else
                log.info("myMqtt.getProductSecretCbFnc","invalid sn or equal sn")
            end
        else
            log.info("myMqtt.getProductSecretCbFnc","json.decode",err)
        end
    else
        log.info("myMqtt.getProductSecretCbFnc","no 200 ok")
    end
end

-- 认证结果的处理函数
-- @bool result，认证结果，true表示认证成功，false或者nil表示认证失败
local function authCbFnc(result)
    log.info("myMqtt.authCbFnc",result)
    if not result then
        http.request("GET","http://f.okook.com/index.php/api/getdata/getdevicenew?id="..misc.getImei().."&ac=getsecret",
        nil,nil,nil,20000,getProductSecretCbFnc)
    end
end

--初始化MQTT
--@param  无
--@return 无
function mqttInit()
    aLiYun.setMqtt(nil,nil,120)
    aLiYun.setup(PRODUCT_KEY,nil,misc.getImei,misc.getSn)
    aLiYun.on("auth",authCbFnc)
    aLiYun.on("connect",connectCbFnc)
end
