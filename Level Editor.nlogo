extensions [table gamelogo]
globals [
  w? a? s? d? wDown? shift? lastDown?
  objects currentObj next-id
  level world-palette frame-palette world-map height width tileSet
  mario
  add1 sub1
  cameraX cameraY
  xSprite hitQSprite airSprite air
  snakePath snakeFacing snakeEnd
  marioPalette
]

to setFramePalette
  set frame-palette map [[c]-> ifelse-value is-list? first c [item ((ticks / 4) mod length c) c] [c]] world-palette
end

to decreaseHeightTo [newH]
  set world-map sublist world-map 0 newH
  set height newH
end

to decreaseWidthTo [newW]
  set world-map map [[row]-> sublist row 0 newW] world-map
  set width newW
end

to saveLevel [str]
  file-close
  if file-exists? str [ file-delete str ]
  file-open str

  file-print length world-palette
  foreach world-palette [[c]->
    file-print c
  ]

  file-print length tileset
  foreach tileset [[tile]->
    let asStr (word tile)
    file-print substring asStr 1 (length asStr - 1)
  ]

  file-print (word height " " width)
  foreach (range (length world-map - 1) -1 -1) [[i]->
    let row item i world-map
    let asStr (word row)
    file-print (substring asStr 1 (length asStr - 1))
  ]
  file-flush
  file-close
end

to drawTiles
  let yTile tileCoord (mouse-ycor + cameraY)
  let xTile tileCoord (mouse-xcor + cameraX)
  if mouse-down? and xTile >= 0 and yTile >= 0 [
    if xTile >= width [
      let addedZeros n-values (xTile - width + 1) [[i]-> 0]
      set world-map map [[row]-> sentence row addedZeros] world-map
      set width xTile + 1
    ]
    if yTile >= height [
      let addedRow n-values (width) [[i]-> 0]
      let addRows n-values (yTile - height + 1) [[i]-> addedRow]
      set world-map sentence world-map addRows
      set height yTile + 1
    ]

    set world-map replace-item yTile world-map replace-item xTile (item yTile world-map) selectedTile
  ]
end

to setKeyBinds
  set lastDown? false
  gamelogo:unbind-all
  gamelogo:bind-var 87 w?
  gamelogo:bind-var 65 a?
  gamelogo:bind-var 83 s?
  gamelogo:bind-var 68 d?
  gamelogo:bind-var 160 shift?
end

to-report copy-table [orig] ; taken from table extension homepage
  let copy table:make
  foreach table:keys orig [[key]->
     table:put copy key table:get orig key
  ]
  report copy
end

to createParticle [x y sprite velX velY flipped]
  let particle table:from-list (list
    ["type" "particle"]
    (list "px" x) (list "py" y)
    (list "vx" velX) (list "vy" velY)
    ["width" 16] ["height" 16]
    ["onGround?" true] ["current-sprite" 0] (list "sprites" (list sprite))
    ["gMult" 2] ["collides?" false] (list "flipped?" flipped)
  )
  addObj particle
end

to-report replaceAll [str char repl]
  while [ member? char str ] [
    set str replace-item (position char str) str repl
  ]
  report str
end

to updateWorld
  set world-palette read-from-string worldColors
  setFramePalette
  set tileSet read-from-string (replaceAll tiles "\n" " ")
  table:put level "tiles" (map [[tile]-> replace-item 0 tile gamelogo:create-sprite first tile] tileSet)
end

to setupSnake
  file-open "snake1.txt"
  set snakePath file-read
  file-close
  let start first snakePath
  ;setProperty (item 0 start) (item 1 start) 2 2
  set snakeEnd last snakePath
  let movingToI 1
  let movingTo (item 1 snakePath)
  while [start != snakeEnd] [
    if start = movingTo [
      set movingToI movingToI + 1
      set movingTo (item movingToI snakePath)
    ]
    set start (map moveTo start movingTo)
    ;setProperty (item 0 start) (item 1 start) 2 2
  ]
  set snakeFacing map sign (map - item 0 snakePath item 1 snakePath)
end

to-report sign [n]
  report (ifelse-value n > 0 [1] n < 0 [-1] [0])
end

to addObj [obj]
  table:put obj "id" next-id
  table:put objects next-id obj
  set next-id next-id + 1
end

to spawnMushroom [x y]
  let mushroom table:from-list (list
    ["type" "mushroom"]
    (list "px" x) (list "py" y)
    ["vx" 0] ["vy" 0.75] ["dir" 1]
    ["width" 15] ["height" 15]
    ["onGround?" true] ["current-sprite" 0]
    ["gMult" 0]
  )
  table:put mushroom "sprites" (list gamelogo:create-sprite "mushroom.txt")
  addObj mushroom
end

to setupMario
  file-open "marioColors.txt"
  set marioPalette file-read
  file-close
  set mario table:from-list [
    ["type" "mario"]
    ["px" 40] ["py" 32]
    ["vx" 0] ["vy" 0]
    ["width" 13] ["height" 15]
    ["onGround?" true]
    ["current-sprite" 0] ["animationTimer" 0]
  ]
  table:put mario "sprites" toSpriteList
  ["marioSmall" "marioBig"
    "marioW1" "marioBW1"
    "marioW2" "marioBW2"
    "marioW3" "marioBW3"
    "marioJ" "marioBJ"]
  addObj mario
end

to setupObjects
  set objects table:make
  setupMario
end

to-report toSpriteList [stringList]
  report map [[str]-> gamelogo:create-sprite (word str ".txt")] stringList
end

to-report tileAsStr [tile]
  report replace-item 0 tile (word "\"" first tile "\"")
end

to setupLevel [name]
  set level table:make
  gamelogo:store-level level name
  set world-map table:get level "map"
  set world-palette table:get level "palette"
  setFramePalette
  set worldColors (word world-palette)
  set height table:get level "height"
  set width table:get level "width"
  gamelogo:fill-world item 0 frame-palette
  set tileSet gamelogo:get-raw-tileset name
  set tiles (word "[\n"
    (reduce [[str tile]->
      (word str "\n" tileAsStr tile)
  ] (replace-item 0 tileSet tileAsStr first tileSet)) "\n]")
  set cameraY 0
  drawLevel level
end

to setup
  ca
  reset-ticks
  tick
  set xSprite gamelogo:create-sprite "x.txt"
  set airSprite gamelogo:create-sprite "air.txt"
  set hitQSprite gamelogo:create-sprite "hitQuestion.txt"
  set air (list airSprite 0 0 15 7)
  setKeyBinds
  setupObjects
  setupLevel loadFrom
  set add1 addR 1
  set sub1 subR 1
  drawObj mario
  setupSnake
  tick
end

to-report compose [r1 r2]
  report [ [x] -> (run-result r1 (run-result r2 x))]
end

to-report composeL [lR]
  if length lR = 0 [ error "composeL called on empty list"]
  let output first lR
  set lR but-first lR
  while [length lR != 0] [
    set output compose output first lR
    set lR but-first lR
  ]
  report output
end

to-report addR [x]
  report [[y] -> y + x]
end

to-report subR [x]
  report [[y] -> y - x]
end

to-report zerR [x]
  report [[y] -> ifelse-value abs y <= x [0] [y - x * (abs y / y)] ]
end

to-report toR [n x]
  report [[y] -> ifelse-value abs (y - n) <= x [n] [y - x * sign (y - n)] ]
end

to-report moveTo [from dest]
  report ifelse-value abs (from - dest) <= 1 [dest] [from - sign (from - dest)]
end

to-report minR [x]
  report [[y] -> ifelse-value y > x [x] [y]]
end

to-report maxR [x]
  report [[y] -> ifelse-value y < x [x] [y]]
end

to-report lerp [n1 n2 t]
  report n1 + t * (n2 - n1)
end

to-report lerpC [c1 c2 t]
  report (list
    (lerp item 0 c1 item 0 c2 t)
    (lerp item 1 c1 item 1 c2 t)
    (lerp item 2 c1 item 2 c2 t))
end

to-report lerpPalette [palette c t]
  foreach range length palette [[i]->
    set palette replace-item i palette (lerpC item i palette c t)
  ]
  report palette
end

to drawObj [obj]
  let palette ifelse-value obj = mario [ marioPalette ] [ frame-palette ]
  gamelogo:draw-sprite-at palette floor (table:get obj "px" - cameraX) floor (table:get obj "py" - cameraY) (item (table:get obj "current-sprite") (table:get obj "sprites")) (table:get-or-default obj "flipped" false)
end

to drawTile [tile x y]
  gamelogo:draw-sprite-at frame-palette floor (x * 16 - cameraX) floor (y * 16 - cameraY) first tile false
end

to drawTileTinted [tile x y c]
  gamelogo:draw-sprite-at lerpPalette frame-palette c 0.5 floor (x * 16 - cameraX) floor (y * 16 - cameraY) first tile false
end

to tableChange [tbl key pro]
  table:put tbl key (run-result pro table:get tbl key)
end

to-report clamp [v minN maxN]
  report (ifelse-value v < minN [minN] v > maxN [maxN] [v])
end

to drawLevel [lvl]
  foreach (range tileCoord (cameraY + 239) (tileCoord cameraY - 1) -1) [[y]->
    foreach (range tileCoord cameraX (tileCoord (cameraX + 255) + 1)) [[x]->
      let tile getTile x y
      let snakeProp getProperty tile 2
      (ifelse snakeProp = 2 [
        drawTileTinted tile x y [255 255 255]
      ] snakeProp = 1 [
        drawTileTinted tile x y [255 0 0]
      ] [
        drawTile tile x y
      ])
    ]
  ]
end

to-report getProperty [tile index]
  report ifelse-value length tile <= index [
    0
  ] [
    item index tile
  ]
end

to-report tile-in-world? [x y]
  report x >= 0 and x < width and y >= 0 and y < height
end

to setProperty [x y index value]
  if tile-in-world? x y [
    let tile getTile x y
    while [length tile <= index]
    [
      set tile lPut 0 tile
    ]
    setTile x y (replace-item index tile value)
    ;set world-map replace-item y world-map (replace-item x (item y world-map) (replace-item index tile value))
  ]
end

to setTile [x y tile]
  if tile-in-world? x y [
    set world-map replace-item y world-map (replace-item x (item y world-map) tile)
  ]
end

to-report getBit [num index]
  report floor(num / 2 ^ index) mod 2
end
to-report getBitBool [num index]
  report getBit num index = 1
end

to-report propBit [tile p i]
  report getBitBool (getProperty tile p) i
end

to-report tileAt [x y]
  report getTile (x / 16) (y / 16)
end

to-report typeAt [x y]
  report item 1 tileAt x y
end

to-report getTile [tx ty]
  ifelse tx >= 0 and tx < width and ty >= 0 and ty < height [
    let output item tx item ty world-map
    if is-number? output [
      report ifelse-value output = 0 [air] [ item (output - 1) table:get level "tiles" ]
    ]
    report output
  ] [
    report air
  ]
end

to-report getTileL [tP]
  report getTile item 0 tP item 1 tP
end

to-report tileCoord [v]
  report floor (v / 16)
end

to-report w report table:get currentObj "width" end
to-report h report table:get currentObj "height" end
to-report px report table:get currentObj "px" end
to-report py report table:get currentObj "py" end
to-report vx report table:get currentObj "vx" end
to-report vy report table:get currentObj "vy" end
to-report lSide report px - (w - 1) / 2 end
to-report rSide report px + (w - 1) / 2 end
to-report topSide report py + h - 1 end
to-report botSide report py end

;to-report i


to-report tileLower [tp]
  report tp * 16
end

to-report tileUpper [tp]
  report tp * 16 + 15
end

to-report overlapsTile [obj tx ty]
  let oldCurr currentObj
  set currentObj obj
  let minX px - w / 2
  let maxX px + w / 2
  let minY py
  let maxY py + h
  let output (minX < tileUpper tx and maxX > tileLower tx) and (minY < tileUpper ty and maxY > tileLower ty)
  set currentObj oldCurr
  report output
end

to-report overlappingObjs [tx ty]
  report filter [[obj]-> overlapsTile obj tx ty ] table:values objects
end

to drawXTile [x y c]
  drawXTileAt floor (x * 16) floor (y * 16) c
end

to drawXTileAt [x y c]
  gamelogo:draw-sprite-at (list (item 0 frame-palette) c) x - cameraX y - cameraY xSprite false
end

to drawPoint [x y c]
  let p patch floor (x - cameraX) floor (y - cameraY)
  if p != nobody
  [ ask p [ set pcolor c ] ]
end

to-report boolListToNum [bools]
  let bit ifelse-value last bools [1] [0]
  report ifelse-value length bools = 1 [ bit ]
  [ 2 * boolListToNum but-last bools + bit ]
end

to updateSnake
  let start first snakePath
  let headTile getTileL start
  if getProperty headTile 1 = 0 [
    set start (map - start snakeFacing)
    ifelse start = item 1 snakePath
    [ set snakePath but-first snakePath
      ifelse length snakePath > 1 [
        set snakeFacing (map sign (map - item 0 snakePath item 1 snakePath))
      ] [
        set snakePath lput start snakePath
      ]
    ]
    [ set snakePath replace-item 0 snakePath start ]
  ]
  let movingToI 1
  let movingTo item 1 snakePath
  let newSnakeEnd snakeEnd
  let proc [->
    if start = movingTo [
      set movingToI (min2 (movingToI + 1) (length snakePath - 1))
      set movingTo item movingToI snakePath
    ]
    let next (map moveTo start movingTo)
    ifelse newSnakeEnd = snakeEnd [
      let nextTile getTileL next
      if getProperty nextTile 1 = 0 [ set newSnakeEnd start ]
    ] [
      setProperty (item 0 start) (item 1 start) 2 1
    ]
    set start next
  ]
  while [start != snakeEnd] [ run proc ]
  run proc
  if snakeEnd != newSnakeEnd [
    set snakeEnd newSnakeEnd
    set snakePath lput snakeEnd sublist snakePath 0 movingToI
  ]
  if length snakePath = 1 [ set snakePath lput snakeEnd snakePath]
end

to-report min2 [a b]
  report ifelse-value a > b [b] [a]
end
to-report max2 [a b]
  report ifelse-value a < b [b] [a]
end

to removeObj [obj]
  table:remove objects table:get obj "id"
end

to go
  setFramePalette
  let skyColor item 0 frame-palette
  gamelogo:fill-world skyColor

  let speed ifelse-value shift? [16] [4]
  if w? [ set cameraY cameraY + speed ]
  if s? [ set cameraY cameraY - speed ]
  if a? [ set cameraX cameraX - speed ]
  if d? [ set cameraX cameraX + speed ]

  if cameraX < 0 [set cameraX 0]
  if cameraY < 0 [set cameraY 0]
  ask patches with [(pxcor + cameraX) mod 16 < 1 or (pycor + cameraY) mod 16 < 1] [ set pcolor lerpC skyColor [64 64 64] 0.5 ]
  ask patches with [tileCoord (pxcor + cameraX) = width or tileCoord (pycor + cameraY) = height] [ set pcolor red]
  drawLevel level
  foreach table:values objects [[obj]->
    drawObj obj
  ]
  tick
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
730
499
-1
-1
2.0
1
10
1
1
1
0
1
1
1
0
255
0
239
1
1
1
ticks
60.0

BUTTON
41
24
104
57
NIL
setup
NIL
1
T
OBSERVER
NIL
R
NIL
NIL
1

BUTTON
119
23
182
56
NIL
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
0

BUTTON
117
68
180
101
NIL
go
NIL
1
T
OBSERVER
NIL
F
NIL
NIL
0

INPUTBOX
13
105
184
197
worldColors
[[0 0 0] [187 239 238] [38 123 139] [0 25 50] [[231 156 33] [231 156 33] [156 74 0] [82 33 0] [156 74 0]] [156 74 0]]
1
1
String

BUTTON
15
339
118
372
NIL
updateWorld
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
11
437
198
470
NIL
saveLevel saveTo
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
2
374
199
434
saveTo
level3.txt
1
0
String

BUTTON
744
77
827
110
NIL
drawTiles
T
1
T
OBSERVER
NIL
Q
NIL
NIL
1

INPUTBOX
13
213
197
273
loadFrom
level3.txt
1
0
String

INPUTBOX
741
122
968
387
tiles
[\n[\"ground.txt\" 1]\n[\"brick.txt\" 2 1]\n[\"question.txt\" 3 1]\n[\"question.txt\" 4 1]\n[\"brick.txt\" 3 1]\n[\"brick.txt\" 4 1]\n[\"question.txt\" 4]\n[\"block.txt\" 1]\n[\"coin.txt\" 6 0 15]\n[\"brickSmooth.txt\" 2]\n[\"cloud.txt\" 1 0 7]\n]
1
1
String

SLIDER
741
26
913
59
selectedTile
selectedTile
0
ifelse-value is-list? tileset [ length tileset ] [ 0 ]
1.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
