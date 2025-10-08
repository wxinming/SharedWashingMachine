--����ģ��,����������
require"sys"
require"mqttssl"
module(...,package.seeall)

--mqtt�ͻ��˶���,���ݷ�������ַ,���ݷ������˿ڱ�
local mqttclient,gaddr,gports,gclientid,gusername,gpassword
--Ŀǰʹ�õ�gport���е�index
local gportidx = 1
local gconnectedcb,gconnecterrcb,gevtcbs
local productKey,deviceName
local sKeepAlive,sCleanSession,sWill

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������aliyuniotǰ׺
����  ����
����ֵ����
]]
local function print(...)
	_G.print("aliyuniotssl",...)
end

--[[
��������sckerrcb
����  ��SOCKETʧ�ܻص�����
����  ��
		r��string���ͣ�ʧ��ԭ��ֵ
			CONNECT��mqtt�ڲ���socketһֱ����ʧ�ܣ����ٳ����Զ�����
����ֵ����
]]
local function sckerrcb(r)
	print("sckerrcb",r,gportidx,#gports)
	if r=="CONNECT" then
		if gportidx<#gports then
			gportidx = gportidx+1
			connect(true)
		else
			sys.restart("aliyuniot sck connect err")
		end
	end
end

--[[
��������rcvmessage
����  ���յ�PUBLISH��Ϣʱ�Ļص�����
����  ��
		topic����Ϣ���⣨gb2312���룩
		payload����Ϣ���أ�ԭʼ���룬�յ���payload��ʲô���ݣ�����ʲô���ݣ�û�����κα���ת����
		qos����Ϣ�����ȼ�
����ֵ����
]]
local function rcvmessagecb(topic,payload,qos)
	--OTA��Ϣ
	if topic=="/ota/device/upgrade/"..productKey.."/"..(type(deviceName)=="function" and deviceName() or (deviceName or misc.getimei())) then
		if aliyuniotota and type(aliyuniotota)=="table" and aliyuniotota.upgrade and type(aliyuniotota.upgrade)=="function" then
			aliyuniotota.upgrade(payload)
		end
	--������Ϣ
	else
		gevtcbs.MESSAGE(topic,payload,qos)
	end
end

local function consucb()
	if gconnectedcb then gconnectedcb() end
	if aliyuniotota and type(aliyuniotota)=="table" and aliyuniotota.connectedCb and type(aliyuniotota.connectedCb)=="function" then
		aliyuniotota.connectedCb(productKey,type(deviceName)=="function" and deviceName() or (deviceName or misc.getimei()))
	end
end

function connect(change)
	if change then
		mqttclient:change("TCP",gaddr,gports[gportidx])
	else
		--����һ��mqttssl client
		mqttclient = mqttssl.create("TCP",gaddr,gports[gportidx])
	end
	--������������,�������Ҫ��������һ�д��룬���Ҹ����Լ����������will����
	if sWill then
		mqttclient:configwill(1,sWill.qos,sWill.retain,sWill.topic,sWill.payload)
	end
	mqttclient:setcleansession(sCleanSession)
	--����mqtt������
	mqttclient:connect(gclientid,sKeepAlive or 240,gusername,gpassword,consucb,gconnecterrcb,sckerrcb)
end

--[[
��������databgn
����  ����Ȩ��������֤�ɹ��������豸�������ݷ�����
����  ����		
����ֵ����
]]
local function databgn(host,ports,clientid,username,password)
	gaddr,gports,gclientid,gusername,gpassword = host or gaddr,ports or gports,clientid,username,password or ""
	gportidx = 1
	connect()
end

local procer =
{
	ALIYUN_DATA_BGN = databgn,
}

sys.regapp(procer)


--[[
��������config
����  �����ð�������������Ʒ��Ϣ���豸��Ϣ
����  ��
		productkey��string���ͣ���Ʒ��ʶ����ѡ����
		productsecret��string���ͣ���Ʒ��Կ����ѡ����,����ǰ����ƻ���2վ�㣬���봫��nil
		devicename: string���ͻ���function���ͣ��豸������ѡ����
		devicesecret: string���ͻ���function���ͣ��豸֤�飬��ѡ����
����ֵ����
]]
function config(productkey,productsecret,devicename,devicesecret)
	if productsecret then
		require"aliyuniotauth"
	else
		require"aliyuniotauthssl"
	end
	productKey,deviceName = productkey,devicename
	sys.dispatch("ALIYUN_AUTH_BGN",productkey,productsecret,devicename,devicesecret)
end

--- ����MQTT����ͨ���Ĳ���
-- @number[opt=1] cleanSession 1/0
-- @table[opt=nil] will ������������ʽΪ{qos=, retain=, topic=, payload=}
-- @number[opt=240] keepAlive����λ��
-- @return nil
-- @usage
-- aliyuniotssl.setMqtt(0)
-- aliyuniotssl.setMqtt(1,{qos=0,retain=1,topic="/willTopic",payload="will payload"})
-- aliyuniotssl.setMqtt(1,{qos=0,retain=1,topic="/willTopic",payload="will payload"},120)
function setMqtt(cleanSession,will,keepAlive)
    sCleanSession,sWill,sKeepAlive = cleanSession,will,keepAlive
end

function regcb(connectedcb,connecterrcb)
	gconnectedcb,gconnecterrcb = connectedcb,connecterrcb
end

function subscribe(topics,ackcb,usertag)
	mqttclient:subscribe(topics,ackcb,usertag)
end

function regevtcb(evtcbs)
	gevtcbs = evtcbs
	mqttclient:regevtcb({MESSAGE=rcvmessagecb})
end

function publish(topic,payload,qos,ackcb,usertag)
	if mqttclient then
		mqttclient:publish(topic,payload,qos,ackcb,usertag)
	else
		if ackcb then ackcb(usertag,false) end
	end
end

function getMqttStatus()
	if mqttclient then
		return mqttclient:getstatus()
	else
		return "INVALID"
	end
end