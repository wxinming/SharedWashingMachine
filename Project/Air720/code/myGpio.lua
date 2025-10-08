module(...,package.seeall)
require"pins"
require"myInit"
require"myUart"
require"algorithm"
require"sys"
require"log"

--检测电压,控制电压,检测投币
local detectionVoltage,controlVoltage,detectionCoin,pin1,pin2,pin3

--串口最大金额,串口最大指令
local uartMaxMoney,uartMaxHex = 0,""

--是否投币,投币安全开关
local isGpio,coinSecurity= true,true

--是否投币完成,脉冲设备是否工作(true无工作,false在工作),投币金额
isCoinOk,gpioWorking,coinMoney = true,true,0

--数码管
local spi1Cs,spi1Clk,spi1Do

--检测输入电压的回调函数
--@param  msg:gpio上升沿和下降沿
--@return 无
local function detectionInputVoltageCbFnc(msg)
    log.info("myGpio.detectionInputVoltageCbFnc",msg,detectionVoltage())
    if detectionVoltage() == 0 then
        myUart.sendCompleteWork()
    else
        myUart.sendStartWork(coinMoney)
    end
    gpioWorking = detectionVoltage() == 0
    coinMoney = 0
    pullupVoltage(detectionVoltage() == 0 and 1 or 0)
    setCoinSecurity()
end

--初始化检测输入电压
--@param  pin:脉冲引脚
--@return 无
local function initDetectionInputVoltage(pin)
    return pins.setup(pin,detectionInputVoltageCbFnc)
end

--初始化控制输出电压
--@param  pin:脉冲引脚
--@return 无
local function initControlOutputVoltage(pin)
    return pins.setup(pin,1)
end

--拉低电压
--@param  action:0否,1是
--@return 无
function pullupVoltage(action)
    controlVoltage(action)
end

--发送脉冲投币指令
--@param  reversed:定时器预留参数
--@return 无
local function sendGpioCoinOk(reserved)
    algorithm.uartWriteStr(myUart.MCU_ID,"AA0202010A0A00C3")
end

--发送串口投币指令
--@param  reversed:定时器预留参数
--@return 无
local function sendUartCoinOk(reserved)
    algorithm.uartWriteStr(myUart.UART_ID,algorithm.getUartCoinHex(coinMoney))
end

--设置投币安全
--@param  无
--@return 无
function setCoinSecurity()
	coinSecurity = false
	sys.timerStart(function() coinSecurity = true end,500)
end

--检测投币输入回调函数
--@param  msg:gpio上升沿和下降沿
--@return 无
local function detectionCoinInputCbFnc(msg)
    log.info("myGpio.detectionCoinInputCbFnc",msg,detectionCoin())
    if not coinSecurity or detectionCoin() ~= 1 then return end

    coinMoney = coinMoney + 1
    if isGpio then
        isCoinOk = false
        log.info("myGpio.detectionCoinInputCbFnc","isGpio")
        algorithm.uartWriteStr(myUart.MCU_ID,"AA0102010A0400BC")
        algorithm.stopRunningTimer(sendGpioCoinOk,"sendGpioCoinOk")
        sys.timerStart(sendGpioCoinOk,15000,"sendGpioCoinOk")
    else
        log.info("myGpio.detectionCoinInputCbFnc","isUart")
        if myInit.style == "uartc" then
            algorithm.uartWriteStr(myUart.UART_ID,"AA20DBFB0000000000020201FFFFFFFFFFFFFFFFFFFFFF00FFFF00FFFFFFFFFF17")
        elseif myInit.style == "pul_uartc" then
            algorithm.uartWriteStr(myUart.UART_ID,"AA1EDAC40000000000020201FFFFFFFFFF00FFFFFFFFFFFFFFFFFFFFFFFF50")
        end

        if coinMoney >= uartMaxMoney then
            pullupVoltage(0)
            algorithm.uartWriteStr(myUart.UART_ID,uartMaxHex)
            algorithm.stopRunningTimer(sendUartCoinOk,"sendUartCoinOk")
        else
            algorithm.stopRunningTimer(sendUartCoinOk,"sendUartCoinOk")
            sys.timerStart(sendUartCoinOk,15000,"sendUartCoinOk")
        end
    end
end

--初始化检测投币输入
--@param  pin:脉冲引脚
--@return 无
local function initDetectionCoinInput(pin)
    if myInit.style ~= "gpio" then
        isGpio = false
        uartMaxMoney,uartMaxHex = algorithm.getMaxMoneyHex()
        if uartMaxMoney == -1 or uartMaxHex == "" then
            log.info("myGpio.initDetectionCoinInput","not found coin configuration file")
            pullupVoltage(0)
            myInit.isCoin = false
        end
    end
    return pins.setup(pin,detectionCoinInputCbFnc)
end

--[[
功能：配置SPI

参数：
id：SPI的ID，spi.SPI_1表示SPI1，Air201、Air202、Air800只有SPI1，固定传spi.SPI_1即可
chpa：spi_clk idle的状态，仅支持0和1，0表示低电平，1表示高电平
cpol：第几个clk的跳变沿传输数据，仅支持0和1，0表示第1个，1表示第2个
dataBits：数据位，仅支持8
clock：spi时钟频率，支持110K到13M（即110000到13000000）之间的整数（包含110000和13000000）
duplex：是否全双工，仅支持0和1，0表示半双工（仅支持输出），1表示全双工。此参数可选，默认半双工

返回值：number类型，1表示成功，0表示失败
]]
local function setAir202Spi()
    spi1Clk,spi1Cs,spi1Do = pins.setup(pio.P0_2,1),pins.setup(pio.P0_3,1),pins.setup(pio.P0_4,1)
    pmd.ldoset(7,pmd.LDO_VMMC)
    return spi.setup(spi.SPI_1,0,0,8,110000,0)
end

---初始化GPIO接口
--@param  无
--@return 无
function initGpioInterface()
    if _G.FRAMEWORK == "AIR202" then
        pin1,pin2,pin3 = pio.P0_29,pio.P0_31,pio.P0_30
        if setAir202Spi() == 0 then
            log.info("myGpio.initGpioInterface","setAir202Spi","success")
            spi.send(spi.SPI_1,"0x03")
            spi.send(spi.SPI_1,"0x40")
            spi.send(spi.SPI_1,"0xC0")
        end
    elseif _G.FRAMEWORK == "AIR720" then
        pin1,pin2,pin3 = pio.P0_26,pio.P0_27,pio.P0_28
    end

    if myInit.style == "gpio" then
        --检测电压输入
        detectionVoltage = initDetectionInputVoltage(pin1)
    end
    --控制电压输出
    controlVoltage = initControlOutputVoltage(pin2)
    --检测投币输入
    detectionCoin = initDetectionCoinInput(pin3)
end
