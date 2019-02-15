--[[
%% properties
221 value
%% events
%% globals
--]]

--
-- Fibaro - Eric Hania
-- Kevin Mode - Scene - Live learn reporting scene
-- Date: 10/02/2019
-- Time: 10:02
--
-- Created by: Jacek Gałka | http://jacekgalka.pl/en
--
-- ************ BEGIN configuration block ************
DEBUG_STATE_GLOBAL_VAR_NAME = "isDebugMode"
LIVE_LEARN_STATE_VAR_NAME = "isKevinLiveLearnOn"
testMode = true

VD_ID = 587
API_IP = fibaro:get(VD_ID, "IPAddress")
API_PORT = fibaro:get(VD_ID,"TCPPort")
-- ************ END configuration block ************

-- ************ BEGIN helper functions ************
GlobalVariable = {}
function GlobalVariable:new(globalVariableName)
	local this =
	{
		globalVariableName = globalVariableName,
		value = fibaro:getGlobalValue(globalVariableName)
	}

	function this:getValue()
		local value = self.value

		if value == "true" then
			self.value = true
		elseif value == "false" then
			self.value = false
		else
			self.value = value
		end

		return self.value
	end

	function this:getGlobalValue()
		local value = fibaro:getGlobalValue(self.globalVariableName)

		if value == "true" then
			self.value = true
		elseif value == "false" then
			self.value = false
		else
			self.value = value
		end

		return self.value
	end

	function this:setValue(value)
		self.value = value
	end

	function this:setGlobalValue(value)
		self.value = value
		fibaro:setGlobal(self.globalVariableName, value)
	end

	return this
end


Logger = {}
function Logger:new(debugStateGlobalVarName)

	--- Logger
	--
	-- Logging levels:
	-- error: FireBrick,
	-- warning: orange,
	-- action: Salmon,
	-- info: RoyalBlue,
	-- success: ForestGreen,
	-- debug: DarkGray
	---

	local this =
	{
		debugStateGlobalVarName = debugStateGlobalVarName,
		isInDebugMode = GlobalVariable:new(DEBUG_STATE_GLOBAL_VAR_NAME),
		loggingColors = {
			error = "FireBrick",
			warning = "orange",
			action = "Salmon",
			info = "RoyalBlue",
			success = "ForestGreen",
			debug = "DarkGray"
		}
	}

	function this:log(level, message, debugMode)
		local currentColor
		local currentLevel
		for loggerLevel, loggerColor in pairs(self.loggingColors) do
			if level == loggerLevel then
				currentColor = loggerColor
				currentLevel = loggerLevel
			end
		end
		if currentLevel == nil then
			currentLevel = "info"
			currentColor = self.loggingColors.info
		end

		if debugMode == "debug" then
			if self.isInDebugMode:getGlobalValue() then
				fibaro:debug(string.format('<%s style="color:%s;">[%s]: %s', "span", currentColor, string.upper(currentLevel), message, "span"))
			end
		else
			fibaro:debug(string.format('<%s style="color:%s;">[%s]: %s', "span", currentColor, string.upper(currentLevel), message, "span"))
		end
	end

	return this
end
local logger = Logger:new(DEBUG_STATE_GLOBAL_VAR_NAME)

function getDataToSend(timestamp, lightId, state)
	local data = {
		timestamp = timestamp,
		lightId = lightId,
		state = state
	}
	data = json.encode(data)
	logger:log("debug", "Data: "..data, "debug")
	return data
end

function feedKevin(data)
	local http = net.HTTPClient()
	controlHeaders = {['content-type'] = 'application/json; charset=utf-8'}
	http:request("http://"..API_IP..":"..API_PORT.."/add_new_sample", {
		options = { method = 'POST', headers = controlHeaders, data = data, timeout = 5000 },
		success = function(status)
			logger:log("success", "Request send")
			if status.status == 200 or status.status == 201 then
				logger:log("success", "Request send")
			else
				logger:log("error", "Request send but something went wrong :(")
			end
		end,
		error = function(err)
			logger:log("error", err)
		end
	})
end
-- ************ END helper functions ************

-- ************ BEGIN creating objects************
local isKevinLiveLearnModeOn = GlobalVariable:new(LIVE_LEARN_STATE_VAR_NAME)
-- ************ END creating objects************

-- ************ BEGIN code block ************
logger:log("info", "", "debug")
logger:log("info", "START script", "debug")

local trigger = fibaro:getSourceTrigger()
local triggerType = trigger["type"]
local triggerDeviceId = trigger["deviceID"]
local triggerProperty = trigger["propertyName"]
local triggerVarName = trigger["varName"]

logger:log("info", "Triggered by: "..triggerType, "debug")
if triggerType == "property" then logger:log("info", "Light: "..fibaro:getName(triggerDeviceId).." ("..triggerDeviceId..")", "debug") end

if isKevinLiveLearnModeOn:getValue() then
	local lightId = triggerDeviceId

	local timestamp = tostring(os.time())
	local lightState = tonumber(fibaro:getValue(lightId, "value"))
	if lightState > 0 then
		lightState = 1
	elseif not (lightState == 0) then
		logger:log("error", "Light state not recognized!")
	end

	logger:log("info", "Timestamp: "..timestamp, "debug")
	logger:log("info", "LightId: "..lightId, "debug")
	logger:log("info", "State: "..lightState, "debug")

	feedKevin(getDataToSend(timestamp, lightId, lightState))

else
	logger:log("info", "Kevin Live Learn is off", "debug")
end

logger:log("info", "END script", "debug")
-- ************ END code block ************