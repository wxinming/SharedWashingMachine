module(...,package.seeall)
require"misc"
require"sys"
require"myMqtt"
require"myUart"
require"myGpio"
require"algorithm"
require"pm"

--配置模块永不休眠
pm.wake("run")

--配置文件数据,设备风格,是否投币
configData,style,isCoin= "","",false

--初始化模块所需功能
--@param  无
--@return 无
local function initConfig()
    myUart.setupUart(myUart.MCU_ID,myUart.parseMcuUart)
    if rtos.poweron_reason() == 0 then
        --algorithm.uartWriteStr(myUart.MCU_ID,"AA000000000000AA")
    end
    
    configData = algorithm.readFile("/config.txt")
    style = algorithm.getStyle(configData)
    
    local callback
    if style:sub(1,4) == "uart" then
        callback = myUart.parseMideaUartC
    elseif style:sub(1,8) == "pul_uart" then
        callback = myUart.parseMideaPulsatorUartC
    elseif style == "hili_uart" then
        callback = myUart.parseHiliUart
        myUart.hiliQueryTimer(15000)
    else
        style,isCoin= "gpio",true
    end

    if callback then
        isCoin = style:sub(-1,-1) == "c"
        myUart.setupUart(myUart.UART_ID,callback)
        if rtos.poweron_reason() == 0 then
            myUart.sendShutdown(style)
        end
    end

    if isCoin then myGpio.initGpioInterface() end
end

algorithm.setConfigStyle("gpio")

initConfig()

--5s后启动阿里云IOT,延时必须的,不可不延时,否则会导致无法读取IMEI和SN
sys.timerStart(myMqtt.mqttInit,5000)
