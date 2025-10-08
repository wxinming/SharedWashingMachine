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

--初始化Air202Spi
--@param  无
--@note:
    --spi.setup(id,chpa,cpol,dataBits,clock,duplex)
    --@param  id:SPI的ID,spi.SPI_1表示SPI1,Air201 Air202 Air800只有SPI1,固定传spi.SPI_1即可
    --@param  chpa:spi_clk idle的状态,仅支持0和1,0表示低电平,1表示高电平
    --@param  cpol:第几个clk的跳变沿传输数据,仅支持0和1,0表示第1个,1表示第2个
    --@param  dataBits:数据位,仅支持8
    --@param  clock:spi时钟频率,支持110K到13M(即110000到13000000)之间的整数(包含110000和13000000)
    --@param  duplex:是否全双工,仅支持0和1,0表示半双工(仅支持输出),1表示全双工.此参数可选，默认半双工
    --@return number:1成功,0失败

    --@other  GPIO10 SPI1_CS  从设备使能信号,由主设备控制
    --@other  GPIO8  SPI1_CLK 时钟信号,由主设备产生
    --@other  GPIO11 SPI1_DO  串行数据输出
--@return 1成功,0失败
local function initAir202Spi()
    local result = 0
    pmd.ldoset(7,pmd.LDO_VMMC)
    result = spi.setup(spi.SPI_1,1,1,8,110000,1)
    spi1Clk,spi1Cs,spi1Do = pins.setup(pio.P0_10,1),pins.setup(pio.P0_8,1),pins.setup(pio.P0_11,1)
    return result
end

--关闭Air202Spi接口
--@param  无
--@return 1成功,0失败
local function closeAir202Spi()
    return spi.close(spi.SPI_1)
end

--SPI管脚操作Lua脚本语言参考C语言进行代码编写
--[[
#define uchar unsigned char 
#define uint  unsigned int 
//定义控制端口 
sbit DIO =P2^0; 
sbit CLK =P2^1; 
sbit STB =P2^2; 
//定义数据 
uchar const CODE[]={0x3f,0x06,0x5b,0x4f,0x66,0x6d,0x7d,0x07,0xef,0x6f}; //共阴数码管0-9的编码 
uchar KEY[5]={0};  //为存储按键值开辟的数组

//向TM1628发送8位数据,从低位开始
void send_8bit(uchar dat) 
{ 
    uchar i; 
    for(i=0;i<8;i++) 
    {
        if(dat&0x01) 
            DIO=1; 
        else 
            DIO=0; 
        CLK=0; 
        CLK=1; 
        dat=dat>>1; 
    }
}

//向TM1628发送命令
void command(uchar com) 
{ 
    STB=1; 
    STB=0; 
    send_8bit(com); 
}

//读取按键值并存入KEY[]数组，从低字节开始，从低位开始---- 
void read_key() 
{ 
    uchar i,j; 
    command(0x42);  //读键盘命令 
    DIO=1;      //将DIO置高 
    for(j=0;j<5;j++)//连续读取5个字节 
        for(i=0;i<8;i++) 
        { 
            KEY[j]=KEY[j]>>1; 
            CLK=0; 
            CLK=1; 
            if(DIO) 
                KEY[j]=KEY[j]|0X80; 
        }
    STB=1;
} 

//显示函数,1-7位数码管显示数字0-6
void display() 
{ 
    uchar i; 
    command(0x03);      //设置显示模式，7位10段模式 
    command(0x40);      //设置数据命令,采用地址自动加1模式 
    command(0xc0);      //设置显示地址，从00H开始 
    for(i=0;i<7;i++)     //发送显示数据 
    { 
        send_8bit(CODE[i]);      //从00H起，偶数地址送显示数据 
        send_8bit(0);  //因为SEG9-14均未用到，所以奇数地址送全“0” 
    } 
    command(0x8F);      //显示控制命令，打开显示并设置为最亮 
    //read_key();       //读按键值 
    STB=1; 
} 

//按键处理函数
void key_process()
{
    //由用户编写
} 

//主函数
void main() 
{ 
    display();  //显示 
    while(1) 
    { 
        read_key();      //读按键值 
        key_process();    //按键处理
    } 
}
]]

--显示Led
--@param
--@return 无
function displayLed(num)
    sendLedCommand(0x03)
    sendLedCommand(0x40)
    sendLedCommand(0xc0)
    for i = 1,8 do
        send8Bit(tonumber(num))
        send8Bit(0)
    end
    sendLedCommand(0x8F)
    pio.pin.setval(1,pio.P0_10)
end

--发送8字节数据(参考以上C语言进行逻辑处理)
--@param  data:unsigned char
--@return 无
function send8Bit(data)
    for i = 1,8 do
        if bit.band(data,0x01) ~= 0 then
            pio.pin.setval(1,pio.P0_11)
        else
            pio.pin.setval(0,pio.P0_11)
        end
        pio.pin.setval(0,pio.P0_8)
        pio.pin.setval(1,pio.P0_8)
        data = bit.rshift(data,1)
    end
end

--发送Led命令
--@param  com:指令
--@return 无
function sendLedCommand(com)
    pio.pin.setval(1,pio.P0_10)
    pio.pin.setval(0,pio.P0_10)
    send8Bit(com)
end

--初始化GPIO接口
--@param  无
--@return 无
function initGpioInterface()
    if _G.PROJECT == "AIR202" then
        pin1,pin2,pin3 = pio.P0_29,pio.P0_31,pio.P0_30
		--此处为Air202Spi功能未完成,注释
		--[[
        local result = initAir202Spi()
        log.info("myGpio.initGpioInterface","result",result)
        if result == 1 then	displayLed(63)	end
		]]
    elseif _G.PROJECT == "AIR720" then
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
