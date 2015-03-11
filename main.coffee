# Edit then press shift-enter or swipe right

# P-wave speed and time
model =
    speed: (density) -> 1.5*sqrt(1200/density)
    time: (width, speed) -> width/speed

# Density range and color mapping
densityRange = [1200, 3700]
colorMap = (density) ->
    [dMin, dMax] = densityRange
    span = dMax - dMin
    x = 250 - round(150*(density-dMin)/span)
    "rgb(#{x}, #{x-40}, #{x-80})"

# Run simulation
new $blab.Rock  #;
    widths: [50, 90, 70, 90]
    thickness: 8
    densities: [2250, 1700, 1200, 2600]
    densityRange: densityRange
    colorMap: colorMap
    model: model