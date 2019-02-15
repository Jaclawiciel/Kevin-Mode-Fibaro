--
-- Fibaro - Eric Hania
-- Kevin Mode - Virtual Device - Main Loop
-- Date: 10/02/2019
-- Time: 10:02
--
-- Created by: Jacek Gałka | http://jacekgalka.pl/en
--
-- ************ BEGIN configuration block ************
DEBUG_STATE_GLOBAL_VAR_NAME = "isDebugMode"
KEVIN_MODE_STAT_VAR_NAME = "isKevinMode"
KEVNIE_MODE_STATE_LABEL = "kevinModeStateLabel"
LIVE_LEARN_STATE_VAR_NAME = "isKevinLiveLearnOn"
KEVIN_LIVE_LEARN_LABEL = "kevinLiveLearnStateLabel"
VD_ID = fibaro:getSelfId()
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

function setIcon(deviceId, iconId)
	fibaro:call(deviceId, "setProperty", "currentIcon", iconId)
end

function setLabel(deviceId, labelName, labelText)
	fibaro:call(deviceId, "setProperty", "ui."..labelName..".value", labelText)
end
-- ************ END helper functions ************

-- ************ BEGIN creating objects************
local logger = Logger:new(DEBUG_STATE_GLOBAL_VAR_NAME)
local isKevinMode = GlobalVariable:new(KEVIN_MODE_STAT_VAR_NAME)
local isKevinLiveLearnOn = GlobalVariable:new(LIVE_LEARN_STATE_VAR_NAME)
-- ************ END creating objects************

-- ************ BEGIN code block ************
logger:log("info", "", "debug")
logger:log("info", "START script", "debug")

if isKevinMode:getValue() then
	logger:log("action", "Setting Kevin Mode label - ON", "debug")
	setLabel(VD_ID, KEVNIE_MODE_STATE_LABEL, "ON ✅")
else
	logger:log("action", "Setting Kevin Mode label - OFF", "debug")
	setLabel(VD_ID, KEVNIE_MODE_STATE_LABEL, "OFF ❌")
end

if isKevinLiveLearnOn:getValue() then
	logger:log("action", "Setting Kevin Live Learn label - ON", "debug")
	setLabel(VD_ID, KEVIN_LIVE_LEARN_LABEL, "ON ✅")
else
	logger:log("action", "Setting Kevin Live Learn label - OFF", "debug")
	setLabel(VD_ID, KEVIN_LIVE_LEARN_LABEL, "OFF ❌")
end

logger:log("info", "END script", "debug")
-- ************ END code block ************