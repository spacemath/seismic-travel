# TODO
# Info about 8km vertical distance.
# Superscript for m3
# Use svg group (g) for rock regions

# Math functions
round = Math.round
round1 = (x) -> round(10*x)/10

# Class definitions

class Canvas
	
	constructor: (@spec) ->
		
		{@containerSelector, @width, @height, @margin, @xDomain, @yDomain} = @spec
		
		@graphics = d3.select @containerSelector
		
		@graphics.selectAll("svg").remove()
		
		@svg = @graphics.append("svg")
			.attr('width', @width)
			.attr('height', @height)
			
		@w = @width - @margin.left - @margin.right
	
		@h = @height - @margin.top - @margin.bottom
			
		@canvas = @svg.append("g")
			.attr("transform", "translate(#{@margin.left}, #{@margin.top})")
			.attr("width", @w)
			.attr("height", @h)
		
		@mx = d3.scale.linear()
			.domain(@xDomain)
			.range([0, @w]) 
		
		@my = d3.scale.linear()
			.domain(@yDomain)
			.range([0, @h])
		
		$("#graphics-preloader").remove()
		
	invertX: (x) -> @limit @mx.invert(x), @xDomain
	
	invertY: (y) -> @limit @my.invert(y), @yDomain
		
	limit: (z, d) ->
		return d[1] if z>d[1]
		return d[0] if z<d[0]
		z
		
	append: (obj) -> @canvas.append(obj)


class Rock
	
	containerSelector: "#graphics"
	width: 850
	height: 300
	margin: {top: 30, right: 30, bottom: 50, left: 25}
	buffer: 30
	
	constructor: (@spec) ->
		
		{@widths, @thickness, @densities, @densityRange, @colorMap, @model} = @spec
		
		@xDomain = [0, @totalWidth()]
		@yDomain = [0, @thickness]
		
		@canvas = new Canvas
			containerSelector: @containerSelector
			width: @width
			height: @height
			margin: @margin
			xDomain: @xDomain
			yDomain: @yDomain
		
		setBoundary = (idx, x) => @setBoundary(idx, x)
		
		@regions =
			for density in @densities
				new RockRegion
					canvas: @canvas
					model: @model
					density: density
					densityRange: @densityRange
					colorMap: @colorMap
					callback: => @setTotalTime()
		
		@boundaries = (new RockBoundary(canvas: @canvas, idx: idx, callback: setBoundary) for region, idx in @regions[0..-2])
		
		@endLabel 0
		@endLabel @totalWidth()
		
		@draw()
		
	setBoundary: (idx, x) ->
		c = @cumulativeWidths()
		xMin = if idx>0 then c[idx-1] else 0
		xMax = c[idx+1]
		@widths[idx..idx+1] = [x-xMin, xMax-x] if x>xMin+@buffer and x<xMax-@buffer
		@draw()
		
	endLabel: (x) ->
		y = @canvas.yDomain[1]
		d = new Text(canvas: @canvas, y: y, dy: "1.2em")
		d.set(x, round(x)+ " km")
		
	draw: ->
		c = @cumulativeWidths()
		xr = (idx) -> if idx>0 then c[idx-1] else 0
		region.set(xr(idx), @widths[idx]) for region, idx in @regions
		boundary.set(c[idx]) for boundary, idx in @boundaries
		@setTotalTime()
		
	cumulativeWidths: ->
		w = 0
		(w += width for width in @widths)
		
	totalWidth: -> @cumulativeWidths()[-1..][0]
	
	setTotalTime: ->
		t = 0
		t += region.time for region in @regions if @regions
		$("#total-time").text round(t)+" seconds"


class Rectangle
	
	constructor: (@spec) ->
		
		{@canvas, @x, @w} = @spec
		@x = 1 unless @x
		@w = 1 unless @w
		
		@mx = @canvas.mx
		@my  = @canvas.my
		
		@rect = @canvas.append("rect")
			.attr("y", @my(0))
			.attr("height", @my(@canvas.yDomain[1]))
			.attr("class", "unselectable")
			
		@set @x, @w
	
	set: (@x, @w) ->
		@rect.attr "x", @mx(@x)
		@rect.attr "width", @mx(@w) if @w


class RockRegion extends Rectangle
	
	constructor: (@spec) ->
		{@canvas, @model, @density, @densityRange, @colorMap, @callback} = @spec
		super @spec
		@content = new RockRegionContent {@canvas}
		@setDensity @spec.density
		new VSlider(rect: @rect, callback: (y) => @yToDensity(y))
	
	set: (x=@x, w=@w) ->
		super x, w
		@speed = @model.speed(@density)
		@time = @model.time(@w, @speed)
		@content?.set {@x, @w, @density, @speed, @time}
		@callback()
		
	yToDensity: (y) ->
		[dMin, dMax] = @densityRange
		b = 200  # Buffer
		y1 = @canvas.invertY(y)/@canvas.yDomain[1]
		density = 10*round((dMax-dMin+2*b)/10*(1-y1)) + dMin - b
		density = dMin if density<dMin
		density = dMax if density>dMax
		@setDensity density
		
	setDensity: (@density) ->
		@rect.attr "fill", @colorMap(@density)
		@set()


class RockRegionContent
	
	constructor: (@spec) ->
		
		{@canvas} = @spec
		
		@text =
			density: @t 2
			dUnit: @t 2, 1
			width: @t 4
			speed: @t 5
			time: @t 6
	
	set: (@vals) ->
		{@x, @w, @density, @speed, @time} = @vals
		@center = @x + @w/2
		@s "density", round(@density)
		@s "dUnit", "kg/m3"  
		@s "width", round(@w)+" km"
		@s "speed", round1(@speed)+" km/s"
		@s "time", round1(@time)+" s"
		
	t: (y, dy=0) -> new RockRegionText(canvas: @canvas, y: y, dy: "#{dy}em")
	
	s: (f, v) -> @text[f].set @center, v


class VSlider
	
	constructor: (@spec) ->
		
		{@rect, @callback} = @spec
		
		@setAdjust false
		
		@rect.on "mousedown", => @setAdjust true
		
		@rect.on "mouseup", => @setAdjust false
		
		@rect.on "mousemove", => (@set() if @adjust)
		
		@rect.on "mouseleave", => @setAdjust false
		# tag = d3.event.toElement.tagName - check if tag is text - now handle via CSS pointer-events
		
		@rect.append("svg:title").text("To adjust density, click and move up/down.")
		
	setAdjust: (@adjust) ->
		@rect.attr "class", (if @adjust then "rock-region-adjust-density unselectable" else "rock-region unselectable")
		@set() if @adjust
		
	set: =>
		coord = d3.mouse(@rect[0][0])
		@callback coord[1]


class RockBoundary extends Rectangle
	
	width: 20
	
	constructor: (@spec) ->
		@spec.w = @width
		super @spec
		@rect.attr "class", "rock-boundary"
		canvas = @spec.canvas
		y =  canvas.yDomain[1]
		@distance = new Text(canvas: canvas, y: y, dy: "1.2em")
		@setDraggable()
		
	set: (x, w) ->
		# w not used - fixed boundary width
		@w = @canvas.invertX(@width/2)
		super (x-@w/2), @w
		@distance?.set(x, Math.round(x)+" km")
		
	setDraggable: ->
		@rect.call(
			d3.behavior
			.drag()
			.on("drag", => @spec.callback(@spec.idx, @canvas.invertX(d3.event.x)))
		)
		


class Text
	
	textClass: "rock-text"
	
	constructor: (@spec) ->
		
		{@canvas} = @spec
		@mx = @canvas.mx
		@my = @canvas.my
		
		@text = @canvas.append("text")
			.attr("y", @my(@spec.y))
			.attr("class", @textClass)
		
		@text.attr("dy", @spec.dy) if @spec.dy
		
	set: (@x, @t) ->
		@text.attr("x", @mx(@x))
		@text.text(@t)
		
	setText: (@t) ->
		@text.text(@t)


class RockRegionText extends Text
	
	textClass: "rock-region-text unselectable"


# Export rock simulation
$blab.rock = (spec) -> new Rock spec
