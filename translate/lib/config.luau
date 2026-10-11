local M = {}

M.LANGUAGES = {
	{ id = "de", label = "Deutsch" },
	{ id = "ru", label = "Русский" },
	{ id = "en", label = "English" },
	{ id = "fr", label = "Français" },
	{ id = "es", label = "Español" },
	{ id = "uk", label = "Українська" },
	{ id = "pl", label = "Polski" },
	{ id = "zh", label = "中文" },
}

local function setting(key, fallback)
	local value = noctalia.getConfig(key)
	if type(value) ~= "string" or value == "" then
		return fallback
	end
	return noctalia.string.trim(value)
end

local function knownLanguage(id)
	for _, item in ipairs(M.LANGUAGES) do
		if item.id == id then
			return true
		end
	end
	return false
end

function M.path()
	local dir = noctalia.pluginDataDir()
	if type(dir) ~= "string" or dir == "" then
		return nil
	end
	return dir .. "/config.json"
end

function M.blank()
	return {
		baseUrl = setting("base_url", ""),
		apiKey = setting("api_key", ""),
		model = setting("model", "google/gemma-4-12B-it-qat-q4_0-gguf"),
		models = {},
		source = "de",
		target = "ru",
	}
end

function M.load()
	local cfg = M.blank()
	local path = M.path()
	if not path then
		return cfg
	end
	local raw = noctalia.readFile(path)
	if type(raw) ~= "string" or raw == "" then
		return cfg
	end
	local saved = noctalia.json.decode(raw)
	if type(saved) ~= "table" then
		return cfg
	end
	local savedUrl = saved.baseUrl or saved.base_url
	local savedKey = saved.apiKey or saved.api_key
	if type(savedUrl) == "string" and savedUrl ~= "" then
		cfg.baseUrl = savedUrl
	end
	if type(savedKey) == "string" then
		cfg.apiKey = savedKey
	end
	if type(saved.model) == "string" and saved.model ~= "" then
		cfg.model = saved.model
	end
	if type(saved.models) == "table" then
		cfg.models = {}
		for _, name in ipairs(saved.models) do
			if type(name) == "string" and name ~= "" then
				table.insert(cfg.models, name)
			end
		end
	end
	if knownLanguage(saved.source) then
		cfg.source = saved.source
	end
	if knownLanguage(saved.target) then
		cfg.target = saved.target
	end
	return cfg
end

function M.save(cfg)
	local path = M.path()
	if not path then
		return
	end
	local encoded = noctalia.json.encode(cfg)
	if encoded then
		noctalia.writeFile(path, encoded)
	end
	noctalia.state.set("config", cfg)
end

function M.labels()
	local labels = {}
	for _, item in ipairs(M.LANGUAGES) do
		table.insert(labels, item.label)
	end
	return labels
end

function M.indexOf(id)
	for i, item in ipairs(M.LANGUAGES) do
		if item.id == id then
			return i - 1
		end
	end
	return 0
end

function M.languageAt(index)
	return M.LANGUAGES[(tonumber(index) or 0) + 1]
end

local function scriptOf(id)
	if id == "ru" or id == "uk" then
		return "cyrillic"
	end
	if id == "zh" then
		return "han"
	end
	return "latin"
end

local function textScript(text)
	local cyrillic, han, latin = 0, 0, 0
	for _, code in utf8.codes(text) do
		if code >= 0x0400 and code <= 0x04FF then
			cyrillic += 1
		elseif code >= 0x4E00 and code <= 0x9FFF then
			han += 1
		elseif (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 0x00C0 and code <= 0x024F) then
			latin += 1
		end
	end
	if cyrillic > han and cyrillic > latin then
		return "cyrillic"
	end
	if han > cyrillic and han > latin then
		return "han"
	end
	if latin > cyrillic and latin > han then
		return "latin"
	end
	return nil
end

function M.instruction(leftId, rightId, text)
	local leftName = M.prompt(leftId)
	local rightName = M.prompt(rightId)
	local seen = textScript(text)
	local leftScript = scriptOf(leftId)
	local rightScript = scriptOf(rightId)
	local fromId, toId
	if seen == leftScript and seen ~= rightScript then
		fromId, toId = leftId, rightId
	elseif seen == rightScript and seen ~= leftScript then
		fromId, toId = rightId, leftId
	end
	if fromId then
		return "Translate the user message from "
			.. M.prompt(fromId)
			.. " into "
			.. M.prompt(toId)
			.. ". Reply with the translation only."
	end
	return "The user message is written in either "
		.. leftName
		.. " or "
		.. rightName
		.. ". Translate it into the other of those two languages. Reply with the translation only."
end

function M.prompt(id)
	for _, item in ipairs(M.LANGUAGES) do
		if item.id == id then
			if id == "de" then
				return "German"
			elseif id == "ru" then
				return "Russian"
			elseif id == "en" then
				return "English"
			elseif id == "fr" then
				return "French"
			elseif id == "es" then
				return "Spanish"
			elseif id == "uk" then
				return "Ukrainian"
			elseif id == "pl" then
				return "Polish"
			elseif id == "zh" then
				return "Chinese"
			end
			return item.label
		end
	end
	return "Russian"
end

function M.parseModels(body)
	local decoded = noctalia.json.decode(body)
	local list, seen = {}, {}
	local function add(name)
		if type(name) ~= "string" or name == "" or seen[name] then
			return
		end
		seen[name] = true
		table.insert(list, name)
	end
	if type(decoded) ~= "table" then
		return list
	end
	if type(decoded.data) == "table" then
		for _, item in ipairs(decoded.data) do
			if type(item) == "table" then
				add(item.id)
			end
		end
	end
	if type(decoded.models) == "table" then
		for _, item in ipairs(decoded.models) do
			if type(item) == "string" then
				add(item)
			elseif type(item) == "table" then
				add(item.id or item.name or item.model)
			end
		end
	end
	return list
end

return M
