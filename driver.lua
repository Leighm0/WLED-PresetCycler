-------------
-- Globals --
-------------
do
	EC = {}
	OPC = {}
	RFP = {}
	g_MAX_PRESETS = 1
	g_IP = "0.0.0.0"
	g_UDP_PORT = 21324
	g_LIGHT_PROXY = 5001
	g_UIBUTTON_PROXY = 5002
	g_currentPreset = "off"
	g_lightOn = false
	g_lightLevel = 0
	g_debugMode = 0
	g_DbgPrint = nil
end

----------------------------------------------------------------------------
--Function Name : OnDriverInit
--Description   : Function invoked when a driver is loaded or being updated.
----------------------------------------------------------------------------
function OnDriverInit()
	C4:UpdateProperty("Driver Name", C4:GetDriverConfigInfo("name"))
	C4:UpdateProperty("Driver Version", C4:GetDriverConfigInfo("version"))
	C4:AllowExecute(true)
end

------------------------------------------------------------------------------------------------
--Function Name : OnDriverLateInit
--Description   : Function that serves as a callback into a project after the project is loaded.
------------------------------------------------------------------------------------------------
function OnDriverLateInit()
	for k,v in pairs(Properties) do OnPropertyChanged(k) end
	C4:SendToProxy(g_LIGHT_PROXY, "ONLINE_CHANGED", { STATE = true }, "NOTIFY")
	C4:SendToProxy(g_LIGHT_PROXY, "ONLINE_CHANGED", "true", "NOTIFY")
	C4:CreateServer(g_UDP_PORT, "", true)
end

-----------------------------------------------------------------------------------------------------------------------------
--Function Name : OnDriverDestroyed
--Description   : Function called when a driver is deleted from a project, updated within a project or Director is shut down.
-----------------------------------------------------------------------------------------------------------------------------
function OnDriverDestroyed()
	if (g_DbgPrint ~= nil) then g_DbgPrint:Cancel() end
	C4:DestroyServer(g_UDP_PORT)
end

-----------------------------------------------------------------------
--Function Name : OnServerDataIn
--Parameters    : nHandle(int), strData(table)
--Description   : Function called when Data comes in from CreateServer.
-----------------------------------------------------------------------
function OnServerDataIn(nHandle, strData)
	local brightness = 0
	brightness = math.floor((string.byte(strData,3) / 255) * 100)
	g_lightLevel = brightness
	C4:SendToProxy(g_LIGHT_PROXY, "LIGHT_LEVEL_CHANGED", g_lightLevel, "NOTIFY")
	C4:SendToProxy(g_LIGHT_PROXY, "LIGHT_LEVEL", g_lightLevel, "NOTIFY")
	if (g_lightLevel == 0) then
		g_lightOn = false
		g_currentPreset = "off"
		C4:SendToProxy(300, "MATCH_LED_STATE", {['STATE'] = "False"})
		C4:SendToProxy(301, "MATCH_LED_STATE", {['STATE'] = "True"})
		C4:SendToProxy(302, "MATCH_LED_STATE", {['STATE'] = "False"})
		C4:UpdateProperty("Power State", "off")
		C4:UpdateProperty("Brightness", g_lightLevel)
	else
		g_lightOn = true
		if (g_currentPreset == "off") then
			g_currentPreset = "on"
		end
		C4:SendToProxy(300, "MATCH_LED_STATE", {['STATE'] = "True"})
		C4:SendToProxy(301, "MATCH_LED_STATE", {['STATE'] = "False"})
		C4:SendToProxy(302, "MATCH_LED_STATE", {['STATE'] = "True"})
		C4:UpdateProperty("Power State", "on")
		C4:UpdateProperty("Brightness", g_lightLevel)
	end
end

----------------------------------------------------------------------------
--Function Name : OnPropertyChanged
--Parameters    : strProperty(str)
--Description   : Function called by Director when a property changes value.
----------------------------------------------------------------------------
function OnPropertyChanged(strProperty)
	Dbg("OnPropertyChanged: " .. strProperty .. " (" .. Properties[strProperty] .. ")")
	local propertyValue = Properties[strProperty]
	if (propertyValue == nil) then propertyValue = "" end
	local strProperty = string.upper(strProperty)
	strProperty = string.gsub(strProperty, "%s+", "_")
	local success, ret
	if (OPC and OPC[strProperty] and type(OPC[strProperty]) == "function") then
		success, ret = pcall(OPC[strProperty], propertyValue)
	end
	if (success == true) then
		return (ret)
	elseif (success == false) then
		print ("OnPropertyChanged Lua error: ", strProperty, ret)
	end
end

-------------------------------------------------------------------------
--Function Name : OPC.DEBUG_MODE
--Parameters    : strProperty(str)
--Description   : Function called when Debug Mode property changes value.
-------------------------------------------------------------------------
function OPC.DEBUG_MODE(strProperty)
	if (strProperty == "Off") then
		if (g_DbgPrint ~= nil) then g_DbgPrint:Cancel() end
		g_debugMode = 0
		print ("Debug Mode: Off")
	else
		g_debugMode = 1
		print ("Debug Mode: On for 8 hours")
		g_DbgPrint = C4:SetTimer(28800000, function(timer)
			C4:UpdateProperty("Debug Mode", "Off")
			timer:Cancel()
		end, false)
	end
end

-------------------------------------------------------------------------
--Function Name : OPC.IP_ADDRESS
--Parameters    : strProperty(str)
--Description   : Function called when IP Address property changes value.
-------------------------------------------------------------------------
function OPC.IP_ADDRESS(strProperty)
	g_IP = strProperty or "0.0.0.0"
end

---------------------------------------------------------------------------------
--Function Name : OPC.UDP_MULTICAST_PORT
--Parameters    : strProperty(str)
--Description   : Function called when UDP Multicast Port property changes value.
---------------------------------------------------------------------------------
function OPC.UDP_MULTICAST_PORT(strProperty)
	C4:DestroyServer(g_UDP_PORT)
	g_UDP_PORT = strProperty or 21324
	C4:CreateServer(g_UDP_PORT, "", true)
end

----------------------------------------------------------------------
--Function Name : OPC.PRESETS
--Parameters    : strProperty(str)
--Description   : Function called when Presets property changes value.
----------------------------------------------------------------------
function OPC.PRESETS(strProperty)
	g_MAX_PRESETS = strProperty or 1
end

-----------------------------------------------------------------------------------------------------
--Function Name : ExecuteCommand
--Parameters    : strCommand(str), tParams(table)
--Description   : Function called by Director when a command is received for this DriverWorks driver.
-----------------------------------------------------------------------------------------------------
function ExecuteCommand(strCommand, tParams)
	tParams = tParams or {}
	Dbg("ExecuteCommand: " .. strCommand .. " (" ..  formatParams(tParams) .. ")")
	if (strCommand == "LUA_ACTION") then
		if (tParams.ACTION) then
			strCommand = tParams.ACTION
			tParams.ACTION = nil
		end
	end
	local strCommand = string.upper(strCommand)
	strCommand = string.gsub(strCommand, "%s+", "_")
	local success, ret
	if (EC and EC[strCommand] and type(EC[strCommand]) == "function") then
		success, ret = pcall(EC[strCommand], tParams)
	end
	if (success == true) then
		return (ret)
	elseif (success == false) then
		print ("ExecuteCommand Lua error: ", strCommand, ret)
	end
end

----------------------------------------------------------------------------------
--Function Name : EC.SELECT_PRESET
--Parameters    : tParams(table)
--Description   : Function called when "Select Preset" ExecuteCommand is received.
----------------------------------------------------------------------------------
function EC.SELECT_PRESET(tParams)
	local preset = tParams["Preset"] or "off"
	setPreset(preset)
end

----------------------------------------------------------------------------------
--Function Name : EC.CUSTOM_PRESET
--Parameters    : tParams(table)
--Description   : Function called when "Custom Preset" ExecuteCommand is received.
----------------------------------------------------------------------------------
function EC.CUSTOM_PRESET(tParams)
	local preset = tParams["Preset"] or "off"
	setWLEDPreset(preset)
end

-----------------------------------------------------------------
--Function Name : ReceivedFromProxy
--Parameters    : idBinding(int), strCommand(str), tParams(table)
--Description   : Function called when proxy command is called
-----------------------------------------------------------------
function ReceivedFromProxy(idBinding, strCommand, tParams)
	tParams = tParams or {}
	Dbg("ReceivedFromProxy: [" .. idBinding .. "] : " .. strCommand .. " (" ..  formatParams(tParams) .. ")")
	local strCommand = string.upper(strCommand)
	strCommand = string.gsub(strCommand, "%s+", "_")
	if(strCommand == "PROXY_NAME" or strCommand =="CAPABILITIES_CHANGED" or strCommand =="AV_BINDINGS_CHANGED" or strCommand=="DEFAULT_ROOM") then
		return 
	end
	local success, ret
	if (RFP and RFP[strCommand] and type(RFP[strCommand]) == "function") then
		success, ret = pcall(RFP[strCommand], idBinding, tParams)
	end
	if (success == true) then
		return (ret)
	elseif (success == false) then
		print ("ReceivedFromProxy Lua error: ", strCommand, ret)
	end
end

------------------------------------------------------------------------------
--Function Name : RFP.SELECT
--Parameters    : tParams(table), idBinding(int)
--Description   : Function called when "SELECT" ReceivedFromProxy is received.
------------------------------------------------------------------------------
function RFP.SELECT(idBinding, tParams)
	if(idBinding == g_UIBUTTON_PROXY) then
		nextPreset()
	end
end

--------------------------------------------------------------------------
--Function Name : RFP.ON
--Parameters    : tParams(table), idBinding(int)
--Description   : Function called when "ON" ReceivedFromProxy is received.
--------------------------------------------------------------------------
function RFP.ON(idBinding, tParams)
	if(idBinding == g_LIGHT_PROXY) then
		setWLEDOn()
	end
end

---------------------------------------------------------------------------
--Function Name : RFP.OFF
--Parameters    : tParams(table), idBinding(int)
--Description   : Function called when "OFF" ReceivedFromProxy is received.
---------------------------------------------------------------------------
function RFP.OFF(idBinding, tParams)
	if(idBinding == g_LIGHT_PROXY) then
		setWLEDOff()
	end
end

------------------------------------------------------------------------------
--Function Name : RFP.TOGGLE
--Parameters    : tParams(table), idBinding(int)
--Description   : Function called when "TOGGLE" ReceivedFromProxy is received.
------------------------------------------------------------------------------
function RFP.TOGGLE(idBinding, tParams)
	if(idBinding == g_LIGHT_PROXY) then
		if(g_lightOn == true) then
			setWLEDOff()
		else
			setWLEDOn()
		end
	end
end

---------------------------------------------------------------------------------
--Function Name : RFP.SET_LEVEL
--Parameters    : tParams(table), idBinding(int)
--Description   : Function called when "SET LEVEL" ReceivedFromProxy is received.
---------------------------------------------------------------------------------
function RFP.SET_LEVEL(idBinding, tParams)
	if(idBinding == g_LIGHT_PROXY) then
		RFP.RAMP_TO_LEVEL(idBinding, tParams)
	end
end

-------------------------------------------------------------------------------------
--Function Name : RFP.BUTTON_ACTION
--Parameters    : tParams(table), idBinding(int)
--Description   : Function called when "BUTTON ACTION" ReceivedFromProxy is received.
-------------------------------------------------------------------------------------
function RFP.BUTTON_ACTION(idBinding, tParams)
	if(idBinding == g_LIGHT_PROXY) then
		if(tParams["BUTTON_ID"] == "0" and tParams["ACTION"] == "2") then
			setWLEDOn()
		elseif(tParams["BUTTON_ID"] == "1" and tParams["ACTION"] == "2") then
			setWLEDOff()
		elseif(tParams["BUTTON_ID"] == "2" and tParams["ACTION"] == "2") then
			if(g_lightOn == true) then
				setWLEDOff()
			else
				setWLEDOn()
			end
		end
	end
end

-------------------------------------------------------------------------------------
--Function Name : RFP.RAMP_TO_LEVEL
--Parameters    : tParams(table), idBinding(int)
--Description   : Function called when "RAMP TO LEVEL" ReceivedFromProxy is received.
-------------------------------------------------------------------------------------
function RFP.RAMP_TO_LEVEL(idBinding, tParams)
	if(idBinding == g_LIGHT_PROXY) then
		local level = math.floor((tParams["LEVEL"] * .01) * 255)
		g_lightLevel = level
		setWLEDLevel(g_lightLevel)
		if(g_lightLevel > 0) then
			g_lightOn = true
			if(g_currentPreset == "off") then
				setPreset("on")
				g_currentPreset = "on"
			end
		else 
			g_lightOn = false
			setPreset("off")
		end
		C4:SendToProxy(g_LIGHT_PROXY, "LIGHT_LEVEL_CHANGED", g_lightLevel, "NOTIFY")
		C4:SendToProxy(g_LIGHT_PROXY, "LIGHT_LEVEL", g_lightLevel, "NOTIFY")
		if (g_lightLevel == 0) then
			C4:UpdateProperty("Power State", "off")
			C4:UpdateProperty("Brightness", g_lightLevel)
			C4:SendToProxy(300, "MATCH_LED_STATE", {['STATE'] = "False"})
			C4:SendToProxy(301, "MATCH_LED_STATE", {['STATE'] = "True"})
			C4:SendToProxy(302, "MATCH_LED_STATE", {['STATE'] = "False"})
		else
			C4:UpdateProperty("Power State", "on")
			C4:UpdateProperty("Brightness", g_lightLevel)
			C4:SendToProxy(300, "MATCH_LED_STATE", {['STATE'] = "True"})
			C4:SendToProxy(301, "MATCH_LED_STATE", {['STATE'] = "False"})
			C4:SendToProxy(302, "MATCH_LED_STATE", {['STATE'] = "True"})
		end
	end
end

-------------------------------------------------------------------------------------------
--Function Name : RFP.GET_CONNECTED_STATE
--Parameters    : tParams(table), idBinding(int)
--Description   : Function called when "GET CONNECTED STATE" ReceivedFromProxy is received.
-------------------------------------------------------------------------------------------
function RFP.GET_CONNECTED_STATE(idBinding, tParams)
	if(idBinding == g_LIGHT_PROXY) then
		C4:SendToProxy(g_LIGHT_PROXY, "ONLINE_CHANGED", { STATE = true }, "NOTIFY")
		C4:SendToProxy(g_LIGHT_PROXY, "ONLINE_CHANGED", "true", "NOTIFY")
	end
end

--------------------------------------------------------------------------------------------------
--Function Name : setWLEDPreset
--Parameters    : preset(int)
--Description   : Function called to send the Preset to WLED Controller based on Preset Selection.
--------------------------------------------------------------------------------------------------
function setWLEDPreset(preset) 
	local baseUrl = "http://" .. g_IP .. "/win&PL="
	local queryUrl = baseUrl .. preset
	local t = C4:url() :OnDone(
		function(transfer, responses, errCode, errMsg) 
			if (errCode == 0) then
				local lresp = responses[#responses]
				g_lightOn = true
			else
				if (errCode == -1) then 
					Dbg("OnDone: transfer was aborted")
				else
					Dbg("OnDone: transfer failed with error " .. errCode .. ": " .. errMsg .. " (" .. #responses .. " responses completed)") 
				end
			end 
		end)
	:SetOptions({ ["fail_on_error"] = false, ["timeout"] = 30, ["connect_timeout"] = 10})
	:Get(queryUrl, {})
end

--------------------------------------------------------
--Function Name : setWLEDOn
--Parameters    : preset(int)
--Description   : Function called to turn WLED light on.
--------------------------------------------------------
function setWLEDOn() 
	setWLEDLevel(255)
	g_lightOn = true
	setPreset("on")
	C4:SendToProxy(g_LIGHT_PROXY, "LIGHT_LEVEL_CHANGED", "100", "NOTIFY")
	C4:SendToProxy(g_LIGHT_PROXY, "LIGHT_LEVEL", 100, "NOTIFY")
	C4:SendToProxy(300, "MATCH_LED_STATE", {['STATE'] = "True"})
	C4:SendToProxy(301, "MATCH_LED_STATE", {['STATE'] = "False"})
	C4:SendToProxy(302, "MATCH_LED_STATE", {['STATE'] = "True"})
	C4:UpdateProperty("Power State", "on")
	C4:UpdateProperty("Brightness", "100")
end

---------------------------------------------------------
--Function Name : setWLEDOff
--Parameters    : preset(int)
--Description   : Function called to turn WLED light off.
---------------------------------------------------------
function setWLEDOff() 
	setWLEDLevel(0)
	g_lightOn = false
	setPreset("off")
	C4:SendToProxy(g_LIGHT_PROXY, "LIGHT_LEVEL_CHANGED", "0", "NOTIFY")
	C4:SendToProxy(g_LIGHT_PROXY, "LIGHT_LEVEL", 0, "NOTIFY")
	C4:SendToProxy(300, "MATCH_LED_STATE", {['STATE'] = "False"})
	C4:SendToProxy(301, "MATCH_LED_STATE", {['STATE'] = "True"})
	C4:SendToProxy(302, "MATCH_LED_STATE", {['STATE'] = "False"})
	C4:UpdateProperty("Power State", "off")
	C4:UpdateProperty("Brightness", "0")
end

-----------------------------------------------------------------------------------------------------------
--Function Name : setWLEDLevel
--Parameters    : level(int)
--Description   : Function called to send the Brightness Level to WLED Controller based on Level Selection.
-----------------------------------------------------------------------------------------------------------
function setWLEDLevel(level) 
	local baseUrl = "http://" .. g_IP .. "/win&A="
	local queryUrl = baseUrl .. level
	local t = C4:url() :OnDone(
		function(transfer, responses, errCode, errMsg) 
			if (errCode == 0) then
				local lresp = responses[#responses]
			else
				if (errCode == -1) then 
					Dbg("OnDone: transfer was aborted")
				else
					Dbg("OnDone: transfer failed with error " .. errCode .. ": " .. errMsg .. " (" .. #responses .. " responses completed)") 
				end
			end 
		end)
	:SetOptions({ ["fail_on_error"] = false, ["timeout"] = 30, ["connect_timeout"] = 10})
	:Get(queryUrl, {})
end

------------------------------------------------------------------------------
--Function Name : setPreset
--Parameters    : preset(str)
--Description   : Function called to set the Preset based on Preset Selection.
------------------------------------------------------------------------------
function setPreset(preset)
	C4:SendToProxy(g_UIBUTTON_PROXY, "ICON_CHANGED", {icon=preset, icon_description="Preset=" .. preset})
	g_currentPreset = preset
    if(g_currentPreset == "off") then
		setWLEDLevel(0)
		g_lightOn = false
		C4:SendToProxy(g_LIGHT_PROXY, "LIGHT_LEVEL_CHANGED", "0", "NOTIFY")
		C4:SendToProxy(g_LIGHT_PROXY, "LIGHT_LEVEL", 0, "NOTIFY")
		C4:SendToProxy(300, "MATCH_LED_STATE", {['STATE'] = "False"})
		C4:SendToProxy(301, "MATCH_LED_STATE", {['STATE'] = "True"})
		C4:SendToProxy(302, "MATCH_LED_STATE", {['STATE'] = "False"})
		C4:UpdateProperty("Power State", "off")
		C4:UpdateProperty("Brightness", "0")
    elseif(g_currentPreset == "on") then
		setWLEDPreset(99)
    elseif(g_currentPreset == "1") then
		setWLEDPreset(1) 
    elseif(g_currentPreset == "2") then
		setWLEDPreset(2)
    elseif(g_currentPreset == "3") then
		setWLEDPreset(3)
    elseif(g_currentPreset == "4") then
		setWLEDPreset(4)
    elseif(g_currentPreset == "5") then
		setWLEDPreset(5)
    elseif(g_currentPreset == "6") then
		setWLEDPreset(6)
    elseif(g_currentPreset == "7") then
		setWLEDPreset(7)
    elseif(g_currentPreset == "8") then
		setWLEDPreset(8)
    elseif(g_currentPreset == "9") then
		setWLEDPreset(9)
    elseif(g_currentPreset == "10") then
		setWLEDPreset(10)
    end
end

--------------------------------------------------------------
--Function Name : nextPreset
--Description   : Function called to cycle to the next Preset.
--------------------------------------------------------------
function nextPreset()
	if(g_currentPreset == "off") then
		g_currentPreset = "1"
    elseif(g_currentPreset == "on") then
		g_currentPreset = "1"
    elseif(g_currentPreset == "" .. g_MAX_PRESETS) then
		g_currentPreset = "off"
    else
		g_currentPreset = "" .. tonumber(g_currentPreset) + 1
    end
	setPreset(g_currentPreset)
end

---------------------------------------------------------------------------------------------
--Function Name : Dbg
--Parameters    : strDebugText(str)
--Description   : Function called when debug information is to be printed/logged (if enabled)
---------------------------------------------------------------------------------------------
function Dbg(strDebugText)
    if (g_debugMode == 1) then print(strDebugText) end
end

---------------------------------------------------------
--Function Name : formatParams
--Parameters    : tParams(table)
--Description   : Function called to format table params.
---------------------------------------------------------
function formatParams(tParams)
	tParams = tParams or {}
	local out = {}
	for k,v in pairs(tParams) do
		if (type(v) == "string") then
			table.insert(out, k .. " = \"" .. v .. "\"")
		else
			table.insert(out, k .. " = " .. tostring(v))
		end
	end
	return "{" .. table.concat(out, ", ") .. "}"
end
