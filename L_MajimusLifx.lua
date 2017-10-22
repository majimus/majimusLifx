--[[
August 12, 2017
Created by Majimus.

Based on/inspired by the code found at: 
http://forum.micasaverde.com/index.php/topic,36961.msg275597.html#msg275597

and also inspired by:
https://github.com/toggledbits/DeusExMachina

This provides ability to control LIFX lights via Vera U17.
The implementation uses the LIFX API (RESTful) and therefore an internet connection is
required for network access to LIFX servers. 

The "ApiKey" variable below must be updated with your private API token from LIFX:
	https://cloud.lifx.com/settings
	
At this time we also need the "LightId" in the format "id:xxxxxxxx"

More info on installation and setup here:
	
More functionality and refinement will be added with time.
--]]
module("L_MajimusLifx", package.seeall)

-- Module Version
PLUGIN_VERSION = '0.2'

https = require("ssl.https")
ltn12 = require("ltn12")

-- using json lib from https://gist.github.com/tylerneylon/59f4bcf316be525b30ab
-- changed name from json.lua to avoid conflicts
-- wrapped it in a module as well.
local json = require("L_MajimusJsonTyler")  

local SID = "urn:majimus-com:serviceId:Lifx"
local BDID = "urn:schemas-majimus-com:device:LifxBulb:1"
local SDID = "urn:schemas-majimus-com:device:LifxScene:1"
local PDID = "urn:schemas-majimus-com:device:LifxParent:1"
local SWITCH_SID  = "urn:upnp-org:serviceId:SwitchPower1"
local DIMMER_SID  = "urn:upnp-org:serviceId:Dimming1"
local COLOR_SID  = "urn:micasaverde-com:serviceId:Color1"

--vars for parent
local g_appendPtr

--debug mode
DEBUG = 0
--update bulbs every 3 mins
DELAY = 180

--we should run the stats updater only once
STATS_RUNNING = false

TypeDeviceFileMap = {
	[ "bulb" ] = "D_MajimusLifx_B.xml",
	[ "scene" ] = "D_MajimusLifx_S.xml"
}


local function log(textParm, level)
    level = level or 1
    if DEBUG >= level then
        local text = ''
        local theType = type(textParm)
        if theType == 'string' then
            text = textParm
        else
            text = 'type is: '..theType
        end
        luup.log('MajimusLifx '..PLUGIN_VERSION..' debug: '..text, 50)
    end
end

local function lifx_ctrl(selector, mode, color, bright, cycles, period)
    log("Lifx cloud ctrl",1)
	https.TIMEOUT = 7
	local resp = {}
	local payload = ''
	local selmethod, selurl, key, value, stat, power, connected, err
	local token = luup.variable_get(SID, "ApiKey", luup.device) or "0"
	
	log("Token "..token,2)
	
	-- Default values
	color = color or "rgb:0,255,0" -- if color nil or false then use green at brightest
	bright = bright or 1.0  -- if bright nil or false then use 1.0
	period = period or 1  -- if period nil or false then use 1
	cycles = cycles or 1  -- if period nil or false then use 1
	
	if selector then
		log("Entry Selector:"..selector,2)
	else
		log("Entry Selector: nil",2)
		if mode == "list" then
			selector = "all"
		end
	end
	
	selector = selector or luup.variable_get(SID, "LightId", luup.device) or ""
	
	log("Final Selector:"..selector,2)
		
	if mode == "pulse" then
		selmethod = "POST"
		selurl = "https://api.lifx.com/v1/lights/" .. selector .. "/effects/pulse"
		payload = '{"cycles": ' .. cycles .. ', "power_on": "true", "persist": "false", "color": "'
					.. color .. ', brightness:' .. bright .. '", "period": ' .. period .. '}'
	elseif mode == "breathe" then
		selmethod = "POST"
		selurl = "https://api.lifx.com/v1/lights/" .. selector .. "/effects/breathe"
		payload = '{"cycles": ' .. cycles .. ', "power_on": "true", "persist": "false", "color": "'
					.. color .. ', brightness:' .. bright .. '", "period": ' .. period .. '}'
	elseif mode == "brightness" then
		selmethod = "PUT"
		selurl = "https://api.lifx.com/v1/lights/" .. selector .. "/state"
		payload = '{"brightness":' ..bright.. '}'
	elseif mode == "color" then
		selmethod = "PUT"
		selurl = "https://api.lifx.com/v1/lights/" .. selector .. "/state"
		payload = '{"color": "' .. color .. '"}'
	elseif mode == "on" then
		selmethod = "PUT"
		selurl = "https://api.lifx.com/v1/lights/" .. selector .. "/state"
		payload = '{"power": "on"}'
	elseif mode == "off" then
		selmethod = "PUT"
		selurl = "https://api.lifx.com/v1/lights/" .. selector .. "/state"
		payload = '{"power": "off"}'
	elseif mode == "toggle" then
		selmethod = "POST"
		selurl = "https://api.lifx.com/v1/lights/" .. selector .. "/toggle"
		payload = ''
	elseif mode == "list" then
		selmethod = "GET"
		selurl = "https://api.lifx.com/v1/lights/" .. selector
		payload = ''
	elseif mode == "scene" then
		selmethod = "PUT"
		selurl = "https://api.lifx.com/v1/scenes/" .. selector .. "/activate"
		payload = '{"duration": "' .. period .. '"}'
	else
		log("Unknown Command!")
		return false
	end
	
	if(payload:len()> 0) then
		log("payload"..payload,2)
	end
	
	local result, statuscode, response_body, status = https.request {
		url = selurl,
		method = selmethod,
		headers = {
				   ["Authorization"] = "Bearer "..token,
				   ["Content-Type"] = "application/json",
				   ["Content-Length"] = payload:len() },
		source = ltn12.source.string(payload),
		sink = ltn12.sink.table(resp)
	 }
	
	if(resp[1] == nil) then
	    log("Lifx NULL response",1) 
		return
	end
	
	local jsondata = json.parse(resp[1])  --resp is a table where resp[1] is string containing json
	
	--for the list command we return multidata
	if(mode == "list") then
		return jsondata
	end	
	
	--return status for individual light command
	key, value = pairs(jsondata)
	
	if type(value["results"]) == "table" then 
		jsondata = jsondata.results[1]
	elseif type(value[1]) == "table" then 
		jsondata = jsondata[1]
	end
	
	for key, value in pairs(jsondata) do
		--print(key, value)
		if key == "power" then
			power = value
		elseif key == "connected" then
			connected = value
		elseif key == "status" then
			stat = value
		elseif key == "brightness" then
			brightness = value
		elseif key == "error" then
			err = value
		end
	end
	
	--return stat, power, connected, err, resp[1]
	if(stat == "ok") then
		return true
	else
		return false
	end
end


local function getLoadLevel(lul_device)
	level = luup.variable_get(DIMMER_SID, "LoadLevelTarget", lul_device)
	return level
end


function turnOn(lul_device)
	log("TurnOn")
	local sel = luup.variable_get(SID, "LightId", lul_device)	
	--handle the scene
	if(luup.devices[lul_device].device_type == SDID) then
		log("Play Scene")
		delay = luup.variable_get(SID, "SceneDelay", lul_device) or "0"
		lifx_ctrl(sel, "scene", nil, nil, nil, delay)
		return
	end	
	--lifx_ctrl(selector, mode, color, bright, cycles, period)
	local stat = lifx_ctrl(sel, "on", nil, nil, nil, nil)	
	-- do not update if we returned
	if(stat == false) then
		return
	end
	luup.variable_set(SWITCH_SID,"Status", 1, lul_device)
	--get Target Level
	loadLevel = getLoadLevel(lul_device)
    luup.variable_set(DIMMER_SID,"LoadLevelStatus", loadLevel, lul_device)	
end

function turnOff(lul_device)
	log("TurnOff")	
	if (luup.devices[lul_device].device_type == BDID) then
		log("Turn off light")
		local sel = luup.variable_get(SID, "LightId", lul_device)	
		--lifx_ctrl(selector, mode, color, bright, cycles, period)
		local stat = lifx_ctrl(sel, 'off', nil, nil, nil, nil)
		-- do not update if we returned
		if(stat == false) then
			return
		end
	elseif (luup.devices[lul_device].device_type == SDID) then
		log("Turn off a scene, nothing to do")
	end	
	luup.variable_set(SWITCH_SID, "Status", 0, lul_device)
	luup.variable_set(DIMMER_SID,"LoadLevelStatus", 0, lul_device)
end

function setLoadLevelTarget(target,lul_device)
	log("SetLoadLevel:" .. target)
	local sel = luup.variable_get(SID, "LightId", lul_device)
	--set target to range 0.0 - 1.0
	target_scaled = (target / 100.0) * 1.0	
	
	--non zero target turn on
	if (target ~= "0") then
		--lifx_ctrl(selector, mode, color, bright, cycles, period)
		log("SetLoadLevel Scaled:" .. target)
		stat = lifx_ctrl(sel, 'brightness', nil, target_scaled, nil, nil)
		
		-- do not update if we returned
		if(stat == false) then
			return
		end
		luup.variable_set(DIMMER_SID, "LoadLevelTarget", target, lul_device)
	
		-- Turn on lights now, will come on at set target	
		turnOn(lul_device)
	else
		--turn off we have zero target
		turnOff(lul_device)
	end	

end

function setColorRGB(RGBTarget,lul_device)
	--lifx_ctrl(selector, mode, color, bright, cycles, period)
	target = 'rgb:'..RGBTarget
	local sel = luup.variable_get(SID, "LightId", lul_device)
	log("SetColorRGB: " ..target)
	lifx_ctrl(sel, 'color', target, nil, nil, nil)
end

--TODO update color
function updateStats()
	log("Updating stats")
	
	--update the debug level periodically.
	local dlevel = luup.variable_get(SID, "DEBUG", luup.device) or "0"
	local id = "INVALID"
	dlevel = tonumber(dlevel)
	DEBUG = dlevel	
	
	--set status update times
	local update = luup.variable_get(SID, "DELAY", luup.device) or "60"
	update = tonumber(update)
	DELAY = update
	
	status_data = lifx_ctrl('all', 'list', nil, nil, nil, nil);
	
	--handle error
	if(status_data == nil) then
		log("Stats Failure")
	end
	
	brightness_tab = {}
	power_tab = {}
	
	for status_key, status_value in pairs(status_data) do
	    cstat = 0
		for key, value in pairs(status_value) do
			if type(value) == "string" or type(value) == "number" then 
				log("Lifx Key:"..key.." Value:"..value,2)
			end
			if key == "power" then
				power = value
				cstat = cstat + 1
			elseif key == "connected" then
				connected = value
			elseif key == "status" then
				stat = value
			elseif key == "brightness" then
				bright = value
				cstat = cstat + 1
			elseif key == "id" then
				id = "id:"..value
				cstat = cstat + 1
			elseif key == "error" then
				err = value
			end			
			if(cstat == 3) then
				cstat = 0;
				brightness_tab[id] = bright
				power_tab[id] = power
				log("Lifx Saving "..id..":"..power..":"..bright,2)
			end			
		end
	end
	
	for k, v in pairs(luup.devices) do
		if (v and v.device_type == BDID) then
			log("UpdateStats Dev#:"..k,1)
			id=luup.variable_get(SID, "LightId", k)			
			bright = brightness_tab[id]
			power  = power_tab[id]			
			if(bright == nil or power == nil) then
				log("Stats Failure")
				bright = 0
				power = "Failure"
			end			
			log('Power:'..power..' Bright:'..bright,2)
			loadLevel = tonumber(bright)
			loadLevel = loadLevel * 100
			if (power == "on") then
				luup.variable_set(SWITCH_SID, "Status", 1, k)
				luup.variable_set(DIMMER_SID,"LoadLevelStatus", loadLevel, k)
			else
				luup.variable_set(SWITCH_SID, "Status", 0, k)
				luup.variable_set(DIMMER_SID,"LoadLevelStatus", 0, k)
				luup.variable_set(DIMMER_SID,"LoadLevelTarget", loadLevel, k)
			end
		end
	end
	--call it again after a while
	math.randomseed(os.time())
	variance  =  math.random(1,25)
	log("Stats Variance:"..variance,2)
	luup.call_delay("updateStats",DELAY+variance)
end

function setChildData(count,data)
	luup.variable_set(SID, "ChildCount", count, Device)
	luup.variable_set(SID, "ChildData", data, Device)
end

local function createChildDevices()
	local childCount = luup.variable_get(SID, "ChildCount", Device)
	local childData = luup.variable_get(SID, "ChildData", Device)
	if (childCount == nil) then
		luup.variable_set(SID, "ChildCount", "0", Device)
		childCount = 0		
	else
		childCount = tonumber(childCount)
	end
	
	if (childCount == 0) then
		log("ChildCount 0 -> Return", 2)
		luup.variable_set(SID, "ChildData", "", Device)
		return
	end
	
	log("Creating up to " .. childCount .. " children", 2)	
	log("ChildData " .. childData, 2)
	local children = g_appendPtr
	local cnt = 0
	local childId = ""
	local childApiKey = ""
	local childType = ""
	local childName = ""
	local ApiKey = luup.variable_get(SID,"ApiKey", Device)
	for i in string.gmatch(childData, "[^,]*") do
	    local size = string.len(i)
		log(size.." MatchState "..i,2)		
		if (cnt == 2 and size>0) then			
			childType = i
			if (childId and childId ~= "") then
				local childParameters = ""
				childParameters = childParameters .. SID .. ",LightId=" .. childId
				childParameters = childParameters .."\n" ..SID .. ",ApiKey=" .. ApiKey
				local childDeviceFile = TypeDeviceFileMap[childType]
				if (childType == "scene") then
					childParameters = childParameters .."\n" ..SID .. ",SceneDelay=0"
				end
				log("Creating child state#" ..cnt.. "Params:" .. childParameters,1)
				luup.chdev.append(Device, children, childId, childName, "", childDeviceFile, "I_MajimusLifx.xml", childParameters, false)
			end
			cnt = 0
		elseif (cnt == 1 and size>0) then
			cnt = cnt + 1
			childName = i
			log("Creating child state#" ..cnt.."Name "..childName,2)
		elseif(size>0) then 
			childId = i
			log("Creating child state#" ..cnt.."Id "..childId,2)
			cnt = cnt + 1
		end
	end
	--we have added all the children so reset the child info
	--setChildData("0","")
end	

function startParent(lul_device)
	log("Parent Starting!:"..lul_device)
	
	--make some children
	g_appendPtr = luup.chdev.start(lul_device)
	createChildDevices()
	luup.chdev.sync(Device, g_appendPtr)
	
    --run the updater
	if (STATS_RUNNING == false) then
		STATS_RUNNING = true
		luup.call_delay("updateStats",5)
	else
		log("Stats already started!")
	end	
end

function startChild(lul_device)
	log("child Starting!:"..lul_device)
end

function bootStrap(lul_device)
	--have one implementation file and start parent of child from here
	if(luup.devices[lul_device].device_type == PDID) then
		--set debug levels
		local dlevel = luup.variable_get(SID, "DEBUG", lul_device) or "0"
		dlevel = tonumber(dlevel)
		DEBUG = dlevel
		if( dlevel == 0) then
			luup.variable_set(SID, "DEBUG", dlevel,lul_device)
		end
		
		--set status update times
		local update = luup.variable_get(SID, "DELAY", lul_device) or "180"
		update = tonumber(update)
		DELAY = update
		if(update == 180) then
			luup.variable_set(SID, "DELAY", update,lul_device)
		end
		
		startParent(lul_device)
	else
		--startChild(lul_device)
		log("Child Device Startup")
	end
end