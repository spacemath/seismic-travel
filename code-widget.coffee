codeWidget = ->
	code = $ "#computation-code"
	code.hide()
	delay = 1000
	$("#computation-toggle").click ->
		if code.is(":visible")
			code.hide delay
		else
			code.show 0, ->
				$("html, body").animate({scrollTop: $(document).height()}, delay)
		false

codeWidget()