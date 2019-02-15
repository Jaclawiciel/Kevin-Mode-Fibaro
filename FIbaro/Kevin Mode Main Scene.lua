--[[
%% properties
%% events
%% globals
isKevinMode
%% autostart
--]]

--
-- Fibaro - Eric Hania
-- Kevin Mode - Scene - Main Scene
-- Date: 10/02/2019
-- Time: 10:02
--
-- Created by: Jacek Gałka | http://jacekgalka.pl/en
--
-- ************ BEGIN configuration block ************
DEBUG_STATE_GLOBAL_VAR_NAME = "isDebugMode"
KEVIN_MODE_STAT_VAR_NAME = "isKevinMode"
KEVNIE_MODE_STATE_LABEL = "kevinModeStateLabel"
testMode = true
DIMMER_TYPE = "com.fibaro.FGD212"
SONOS_CONTROLLER_SCENE_ID = 100
SCENE_ID = 138

excludedLights = {34 }
VD_ID = 587
API_IP = fibaro:get(VD_ID, "IPAddress")
API_PORT = fibaro:get(VD_ID,"TCPPort")
DIM_LEVEL_SLIDER = "dimLevelSlider"

START_SIMULATION_TTS_MESSAGE = "From now on I'm starting to simulate your presence at home."
STOP_SIMULATION_TTS_MESSAGE = "I will not simulate your presence at home anymore. I will turn off all the lights."
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

function numberOfSceneInstances() -- returns number of instances running
	return fibaro:countScenes()
end

function abortSceneInstance()
	fibaro:abort()
end

function killAllSceneInstances()
	fibaro:killScenes(SCENE_ID)
end

function getActiveLights(excludedLights)
	local allDevices = api.get("/devices")
	local lightIds = {}
	for _, device in pairs(allDevices) do
		local isExcluded = false
		for _, excludedLightId in pairs(excludedLights) do
			if device.id == excludedLightId then
				isExcluded = true
			end
		end

		if not isExcluded and device.type == DIMMER_TYPE and device.visible then
			table.insert(lightIds, device.id)
		end
	end
	return lightIds
end

function getTableAsString(table)
	if type(table) == 'table' then
		local s = '{ '
		for k,v in pairs(table) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. getTableAsString(v) .. ','
		end
		return s .. '} '
	else
		return tostring(table)
	end
end

function getSlider(deviceId, sliderName)
	return tonumber(fibaro:getValue(deviceId, "ui."..sliderName..".value"))
end

function turnOnTheLight(lightId)
	local dimLevel = getSlider(VD_ID, DIM_LEVEL_SLIDER)
	logger:log("action", "Turning on "..lightId.." on "..dimLevel.."%", "debug")
	if not testMode then
		if not (tonumber(fibaro:getValue(lightId, "value")) == dimLevel) then
			fibaro:call(lightId, "setValue", dimLevel)
		end
	end
end

function turnOffTheLight(lightId)
	logger:log("action", "Turning off "..lightId, "debug")
	if not testMode then
		if not (tonumber(fibaro:getValue(lightId, "value")) == 0) then
			fibaro:call(lightId, "turnOff")
		end
	end
end

function tablelength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

function getRandomDelay(numberOfItems)
	local maxTimePerLoop = math.floor(50 / numberOfItems)
	math.randomseed(os.time())
	local delay = math.random(1, maxTimePerLoop) * 1000
	logger:log("info", "Delay: "..(delay / 1000).." seconds")
	return delay
end

function processResponse(response)
	local lights = json.decode(response)

	for lightId, value in pairs(lights) do
		local randomDelay = getRandomDelay(tablelength(lights))
		fibaro:sleep(randomDelay)
		if value == "ERROR" then
			logger:log("warning", "API reponded with error for "..lightId)
		elseif value == 0 then
			turnOffTheLight(lightId)
		elseif value == 1 then
			turnOnTheLight(lightId)
		else
			logger:log("warning", "API responded with unknown response: "..value)
		end
	end
	logger:log("debug", "Light simulation iteration END")
end

function sendRequest(lights)
	local shouldPrintResponse = true
	local request = "http://"..API_IP..":"..API_PORT.."/get_lights?lights="..table.concat(lights, ",")
	local http = net.HTTPClient()
	controlHeaders = {['content-type'] = 'application/json; charset=utf-8'}
	http:request(request, {
		options = { method = 'GET', headers = controlHeaders, timeout = 5000 },
		success = function(status)
			logger:log("success", "Request sent to API", "debug")
			if shouldPrintResponse then
				logger:log("debug", getTableAsString(status), "debug")
			end
--			TODO: UNCOMMENT
			--processResponse(status)
		end,
		error = function(err)
			logger:log("error", err)
		end
	})
end

function simulateLightsLoop()
	logger:log("debug", "Light simulation iteration START")
	local activeLights = getActiveLights(excludedLights)
	sendRequest(activeLights)

	setTimeout(simulateLightsLoop, 60*1000)
end

function playTTS(message)
--	TODO: UNCOMMENT
--	fibaro:startScene(SONOS_CONTROLLER_SCENE_ID, {"play", "tts", message, 40, "en"})
end
-- ************ END helper functions ************

-- ************ BEGIN creating objects************
local isKevinMode = GlobalVariable:new(KEVIN_MODE_STAT_VAR_NAME),
-- ************ END creating objects************

-- ************ BEGIN code block ************
logger:log("info", "", "debug")
logger:log("info", "START script", "debug")

local trigger = fibaro:getSourceTrigger()
local triggerType = trigger["type"]
local triggerDeviceId = trigger["deviceID"]
local triggerProperty = trigger["propertyName"]
local triggerVarName = trigger["varName"]

if isKevinMode:getValue() then
	if triggerType == "global" then
		logger:log('info', "Pressence simulation turned ON by user action")
		if not testMode then
			logger:log("action", "Notifying user through Sonos about turning ON the Presence Simulation")
			playTTS(START_SIMULATION_TTS_MESSAGE)
		end
	elseif triggerType == "autostart" then
		logger:log('info', "Pressence simulation is ON after autostart")
	end

	local activeLights = getActiveLights(excludedLights)
	logger:log("info", "Active lights: "..table.concat(activeLights, ", "), "debug")

	logger:log("action", "Starting light simulation loop...")
	simulateLightsLoop()
else
	if triggerType == "global" then
		if not testMode then
			logger:log("action", "Notifying user through Sonos about turning OFF the Presence Simulation")
			playTTS(STOP_SIMULATION_TTS_MESSAGE)
			for _, activeLight in pairs(getActiveLights(excludedLights)) do
				turnOffTheLight(activeLight)
			end
		end
		killAllSceneInstances()
	elseif triggerType == "autostart" then
		logger:log('info', "Pressence simulation is OFF after autostart", "debug")
	end
end

logger:log("info", "END script", "debug")
-- ************ END code block ************