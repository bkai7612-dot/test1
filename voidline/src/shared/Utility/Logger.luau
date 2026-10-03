--!strict
--[[
	Logger
	Tagged, level-filtered logging for client and server.

	    local log = Logger.new("PlayerManager")
	    log:Info("Session created for", player.Name)

	Output format: [VOIDLINE][S][PlayerManager] Session created for Builderman
	(S = server, C = client). Debug/Info use print, Warn/Error use warn.
	Error does NOT throw; call error() yourself if execution must stop.

	Sinks let other systems (analytics, admin console) observe log lines
	without coupling to every caller.
]]

local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Config)

export type Level = "Debug" | "Info" | "Warn" | "Error"
export type Sink = (level: Level, tag: string, message: string) -> ()

local LEVEL_ORDER: { [string]: number } = {
	Debug = 1,
	Info = 2,
	Warn = 3,
	Error = 4,
}

local CONTEXT = if RunService:IsServer() then "S" else "C"

local minLevel: number = LEVEL_ORDER[(
	if RunService:IsStudio() then Config.Logging.StudioMinLevel else Config.Logging.MinLevel
) :: Level] or LEVEL_ORDER.Info

local sinks: { Sink } = {}

local Logger = {}
Logger.__index = Logger

export type Logger = typeof(setmetatable({} :: { Tag: string }, Logger))

local function formatArgs(...: any): string
	local parts = table.create(select("#", ...))
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	return table.concat(parts, " ")
end

local function emit(level: Level, tag: string, ...: any)
	if LEVEL_ORDER[level] < minLevel then
		return
	end
	local message = formatArgs(...)
	local line = string.format("[%s][%s][%s] %s", Config.Game.Title, CONTEXT, tag, message)
	if level == "Warn" or level == "Error" then
		warn(line)
	else
		print(line)
	end
	for _, sink in sinks do
		-- A faulty sink must never break the caller.
		local ok: boolean, err: any = pcall(sink, level, tag, message)
		if not ok then
			warn("[Logger] sink failed:", err)
		end
	end
end

function Logger.new(tag: string): Logger
	return setmetatable({ Tag = tag }, Logger)
end

function Logger.setMinLevel(level: Level)
	minLevel = LEVEL_ORDER[level]
end

-- Registers a sink; returns a function that removes it.
function Logger.addSink(sink: Sink): () -> ()
	table.insert(sinks, sink)
	return function()
		local index = table.find(sinks, sink)
		if index then
			table.remove(sinks, index)
		end
	end
end

function Logger.Debug(self: Logger, ...: any)
	emit("Debug", self.Tag, ...)
end

function Logger.Info(self: Logger, ...: any)
	emit("Info", self.Tag, ...)
end

function Logger.Warn(self: Logger, ...: any)
	emit("Warn", self.Tag, ...)
end

function Logger.Error(self: Logger, ...: any)
	emit("Error", self.Tag, ...)
end

return Logger
