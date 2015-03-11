#TODO
# brown rock
# 0, 300 km
# info about 8k vert d


class Rock
	
	width: 850
	height: 300
	margin: {top: 30, right: 20, bottom: 30, left: 20}
	xDomain: [0, 300]
	yDomain: [0, 8]
	
	constructor: (@callback) ->
		@create()
		@callback this
		
	create: ->
		
		@graphics = d3.select "#graphics"
		
		@graphics.selectAll("svg").remove()
		@svg = @graphics.append("svg")
			.attr('width', @width)
			.attr('height', @height)
			
		@w = @width - @margin.left - @margin.right
	
		@h = @height - @margin.top - @margin.bottom
			
		@rock = @svg.append("g")
			.attr("transform", "translate(#{@margin.left}, #{@margin.top})")
			.attr("width", @w)
			.attr("height", @h)
		
		@mx = d3.scale.linear()
			.domain(@xDomain)
			.range([0, @w]) 
		
		@my = d3.scale.linear()
			.domain(@yDomain)
			.range([0, @h])
			
		new RockRegions rock: this
		
		$("#map-preloader").remove()
		
	invertX: (x) -> @limit @mx.invert(x), @xDomain
	
	invertY: (y) -> @limit @my.invert(y), @yDomain
		
	limit: (z, d) ->
		return d[1] if z>d[1]
		return d[0] if z<d[0]
		z
		
	append: (obj) -> @rock.append(obj)
	

class RockRegions
	
	buffer: 30
	
	constructor: (@spec) ->
		
		{@rock} = @spec
		
		@widths = [50, 90, 70, 90]
		@densities = [2250, 1700, 1200, 2600]
		#@fills = ["red", "#f66", "#faa", "#fcc"]
		setBoundary = (idx, x) => @setBoundary(idx, x)
		
		@regions = (new RockRegion(rock: @rock, density: density) for density in @densities)
		@boundaries = (new RockBoundary(rock: @rock, idx: idx, callback: setBoundary) for region, idx in @regions[0..-2])
		
		@draw()
		
	setBoundary: (idx, x) ->
		c = @cumulativeWidths()
		xMin = if idx>0 then c[idx-1] else 0
		xMax = c[idx+1]
		@widths[idx..idx+1] = [x-xMin, xMax-x] if x>xMin+@buffer and x<xMax-@buffer
		@draw()
		
	draw: ->
		c = @cumulativeWidths()
		xr = (idx) -> if idx>0 then c[idx-1] else 0
		region.set(xr(idx), @widths[idx]) for region, idx in @regions
		boundary.set(c[idx]) for boundary, idx in @boundaries
		
	cumulativeWidths: ->
		w = 0
		(w += width for width in @widths)


class RockRectangle
	
	constructor: (@spec) ->
		
		{@rock, @x, @w} = @spec
		@x = 1 unless @x
		@w = 1 unless @w
		
		@mx = @rock.mx
		@my  = @rock.my
		
		@rect = @rock.append("rect")
			.attr("y", @my(0))
			.attr("height", @my(@rock.yDomain[1]))
			.attr("class", "unselectable")
			
		@set @x, @w
	
	set: (@x, @w) ->
		@rect.attr "x", @mx(@x)
		@rect.attr "width", @mx(@w) if @w


class RockRegion extends RockRectangle
	
	# TODO: use group
	
	constructor: (@spec) ->
		super @spec
		
		rock = @spec.rock
		
		@rect.attr "class", "rock-region unselectable"
		
		@adjust = false
		@rect.on "mousedown", =>
			@adjust = true #not @adjust
			#if @adjust
			@rect.attr "class", "rock-region-adjust-density unselectable"
			#else
			#	@rect.attr "class", "rock-region unselectable"
			foo()
		@rect.on "mouseup", =>
			@adjust = false
			@rect.attr "class", "rock-region unselectable"
		@rect.on "mousemove", => foo()
		@rect.on "mouseleave", (evt) =>
			if @adjust
				@adjust = d3.event.toElement.tagName is "text"
				if not @adjust
					@rect.attr "class", "rock-region unselectable"
		
		@rect.append("svg:title").text("To adjust density, click and move up/down.")
			
		foo = =>
			return unless @adjust
			coord = d3.mouse(@rect[0][0])
			y = @rock.invertY(coord[1])/@rock.yDomain[1]
			density = 10*Math.round(290*(1-y)) + 1000
			density = 1200 if density<1200
			density = 3700 if density>3700
			@setDensity density
		
		
		@densityText = new RockRegionText(rock: rock, y: 1, dy: "0em") #, click: (-> cb()))
		
		@setDensity @spec.density
		
		text = (y, dy=0) -> new RockRegionText(rock: rock, y: y, dy: "#{dy}em")
		
		@dUnit = text 1, 1
		@widthText = text 3
		@speedText = text 4
		@timeText = text 5
		
	model: ->
		
		# @density and @w set
		
		@speed = 1.5 * Math.sqrt(1200/@density)
		@time = @w/@speed
		
		
	set: (x=@x, w=@w) ->
		@x = x
		@w = w
		super @x, @w
		center = @x+@w/2
		
		@model()
		
		#width = @w
		#speed = 1.5 * Math.sqrt(1200/@density)
		#time = width/speed
		
		rnd = Math.round
		rnd1 = (x) -> rnd(10*x)/10
		
		set = (t, v, rnd, unit) ->
			t?.set center, rnd(v)+" #{unit ? ''}"
			
		set @densityText, @density, rnd
		
		#@densityText?.set center, rnd(@density)
		@dUnit?.set center, "kg/m3"  # TODO: superscript m3
		
		set @widthText, @w, rnd, "km"
		set @speedText, @speed, rnd1, "km/s"
		set @timeText, @time, rnd1, "s"
		#@widthText?.set center, rnd(@w)+" km"
		#@speedText?.set center, rnd1(@speed)+" km/s"
		#@timeText?.set center, rnd1(@time)+" s"
		
	setDensity: (@density) ->
		x = 250 - Math.round(150*(@density-1200)/2500)
#		x = 200 - 200*(@density-1200)/2500
		@fill = "rgb(#{x}, #{x-40}, #{x-80})"
#		@fill = "rgb(255, #{x}, #{x})"
		@rect.attr "fill", @fill
		@set()
		

class RockBoundary extends RockRectangle
	
	width: 4
	
	constructor: (@spec) ->
		@spec.w = @width
		super @spec
		@rect.attr "class", "rock-boundary"
		rock = @spec.rock
		@distance = new Text(rock: rock, y: 8, dy: "1.2em")  # TODO 8 here is thickness - get from somewhere?
#		@distance = new RockBoundaryDistance {rock: @spec.rock}
		@setDraggable()
		
	set: (x, @w) ->
		@w ?= @width
		super (x-@w/2), @w
		@distance?.set(x, Math.round(x))
#		@distance?.set x
		
	setDraggable: ->
		@rect.call(
			d3.behavior
			.drag()
			.on("drag", => @spec.callback(@spec.idx, @rock.invertX(d3.event.x)))
		)


class Text
	
	textClass: "rock-boundary-text"
	
	constructor: (@spec) ->
		
		{@rock} = @spec  # TODO: more here
		@mx = @rock.mx
		@my = @rock.my
		
		#console.log "ROCK", @rock
		@text = @rock.append("text")
			.attr("y", @my(@spec.y))
			.attr("class", @textClass)  # TODO: not unsel for xlabels
		
		#if @spec.click
		#	@text.on("click", => @spec.click())
			#@text.attr("class", "rock-boundary-text unselectable")
		
		@text.attr("dy", @spec.dy) if @spec.dy
		
	set: (@x, @t) ->
		@text.attr("x", @mx(@x))
		@text.text(@t)
		
	setText: (@t) ->
		@text.text(@t)
		
		
class RockRegionText extends Text
	
	textClass: "rock-boundary-text unselectable rock-region"  # TODO: change cursor



# Exports
$blab.Rock = Rock