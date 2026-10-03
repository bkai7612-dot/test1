-- Test prelude: fake Roblox globals and a module registry keyed by path.
local sources: { [string]: string } = {}
local cache: { [string]: any } = {}
local nodes: { [string]: any } = {}

local NodeMeta = {}
NodeMeta.__index = function(node, key)
	local childPath = if node.__path == "" then key else node.__path .. "/" .. key
	local child = nodes[childPath]
	if child then
		return child
	end
	error("No module or folder at " .. childPath, 2)
end

local function getNode(path: string): any
	local existing = nodes[path]
	if existing then
		return existing
	end
	local name = string.match(path, "([^/]+)$") or path
	local parentPath = string.match(path, "^(.*)/[^/]+$") or ""
	local node = setmetatable({ __path = path, Name = name }, NodeMeta)
	nodes[path] = node
	if path ~= "" then
		rawset(node, "Parent", getNode(parentPath))
	end
	return node
end

local root = getNode("")

-- Roblox-like shims (the CLI's _G is read-only, so they live in a lookup table).
local shims: { [string]: any } = {}
shims.game = { GetService = function() return { IsStudio = function() return false end, IsServer = function() return true end } end }
shims.Random = {
	new = function(seed: number?)
		if seed then
			math.randomseed(seed)
		end
		return {
			NextInteger = function(_, a, b) return math.random(a, b) end,
			NextNumber = function(_, a, b)
				a = a or 0
				b = b or 1
				return a + math.random() * (b - a)
			end,
		}
	end,
}

local function requireNode(node: any): any
	local path = rawget(node, "__path")
	if cache[path] ~= nil then
		return cache[path]
	end
	local source = sources[path]
	assert(source, "No module source for " .. tostring(path))
	local chunk, err = loadstring(source, "=" .. path)
	assert(chunk, err)
	local env = setmetatable({ script = node, require = requireNode }, { __index = function(_, k) local v = shims[k] if v ~= nil then return v end return _G[k] end })
	setfenv(chunk, env)
	local result = chunk()
	cache[path] = result
	return result
end

function __registerModule(path: string, source: string)
	sources[path] = source
	getNode(path)
end

local passed, failed = 0, 0
local failures = {}

function __runSpec(name: string, source: string)
	local chunk, err = loadstring(source, "=" .. name)
	assert(chunk, err)
	local tests = {}
	local env = setmetatable({
		Shared = root,
		require = requireNode,
		test = function(title: string, fn: () -> ())
			table.insert(tests, { title = title, fn = fn })
		end,
	}, { __index = function(_, k) local v = shims[k] if v ~= nil then return v end return _G[k] end })
	setfenv(chunk, env)
	chunk()
	for _, t in tests do
		local ok, e = pcall(t.fn)
		if ok then
			passed += 1
		else
			failed += 1
			table.insert(failures, name .. " :: " .. t.title .. "\n    " .. tostring(e))
		end
	end
end

function __finish()
	for _, f in failures do
		print("FAIL " .. f)
	end
	print(string.format("%d passed, %d failed", passed, failed))
	if failed > 0 then
		error("tests failed")
	end
end
