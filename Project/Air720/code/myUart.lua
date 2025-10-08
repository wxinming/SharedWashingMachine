module(...,package.seeall)
require"myInit"
require"utils"
require"log"
require"algorithm"
require"sys"
require"log"

if _G.FRAMEWORK == "AIR202" then
    UART_ID,MCU_ID = 1,2
elseif _G.FRAMEWORK == "AIR720" then
    UART_ID,MCU_ID = 2,1
end

--串口设备是否工作(true不在工作,false正在工作)
--串口设备是否故障(true故障,false正常)
uartWorking,uartBreakdown = true,false

--串口设备故障次数,串口数据拼接临时变量,单片机数据拼接临时变量
local errCount,uartTemp,mcuTemp = 0,"",""

--发送关机指令
--@param  style:设备类型
--@return 无
function sendShutdown(style)
    if not style then return end
    local order = ""
    if style:sub(1,4) == "uart" then
        order = "AA20DBFB0000000000020200FFFFFFFFFFFFFFFFFFFFFF00FFFF00FFFFFFFFFF18"
    elseif style:sub(1,8) == "pul_uart" then
        order = "AA1EDAC40000000000020200FFFFFFFFFF00FFFFFFFFFFFFFFFFFFFFFFFF51"
    elseif style == "hili_uart" then
        order = "FFFF0A000000000000014D035B"
    end
    
    if algorithm.uartWriteStr(UART_ID,order) then
        sys.timerStart(algorithm.uartWriteStr,1000,UART_ID,order)
    end
end

--启动任务处理串口数据
--@param  id:串口号
--@param  parseFnc:解析函数
--@param  delay:延迟时间
--@return 无
local function taskReadUart(id,parseFnc,delay)
    local cacheData = ""
    while true do
        local s = uart.read(id,"*l")
        if s == "" then
            uart.on(id,"receive",function() sys.publish("UART_RECEIVE") end)
            if not sys.waitUntil("UART_RECEIVE",delay) then
                if cacheData:len() > 0 then
                    parseFnc(cacheData:toHex())
                    cacheData = ""
                end
            end
            uart.on(id,"receive")
        else
            cacheData = cacheData..s     
        end
    end
end

--配置串口
--@note   如果要使用以任务方式处理串口数据,delay不要为空
--@param  id:串口号
--@param  callback:回调函数
--@param  delay:延迟时间
--@return 无
function setupUart(id,callback,delay)
    uart.setup(id,9600,8,uart.PAR_NONE,uart.STOP_1)
    if type(delay) == "number" then
        sys.taskInit(taskReadUart,id,callback,delay)
    else
        uart.on(id,"receive",callback)
    end
end

--发送开始工作数据
--@param  value:投币金额
--@return 无
function sendStartWork(value)
    if value == 0 then
        myMqtt.publishMessage({id=misc.getImei(),mode="auto",working="false"})
    else
        myMqtt.publishMessage({id=misc.getImei(),mode="auto",working="false",money=value})
    end
end

--发送继续工作数据
--@param  无
--@return 无
function sendContinue()
    myMqtt.publishMessage({id=misc.getImei(),mode="auto",working="continue"})
end

--发送工作完成数据
--@param  无
--@return 无
function sendCompleteWork()
    myMqtt.publishMessage({id=misc.getImei(),mode="auto",working="true"})
end

--发送故障数据
--@param  value:故障代码
--@return 无
local function sendBreakdown(value)
    myMqtt.publishMessage({id=misc.getImei(),error=value})
end

--解析美的滚筒设备串口数据
--@param  无
--@return 无
function parseMideaUartC()
    local data = ""
    while true do
        data = uart.read(UART_ID,"*l")
        if not data or data:len() == 0 then 
            break 
        end
        uartTemp = uartTemp..data:toHex()
        log.info("myUart.parseMideaUartC",uartTemp)
        if uartTemp:sub(1,2) ~= "AA" then
            uartTemp = ""
        else
            if uartTemp:sub(1,6) == "AA29DB" or uartTemp:sub(1,6) == "AA11DB" then
                if uartTemp:len() == 84 and uartTemp:sub(-2,-1) == algorithm.getMideaCc(uartTemp) then
                    if uartTemp:sub(23,26) == "0102" then
                        if uartWorking then
                            if uartBreakdown then
                                algorithm.stopRunningTimer(sendShutdown,myInit.style)
                                sendContinue()
                            else
                                sendStartWork(myGpio.coinMoney)
                                if myInit.isCoin then
                                    myGpio.setCoinSecurity()
                                    myGpio.coinMoney = 0
                                    myGpio.pullupVoltage(0)
                                end
                            end
                            uartWorking = false
                            uartBreakdown = false
                            errCount = 0
                        end
                    elseif uartTemp:sub(21,26) == "040000" then
                        if not uartWorking or uartBreakdown then
                            if uartBreakdown then
                                algorithm.stopRunningTimer(sendShutdown,myInit.style)
                            end
                            if myInit.isCoin then
                                myGpio.setCoinSecurity()
                                myGpio.pullupVoltage(1)
                            end
                            uartWorking = true
                            uartBreakdown = false
                            sendCompleteWork()
                            algorithm.uartWtime = 0
                            errCount = 0
                        end
                    end

                    if algorithm.uartWtime ~= 0 then
                        if uartTemp:sub(25,26) == "02" and uartTemp:sub(53,54) == "04" then
                            algorithm.addFluid(algorithm.uartWtime)
                            algorithm.uartWtime = 0
                        end
                    end
                    uartTemp = ""
                    break
                elseif uartTemp:len() == 36 and uartTemp:sub(-2,-1) == algorithm.getMideaCc(uartTemp) then
                    errCount = errCount + 1
                    if errCount == 2 then
                        uartBreakdown = true
                        uartWorking = true
                        sendBreakdown(uartTemp)
                        sys.timerStart(sendShutdown,60000 * 120,myInit.style)
                    elseif errCount == 1 then
                        sys.timerStart(algorithm.uartWriteStr,5000,UART_ID,"AA20DBFB00000000000202FF01FFFFFFFFFFFFFFFFFFFF00FFFF00FFFFFFFFFF17")
                    end
                    uartTemp = ""
                    break
                end
            else
                if uartTemp:len() >= 6 then
                    uartTemp = ""
                end
            end
        end

        if uartTemp:len() > 84 then
            log.info("myUart.parseMideaUartc","data over flow",uartTemp)
            uartTemp = ""
        end
    end
end

--解析美的波轮滚筒设备串口数据
--@param  无
--@return 无
function parseMideaPulsatorUartC()
    local data = ""
    while true do
        data = uart.read(UART_ID,"*l")
        if not data or data:len() == 0 then 
            break 
        end
        uartTemp = uartTemp..data:toHex()
        log.info("myUart.parseMideaPulsatorUartC",uartTemp)
        if uartTemp:sub(1,2) ~= "AA" then
            uartTemp = ""
        else
            if uartTemp:sub(1,4) == "AA23" or uartTemp:sub(1,4) == "AA11" then
                if uartTemp:len() == 72 and uartTemp:sub(-2,-1) == algorithm.getMideaCc(uartTemp) then
                    if uartTemp:sub(21,26) == "040101" then
                        if uartWorking then
                            sendStartWork(myGpio.coinMoney)
                            if myInit.isCoin then
                                myGpio.setCoinSecurity()
                                myGpio.coinMoney = 0
                                myGpio.pullupVoltage(0)
                            end
                            uartWorking = false
                            uartBreakdown = false
                            errCount = 0
                        end
                    elseif uartTemp:sub(21,26) == "040000" then
                        if not uartWorking then
                            if myInit.isCoin then
                                myGpio.setCoinSecurity()
                                myGpio.pullupVoltage(1)
                            end
                            uartWorking = true
                            uartBreakdown = false
                            sendCompleteWork()
                            algorithm.uartWtime = 0
                            errCount = 0
                        end
                    end

                    if algorithm.uartWtime ~= 0 then
                        if uartTemp:sub(25,26) == "02" and uartTemp:sub(53,54) == "04" then
                            algorithm.addFluid(algorithm.uartWtime)
                            algorithm.uartWtime = 0
                        end
                    end
                    uartTemp = ""
                    break
                elseif uartTemp:len() == 36 and uartTemp:sub(-2,-1) == algorithm.getMideaCc(uartTemp) then
                    errCount = errCount + 1
                    if errCount == 1 then
                        sendBreakdown(uartTemp)
                        uartBreakdown = true
                    end
                    uartTemp = ""
                    break
                end
            else
                if uartTemp:len() >= 4 then
                    uartTemp = ""
                end
            end
        end

        if uartTemp:len() > 72 then
            log.info("myUart.parseMideaUartc","data over flow",uartTemp)
            uartTemp = ""
        end
    end
end

--发送海狸查询数据
--@param  reserved:定时的标识
--@return 无
local function hiliSendData(reserved)
	algorithm.uartWriteStr(UART_ID,"FFFF0A000000000000014D0159")
end

--海狸查询定时器
--@param  time:延时多少ms
--@return 无
function hiliQueryTimer(time)
    if algorithm.stopRunningTimer(hiliSendData,"hiliSendData") then
        log.info("myUart.hiliQueryTimer","stop running timer success")
    end
    sys.timerLoopStart(hiliSendData,time,"hiliSendData")
end

--解析海狸串口数据
--@param  无
--@return 无
function parseHiliUart()
    local data = ""
    while true do
        data = uart.read(UART_ID,"*l")
        if not data or data:len() == 0 then 
            break 
        end
        uartTemp = uartTemp..data:toHex()
        log.info("myUart.parseHiliUart",uartTemp)
        if uartTemp:sub(1,6) == "FFFF2C" then
            if uartTemp:len() == 94 and uartTemp:sub(-2,-1) == algorithm.getHaierCc(uartTemp) then
                if uartTemp:sub(25,26) == "0D" or uartTemp:sub(35,36) == "F1" then
                    if uartWorking then
                        sendStartWork(0)
                        uartWorking = false
                        uartBreakdown = false
                        hiliQueryTimer(2000)
                        errCount = 0
                    end
                elseif uartTemp:sub(33,36) == "0021" or uartTemp:sub(33,34) == "0E" then
                    if not uartWorking then
                        sendCompleteWork()
                        uartWorking = true
                        uartBreakdown = false
                        hiliQueryTimer(15000)
                        errCount = 0
                    end
                elseif uartTemp:sub(35,36) == "51" or uartTemp:sub(35,36) == "71" or uartTemp:sub(35,36) == "41" then
                    errCount = errCount + 1
                    if errCount == 1 then
                        sendBreakdown(uartTemp)
                        uartBreakdown = true
                    end
                end
                uartTemp = ""
                break
            end
        else
            if uartTemp:len() >= 6 then
                uartTemp = ""
            end
        end
        if uartTemp:len() > 94 then
            log.info("myUart.parseHiliUart","data over flow",uartTemp)
            uartTemp = ""
        end
    end
end

--解析单片机脉冲3数据
--@param hexData:要解析的字符串
--@return 无
local function parseMcuGpio3Data(hexData)
    if hexData:sub(1,12) == "BA0301010A0A" or hexData:sub(1,12) == "BA0300010A0A" then
        log.info("myUart.parseMcuGpio3Data","touch complete working")
        if hexData:sub(13,14) == "00" then
            log.info("myUart.parseMcuGpio3Data","singlechip working complete")
            sendCompleteWork()
            myGpio.gpioWoking = true
        elseif hexData:sub(13,14) == "01" then
            log.info("myUart.parseMcuGpio3Data","add laundry detergent complete")
        end
    end
end

--新单片机增加查询指令
--脉冲1.6801000000000069
--脉冲2.680200000000006A
--脉冲3.680300000000006B

--以任务方式处理单片机串口数据
--@note   该函数尽量不要使用,如果任务过多会导致无法解析数据
--@param  hexData:要解析的字符串
--@return 无
function taskParseMcuUart(hexData)
    log.info("myUart.parseMCU","hexData",hexData)
    --脉冲1返回:BB0102010A0A00D3
    if hexData == "BB0102010A0A00D3" then
        log.info("myUart.parseMcu","receive gpio1 return value")
        if myGpio.isCoinOk then
            if algorithm.gpioDelayTime > 0 then
                sys.timerStart(algorithm.uartWriteStr,algorithm.gpioDelayTime,MCU_ID,"AA0202010A0A00C3")
            else
                algorithm.uartWriteStr(MCU_ID,"AA0202010A0A00C3")
            end
        end
    --脉冲2返回:BB0202010A0A00D4
    elseif hexData == "BB0202010A0A00D4" then
        log.info("myUart.parseMcu","simulation read button success")
        myGpio.isCoinOk = true
        algorithm.gpioDelayTime = 0
    elseif hexData:sub(1,12) == "AA0300000000" then
        log.info("myUart.parseMcu","touch start working")
        if hexData:sub(13,14) == "00" then
            sendStartWork(0)
            myGpio.gpioWoking = false
        elseif hexData:sub(13,14) == "01" then
            log.info("myUart.parseMcu","start add laundry detergent")
        end
    --兼容老单片机回复数据,不可删除
    elseif hexData:len() == 32 and hexData:sub(1,16) == "BB030100000001C0" then
        parseMcuGpio3Data(hexData:sub(17,32))
    elseif hexData == "BA0300010A0A00D3" then
        parseMcuGpio3Data(hexData)
    end
end

--解析单片机串口数据
--@note   此函数不要随意更改,兼容Air202和Air720
--@param  无
--@return 无
function parseMcuUart()
    local data = ""
    while true do
        data = uart.read(MCU_ID,"*l")
        if not data or data:len() == 0 then 
            break
        end
        mcuTemp = mcuTemp..data:toHex()
        log.info("myUart.parseMcuUart",mcuTemp)
        if mcuTemp:sub(1,4) == "BB01" or mcuTemp:sub(1,4) == "BB02" then
            if mcuTemp:len() == 16 and mcuTemp:sub(-2,-1) == algorithm.getMcuCc(mcuTemp) then
                if mcuTemp == "BB0102010A0A00D3" then--发送完成脉冲1回复的数据
                    log.info("myUart.parseMcuUart","receive gpio1 return value")
                    if myGpio.isCoinOk then
                        if algorithm.gpioDelayTime > 0 then
                            sys.timerStart(algorithm.uartWriteStr,algorithm.gpioDelayTime,MCU_ID,"AA0202010A0A00C3")
                        else
                            algorithm.uartWriteStr(MCU_ID,"AA0202010A0A00C3")
                        end
                    end
                elseif mcuTemp == "BB0202010A0A00D4" then--发送完成脉冲2回复的数据
                    log.info("myUart.parseMcuUart","simulation read button success")
                    myGpio.isCoinOk = true
                    algorithm.gpioDelayTime = 0
                end
                mcuTemp = ""
                break
            end
        elseif mcuTemp:sub(1,4) == "BB03" then--每秒回复的数据,兼容老单片机,不可删除
            if mcuTemp:len() == 16 and mcuTemp:sub(-2,-1) == algorithm.getMcuCc(mcuTemp) then
                log.info("myUart.parseMcuUart","time remaining",algorithm.getCountDown(algorithm.hexToSec(mcuTemp)))
                mcuTemp = ""
                break
            end
        elseif mcuTemp:sub(1,4) == "AA03" then
            if mcuTemp:len() == 16 and mcuTemp:sub(-2,-1) == algorithm.getMcuCc(mcuTemp) then
                log.info("myUart.parseMcuUart","touch start working")
                if mcuTemp:sub(13,14) == "00" then
                    sendStartWork(0)
                    myGpio.gpioWoking = false
                elseif mcuTemp:sub(13,14) == "01" then
                    log.info("myUart.parseMcuUart","start add laundry detergent")
                end
                mcuTemp = ""
                break
            end
        elseif mcuTemp:sub(1,4) == "BA03" then
            if mcuTemp:len() == 16 and mcuTemp:sub(-2,-1) == algorithm.getMcuCc(mcuTemp) then
                parseMcuGpio3Data(mcuTemp)
                mcuTemp = ""
                break
            end
        else
            if mcuTemp:len() >= 4 then
                mcuTemp = ""
            end
        end

        if mcuTemp:len() > 16 then
            log.info("myUart.parseMcuUart","data over flow",mcuTemp)
            mcuTemp = ""
        end
    end
end
