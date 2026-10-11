--!nonstrict

function update()
	barWidget.setGlyph("language")
	barWidget.setText("")
	barWidget.setTooltip("Translate")
end

function onClick()
	noctalia.togglePanel("ildus/translate:panel")
end
