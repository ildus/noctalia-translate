--!nonstrict

local config = require("./lib/config.luau")

local open = false
local draft = ""
local committed = ""
local lastEdit = 0
local generation = 0
local busy = false
local translation = ""
local cfg = config.load()
local render

local function apply(nextCfg)
	if type(nextCfg) ~= "table" then
		return
	end
	cfg = nextCfg
end

noctalia.state.watch("config", function(value)
	apply(value)
	if open and render then
		render()
	end
end)

render = function()
	local result = if busy then "…" elseif translation ~= "" then translation else ""
	panel.render(ui.column({ flexGrow = 1, gap = 12, align = "stretch" }, {
		ui.row({ align = "center", justify = "space_between", gap = 8 }, {
			ui.label({ text = "Translate", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
			ui.button({ glyph = "settings", variant = "ghost", onClick = "onSettings" }),
			ui.button({ glyph = "copy", variant = "ghost", enabled = translation ~= "" and not busy, onClick = "onCopy" }),
			ui.button({ glyph = "close", variant = "ghost", onClick = "onCloseClicked" }),
		}),
		ui.row({ gap = 8, align = "center" }, {
			ui.select({
				key = "source-lang",
				options = config.labels(),
				selectedIndex = config.indexOf(cfg.source),
				onChange = "onSource",
				flexGrow = 1,
			}),
			ui.label({ text = "<->" }),
			ui.select({
				key = "target-lang",
				options = config.labels(),
				selectedIndex = config.indexOf(cfg.target),
				onChange = "onTarget",
				flexGrow = 1,
			}),
		}),
		ui.input({
			key = "source",
			placeholder = "zugeben или признавать",
			focus = true,
			onChange = "onDraft",
			onSubmit = "onSubmit",
		}),
		ui.label({
			text = result,
			color = "primary",
			maxLines = 8,
		}),
	}))
end

local function translate(text)
	if cfg.model == "" then
		translation = "Pick a model"
		render()
		return
	end

	generation += 1
	local ticket = generation
	local body, encodeErr = noctalia.json.encode({
		model = cfg.model,
		messages = {
			{
				role = "system",
				content = config.instruction(cfg.source, cfg.target, text),
			},
			{ role = "user", content = text },
		},
		chat_template_kwargs = { enable_thinking = false },
	})
	if not body then
		busy = false
		translation = encodeErr or "Could not encode the request"
		render()
		return
	end

	busy = true
	translation = ""
	render()

	local base = (cfg.baseUrl or ""):gsub("/+$", "")
	local started = noctalia.http({
		url = base .. "/v1/chat/completions",
		method = "POST",
		headers = {
			"Content-Type: application/json",
			"Authorization: Bearer " .. (cfg.apiKey or ""),
		},
		body = body,
	}, function(res)
		if ticket ~= generation or not open then
			return
		end
		busy = false
		if not res.ok or res.status == 0 then
			translation = "Connection error"
			render()
			return
		end
		if res.status >= 400 then
			local detail = noctalia.string.trim(res.body or "")
			if #detail > 180 then
				detail = string.sub(detail, 1, 180)
			end
			translation = if detail ~= ""
				then string.format("HTTP %d: %s", res.status, detail)
				else string.format("HTTP %d", res.status)
			render()
			return
		end
		local decoded = noctalia.json.decode(res.body)
		local message = decoded and decoded.choices and decoded.choices[1] and decoded.choices[1].message
		local content = message and message.content
		if type(content) ~= "string" or content == "" then
			translation = "Empty response"
		else
			translation = noctalia.string.trim(content)
		end
		render()
	end)

	if not started then
		busy = false
		translation = "Request was not started"
		render()
	end
end

local function consider()
	if not open or draft == committed then
		return
	end
	if os.clock() - lastEdit < 0.45 then
		return
	end
	committed = draft
	local text = noctalia.string.trim(draft)
	if text == "" then
		generation += 1
		busy = false
		translation = ""
		render()
		return
	end
	translate(text)
end

local function retranslate()
	committed = ""
	consider()
end

function update()
	noctalia.setUpdateInterval(200)
	consider()
end

function onOpen()
	open = true
	apply(config.load())
	draft = ""
	committed = ""
	lastEdit = 0
	generation += 1
	busy = false
	translation = ""
	render()
end

function onClose()
	open = false
	generation += 1
end

function onSource(index)
	local picked = config.languageAt(index)
	if not picked or picked.id == cfg.source then
		return
	end
	if picked.id == cfg.target then
		cfg.target = cfg.source
	end
	cfg.source = picked.id
	config.save(cfg)
	retranslate()
end

function onTarget(index)
	local picked = config.languageAt(index)
	if not picked or picked.id == cfg.target then
		return
	end
	if picked.id == cfg.source then
		cfg.source = cfg.target
	end
	cfg.target = picked.id
	config.save(cfg)
	retranslate()
end

function onDraft(text)
	draft = text
	lastEdit = os.clock()
end

function onSubmit(text)
	draft = text
	lastEdit = 0
	committed = ""
	consider()
end

function onCopy()
	if translation ~= "" and not busy then
		noctalia.copyToClipboard(translation, "text/plain")
	end
end

function onSettings()
	noctalia.togglePanel("ildus/translate:settings")
end

function onCloseClicked()
	panel.close()
end
