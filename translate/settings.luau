--!nonstrict

local config = require("./lib/config.luau")

local open = false
local cfg = config.load()
local modelStatus = ""
local loadingModels = false
local render

local function apply(nextCfg)
	if type(nextCfg) == "table" then
		cfg = nextCfg
	end
end

noctalia.state.watch("config", function(value)
	apply(value)
	if open and render then
		render()
	end
end)

local function modelOptions()
	if type(cfg.models) == "table" and #cfg.models > 0 then
		return cfg.models
	end
	if type(cfg.model) == "string" and cfg.model ~= "" then
		return { cfg.model }
	end
	return { "No models" }
end

local function selectedModelIndex()
	local options = modelOptions()
	for i, name in ipairs(options) do
		if name == cfg.model then
			return i - 1
		end
	end
	return 0
end

render = function()
	panel.render(ui.column({ flexGrow = 1, gap = 12, align = "stretch" }, {
		ui.row({ align = "center", justify = "space_between", gap = 8 }, {
			ui.label({ text = "Translate settings", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
			ui.button({ glyph = "close", variant = "ghost", onClick = "onCloseClicked" }),
		}),
		ui.input({
			key = "base-url",
			value = cfg.baseUrl,
			placeholder = "https://api.example.com",
			onChange = "onBaseUrl",
		}),
		ui.input({
			key = "api-key",
			value = cfg.apiKey,
			placeholder = "API key",
			password = true,
			onChange = "onApiKey",
		}),
		ui.row({ gap = 8, align = "center" }, {
			ui.button({
				text = "Models",
				glyph = "refresh",
				enabled = not loadingModels,
				onClick = "onLoadModels",
			}),
			ui.label({ text = modelStatus, color = "on_surface_variant", flexGrow = 1, maxLines = 2 }),
		}),
		ui.select({
			options = modelOptions(),
			selectedIndex = selectedModelIndex(),
			onChange = "onModel",
		}),
	}))
end

function onOpen()
	open = true
	apply(config.load())
	loadingModels = false
	render()
end

function onClose()
	open = false
end

function onBaseUrl(text)
	if not open then
		return
	end
	cfg.baseUrl = text
	config.save(cfg)
end

function onApiKey(text)
	if not open then
		return
	end
	cfg.apiKey = text
	config.save(cfg)
end

function onLoadModels()
	loadingModels = true
	modelStatus = "Loading…"
	render()
	local base = (cfg.baseUrl or ""):gsub("/+$", "")
	local started = noctalia.http({
		url = base .. "/v1/models",
		headers = { "Authorization: Bearer " .. (cfg.apiKey or "") },
	}, function(res)
		loadingModels = false
		if not open then
			return
		end
		if not res.ok or res.status == 0 then
			modelStatus = "Connection error"
			render()
			return
		end
		if res.status >= 400 then
			modelStatus = string.format("HTTP %d", res.status)
			render()
			return
		end
		local fetched = config.parseModels(res.body)
		if #fetched == 0 then
			modelStatus = "No models"
			render()
			return
		end
		cfg.models = fetched
		local known = false
		for _, name in ipairs(cfg.models) do
			if name == cfg.model then
				known = true
				break
			end
		end
		if not known then
			cfg.model = cfg.models[1]
		end
		modelStatus = string.format("%d", #cfg.models)
		config.save(cfg)
		render()
	end)
	if not started then
		loadingModels = false
		modelStatus = "Request was not started"
		render()
	end
end

function onModel(index)
	if type(cfg.models) ~= "table" or #cfg.models == 0 then
		return
	end
	local picked = cfg.models[(tonumber(index) or 0) + 1]
	if type(picked) ~= "string" or picked == cfg.model then
		return
	end
	cfg.model = picked
	config.save(cfg)
	render()
end

function onCloseClicked()
	panel.close()
end
