class Rock
	
	width: 900
	height: 300
	margin: {top: 20, right: 100, bottom: 10, left: 200}
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
	
	# Not used
	invertY: (y) ->  @limit @my.invert(y), @yDomain
		
	limit: (z, d) ->
		return d[1] if z>d[1]
		return d[0] if z<d[0]
		z
		
	append: (obj) -> @rock.append(obj)
	

class RockRegions
	
	constructor: (@spec) ->
		
		{@rock} = @spec
		
		@widths = [25, 50, 75, 150]
		@fills = ["red", "#f66", "#faa", "#fcc"]
		
		setBoundary = (idx, x) => @setBoundary(idx, x)
		
		@regions = (new RockRegion(rock: @rock, fill: fill) for fill in @fills)
		@boundaries = (new RockBoundary(rock: @rock, idx: idx, callback: setBoundary) for region, idx in @regions[0..-2])
		
		@draw()
		
	setBoundary: (idx, x) ->
		c = @cumulativeWidths()
		xMin = if idx>0 then c[idx-1] else 0
		xMax = c[idx+1]
		@widths[idx..idx+1] = [x-xMin, xMax-x] if x>xMin and x<xMax
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
			
		@set @x, @w
	
	set: (@x, @w) ->
		@rect.attr "x", @mx(@x)
		@rect.attr "width", @mx(@w) if @w


class RockRegion extends RockRectangle
	
	constructor: (@spec) ->
		super @spec
		@rect.attr "fill", @spec.fill


class RockBoundary extends RockRectangle
	
	width: 4
	
	constructor: (@spec) ->
		@spec.x = @spec.x - @width/2
		@spec.w = @width
		super @spec
		@rect.attr "class", "rock-boundary"
		@setDraggable()
	
	setDraggable: ->
		@rect.call(
			d3.behavior
			.drag()
			.on("drag", => @spec.callback(@spec.idx, @rock.invertX(d3.event.x)))
		)


# Exports
$blab.Rock = Rock