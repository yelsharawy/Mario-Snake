extensions [table gamelogo]
globals [
  w? a? s? d? wDown? shift? ; flags for button presses
  objects currentObj next-id levelObjects ; object-related
  level world-palette frame-palette world-map ; world-related
  marioPalette mario sinceJump ducking? dead? won? dFrame wFrame ; mario related
  add1 sub1 ; procedures
  cameraX cameraY ; camera
  bParticleLSprite bParticleRSprite ; brick sprites
  xSprite hitQSprite airSprite air ; other sprites, and the "air" tile
  coyote gravity releaseMultiplier fallMultiplier ; physics-related
  snakePath snakeFacing snakeMoving snakeEnd moveTimer snake? ; snake-related
  sBump sJump sPUAppear sPowerup sBreakBlock sWarning ; sounds
  sCollectCoin sDeath sGameover sStomp sPipe s1-up sKick sWin sWorldClear mOverworld ; more sounds
  allChars charSprites ; character sprites (for text in world)
  lives score coins time invFrames ; death-related
]

to-report currentLevel ; returns file name of level
  report (word "level" levelN ".txt")
end

to startup ; startup is called when the model is opened, here i made it setup right away
  setup
end

to setupLevelGlobals ; sets up "level globals", that reset on death
  set time 500
  set ducking? false
  set dead? false
  set won? false
  set wFrame 0
  set dFrame 0
  set cameraX 0
  set cameraY 8
end

to setupGlobals ; sets up all globals
  set xSprite gamelogo:create-sprite "x.txt"
  set airSprite gamelogo:create-sprite "air.txt"
  set hitQSprite gamelogo:create-sprite "hitQuestion.txt"
  set bParticleLSprite gamelogo:create-sprite "brickParticleL.txt"
  set bParticleRSprite gamelogo:create-sprite "brickParticleR.txt"
  set air (list airSprite 0 0 15 7)
  set allChars " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{:}~|"
  set charSprites n-values 96 [[i]-> gamelogo:create-sprite (word "font\\" (i + 32) ".txt")]
  set gravity 1 / 3
  set releaseMultiplier 1.75
  set fallMultiplier 1.5
  set lives 10
  set add1 addR 1
  set sub1 subR 1
  setupLevelGlobals
end

to-report loadSound [str] ; loads sound from "sound" folder
  report gamelogo:create-clip word "sound\\" str
end

to setupMusic
  gamelogo:stop-loop
  set mOverworld loadSound (word "music" levelN ".mid")
  gamelogo:loop-clip mOverworld
end

to setupSounds ; sets up all sounds
  set sBump loadSound "bump.wav"
  set sJump loadSound "jump.wav"
  set sPUAppear loadSound "puAppears.wav"
  set sPowerup loadSound "powerup.wav"
  set sBreakBlock loadSound "breakBlock.wav"
  set sWarning loadSound "warning.wav"
  set sCollectCoin loadSound "collectCoin.wav"
  set sDeath loadSound "death.wav"
  set sWin loadSound "win.wav"
  set sWorldClear loadSound "worldClear.wav"
  set sGameover loadSound "gameover.wav"
  set sStomp loadSound "stomp.wav"
  set sPipe loadSound "pipe.wav"
  set s1-up loadSound "1-up.wav"
  set sKick loadSound "kick.wav"
  setupMusic
end

to-report mario-big? ; returns whether mario is currently using a "big" sprite
  report table:get mario "current-sprite" mod 2 = 1
end

to setKeyBinds ; sets keybinds using my extension
  gamelogo:unbind-all
  set wDown? false
  set w? false
  set snake? false
  ;gamelogo:bindkeydown 81 [ if snake? [ snakeDrop ] ]
  gamelogo:bindkeydown 32 [ if not anyBump? and not dead? and not won? [ set snake? not snake? ] ]
  gamelogo:bindkeydown 87 [ if not w? and not snake? [ set wDown? true ] ]
  gamelogo:bind-var 87 w?
  gamelogo:bind-var 65 a?
  gamelogo:bind-var 83 s?
  gamelogo:bind-var 68 d?
  gamelogo:bind-var 160 shift?
end

to-report copy-table [orig] ; taken from table extension homepage to copy tables
  let copy table:make
  foreach table:keys orig [[key]->
     table:put copy key table:get orig key
  ]
  report copy
end

to createParticle [x y sprite velX velY flipped? background] ; spawns a particle
  let particle table:from-list (list
    ["type" "particle"]
    (list "px" x) (list "py" y)
    (list "vx" velX) (list "vy" velY)
    ["width" 16] ["height" 16]
    ["onGround?" true] ["current-sprite" 0] (list "sprites" (list sprite))
    ["gMult" 2] ["collides?" false] (list "flipped?" flipped?) (list "background?" background)
  )
  addObj particle
end

to createBrickParticles [tx ty] ; creates 4 brick particles for when a block is broken
  createParticle (tx * 16) (ty * 16 + 8) bParticleLSprite -1.5 6 false false
  createParticle (tx * 16) (ty * 16) bParticleLSprite -1.5 3 true false
  createParticle (tx * 16 + 8) (ty * 16 + 8) bParticleRSprite 1.5 6 false false
  createParticle (tx * 16 + 8) (ty * 16) bParticleRSprite 1.5 3 true false
end

to hitAbove [tx ty] ; called to "hit" all objects above a brick block that has been hit
  foreach overlappingObjs tx (ty + 1) [[obj]->
    let objType table:get obj "type"
    (ifelse member? objType ["goomba" "koopa"] [
      hitObj obj
      if objType = "koopa" [ table:put obj "vy" 3 ]
    ] objType = "mushroom" and table:get obj "gMult" > 0 [
      table:put obj "vy" 3
      ;table:put obj "vx" (- table:get obj "vx")
      table:put obj "vx" (abs table:get obj "vx") * sign (table:get obj "px" - (tx * 16 + 8))
    ] objType = "shell" [
      table:put obj "vy" 3
      table:put obj "dir" 3 * sign (table:get obj "px" - (tx * 16 + 8))
      table:put obj "vx" table:get obj "dir"
    ])
  ]
end

to bumpBlock [tx ty] ; called to "bump" up a block
  gamelogo:play-clip sBump
  let block table:from-list (list
    ["type" "bump"]
    (list "px" (tx * 16)) (list "py" (ty * 16))
    ["vx" 0] ["vy" 2]
    ["width" 16] ["height" 16]
    ["onGround?" true] ["current-sprite" 0]
    ["gMult" 1] ["collides?" false]
  )
  let sprite getProperty getTile tx ty 0
  if sprite != airSprite [
    table:put block "sprites" (list sprite)
    setProperty tx ty 0 airSprite
    addObj block
    hitAbove tx ty
  ]
end

to checkHit [obj] ; checks whether Mario has jumped on top of or bumped into an object
  if not dead? and not won? and collides? and objsOverlap obj mario [
    ifelse marioStomped? [
      hitObj obj
      table:put mario "py" topSide
      table:put mario "vy" 4
    ] [
      damageMario
    ]
  ]
end

to turnToShell [obj] ; turns a koopa into a shell
  gamelogo:play-clip sStomp
  table:put obj "animationTimer" 0
  table:put obj "current-sprite" 2
  table:put obj "dir" 0
  table:put obj "vx" 0
  table:put obj "vy" 0
  table:put obj "type" "shell"
  set score score + 100
end

to hitObj [obj] ; does enemy-specific actions to "hit" them
  let kind table:get obj "type"
  (ifelse kind = "mario" [ damageMario ]
    kind = "koopa" [ turnToShell obj ]
    kind = "goomba" [ killEnemy obj ])
end

to killEnemy [obj] ; kills an enemy
  gamelogo:play-clip sStomp
  let kind table:get obj "type"
  ifelse kind = "goomba" [
    table:put obj "animationTimer" 0
    table:put obj "current-sprite" 1
    table:put obj "vx" 0
    table:put obj "vy" 0
    table:put obj "gMult" 0
    table:put obj "collides?" false
    set score score + 100
  ] [
    set score score + 100
    removeObj obj
  ]
end

to-report anyBump? ; finds whether there are any "bump"s in the world
  report not empty? filter [[obj]-> table:get obj "type" = "bump"] table:values objects
end

to-report objsOverlap [obj1 obj2] ; checks whether 2 objects overlap
  let oldCurrent currentObj
  set currentObj obj1
  let l lSide
  let r rSide
  let t topSide
  let b botSide
  set currentObj obj2
  let output (rSide >= l and lSide <= r) and (topSide >= b and botSide <= t)
  set currentObj oldCurrent
  report output
end

to setupSnake ; sets up snake
  file-open (word "snake" levelN ".txt")
  set snakePath file-read
  file-close
  let start first snakePath
  setProperty (item 0 start) (item 1 start) 2 2
  set snakeEnd last snakePath
  let movingToI 1
  let movingTo (item 1 snakePath)
  while [start != snakeEnd] [
    if start = movingTo [
      set movingToI movingToI + 1
      set movingTo (item movingToI snakePath)
    ]
    set start (map moveTo start movingTo)
    setProperty (item 0 start) (item 1 start) 2 2
  ]
  set snakeMoving [0 0]
  set snakeFacing map sign (map - item 0 snakePath item 1 snakePath)
end

to-report sign [n] ; gets the sign of a number: -1 if negative, 0 if 0, and 1 if positive
  report (ifelse-value n > 0 [1] n < 0 [-1] [0])
end

to addObj [obj] ; adds an object to the table of all objects
  table:put obj "id" next-id
  table:put objects next-id obj
  set next-id next-id + 1
end

to spawnCoin [x y] ; spawns a coin particle at a certain position
  let coin table:from-list (list
    ["type" "coin"]
    (list "px" x) (list "py" y)
    ["vx" 0] ["vy" 4] ["gMult" 0.75]
    ["width" 16] ["height" 16]
    ["onGround?" true] ["animationTimer" 0]
    ["collides?" false] ["current-sprite" 0]
    )
  table:put coin "sprites" toSpriteList [ "coin0" "coin1" "coin2" "coin3" ]
  addObj coin
end

to spawnMushroom [x y] ; spawns a mushroom at a current position
  let mushroom table:from-list (list
    ["type" "mushroom"]
    (list "px" x) (list "py" y)
    ["vx" 0] ["vy" 0.25] ["dir" 1]
    ["width" 16] ["height" 16]
    ["onGround?" true] ["current-sprite" 0]
    ["gMult" 0] ["background?" true] ["collides?" false]
  )
  table:put mushroom "sprites" toSpriteList [ "mushroom" ]
  addObj mushroom
end

to spawnGoomba [x y] ; spawns a goomba at a current position
  let goomba table:from-list [
    ["type" "goomba"]
    ["vx" -0.5] ["vy" -1] ["dir" -0.5]
    ["width" 16] ["height" 16]
    ["onGround?" true] ["flipped?" false]
    ["current-sprite" 0] ["animationTimer" 0]
  ]
  table:put goomba "px" x
  table:put goomba "py" y
  table:put goomba "sprites" toSpriteList [ "goomba" "goombaSquashed" ]
  addObj goomba
end

to spawnKoopa [x y] ; spawns a koopa at a current position
  let koopa table:from-list [
    ["type" "koopa"]
    ["vx" -0.5] ["vy" -1] ["dir" -0.5]
    ["width" 16] ["height" 16]
    ["onGround?" true] ["flipped?" false]
    ["current-sprite" 0] ["animationTimer" 0]
  ]
  table:put koopa "px" x
  table:put koopa "py" y
  table:put koopa "sprites" toSpriteList [ "koopa1" "koopa2" "koopaShell" ]
  addObj koopa
end

to setupMario ; sets up mario
  file-open "marioColors.txt"
  set marioPalette file-read
  file-close
  set mario table:from-list [
    ["type" "mario"]
    ["px" 40] ["py" 32]
    ["vx" 0] ["vy" -1]
    ["width" 14] ["height" 12]
    ["onGround?" true] ["flipped?" false]
    ["current-sprite" 0] ["animationTimer" 0]
  ]
  table:put mario "sprites" toSpriteList
  ["marioSmall" "marioBig"
    "marioW1" "marioBW1"
    "marioW2" "marioBW2"
    "marioW3" "marioBW3"
    "marioJ" "marioBJ"
    "marioT" "marioBT"
    "marioDie" "marioDuck"
  ]
  addObj mario
end

to loadObjects [file] ; loads objects from an objects file
  file-open file
  set levelObjects file-read
  foreach levelObjects [[obj]->
    let kind item 0 obj
    let x 8 + 16 * item 1 obj
    let y 16 * item 2 obj
    (ifelse kind = "goomba" [
      spawnGoomba x y
    ] kind = "koopa" [
      spawnKoopa x y
    ])
  ]
  file-close
end

to setupObjects ; sets up objects
  set objects table:make
  setupMario
  loadObjects (word "objects" levelN ".txt")
end

to-report toSpriteList [stringList] ; converts a list of strings to a sprite list
  report map [[str]-> gamelogo:create-sprite (word str ".txt")] stringList
end

to setFramePalette ; sets the "frame palette" - used for animating the palette
  set frame-palette map [[c]-> ifelse-value is-list? first c [item ((ticks / 8) mod length c) c] [c]] world-palette
end

to setupLevel [name] ; sets up a level from a file
  set level table:make
  gamelogo:store-level level name
  set world-map table:get level "map"
  set world-palette table:get level "palette"
  setFramePalette
  gamelogo:fill-world item 0 frame-palette
  set cameraY 8
  drawLevel level
end

to-report getChar [i] ; gets a character from its keycode (UNUSED)
  report item (i - 32) allChars
end
to-report getCode [c] ; gets a keycode from its character
  report position c allChars + 32
end

to-report asStringOfLength [n len] ; adds 0s before a number to reach a certain length
  let str (word n)
  while [ length str < len ] [
    set str word "0" str
  ]
  report str
end

to drawString [x y str] ; draws a string on the screen
  while [str != ""] [
    gamelogo:draw-sprite-at (list first frame-palette [255 255 255]) x y (item (getCode first str - 32) charSprites) false
    set str substring str 1 length str
    set x x + 8
  ]
end

to drawHUD ; draws the HUD at the top of the screen
  drawString 24 (224 - 8) ifelse-value snake? and not dead? and not won? ["SNAKE"] ["MARIO"]
  drawString 24 (224 - 16) (asStringOfLength score 6)
  drawString 201 (224 - 8) "TIME"
  if dFrame < 150 [ drawString 209 (224 - 16) (asStringOfLength time 3) ]
end

to setup ; main setup function, calls all other setup functions
  ca
  reset-ticks
  tick
  setupGlobals
  setKeyBinds
  setupObjects
  setupLevel currentLevel
  drawObj mario
  setupSnake
  setupSounds
  drawHUD
  tick
end

to-report compose [r1 r2] ; composes 2 procedures together
  report [ [x] -> (run-result r1 (run-result r2 x))]
end

to-report composeL [lR] ; composes a list of procedures together (UNUSED, BUT COOL)
  if length lR = 0 [ error "composeL called on empty list"]
  let output first lR
  set lR but-first lR
  while [length lR != 0] [
    set output compose output first lR
    set lR but-first lR
  ]
  report output
end

to-report addR [x] ; creates a procedure to add x
  report [[y] -> y + x]
end

to-report subR [x] ; creates a procedure to subtract x
  report [[y] -> y - x]
end

to-report zerR [x] ; creates a procedure to move a number towards 0 by x
  report [[y] -> ifelse-value abs y <= x [0] [y - x * (abs y / y)] ]
end

to-report toR [n x] ; creates a procedure to move a number towards n by x
  report [[y] -> ifelse-value abs (y - n) <= x [n] [y - x * sign (y - n)] ]
end

to-report moveTo [from dest] ; "moves" the values of one list towards another
  report ifelse-value abs (from - dest) <= 1 [dest] [from - sign (from - dest)]
end

to-report minR [x] ; creates a procedure that returns the minimum of x and y
  report [[y] -> ifelse-value y > x [x] [y]]
end

to-report maxR [x] ; creates a procedure that returns the maximum of x and y
  report [[y] -> ifelse-value y < x [x] [y]]
end

to-report lerp [n1 n2 t] ; lerps between two numbers with an alpha value
  report n1 + t * (n2 - n1)
end

to-report lerpC [c1 c2 t] ; lerps between two colors with an alpha value
  report (list
    (lerp item 0 c1 item 0 c2 t)
    (lerp item 1 c1 item 1 c2 t)
    (lerp item 2 c1 item 2 c2 t))
end

to-report lerpPalette [palette c t] ; lerps a palette towards a color by t
  foreach range length palette [[i]->
    set palette replace-item i palette (lerpC item i palette c t)
  ]
  report palette
end

to drawObj [obj] ; draws an object
  let palette ifelse-value obj = mario [ marioPalette ] [ frame-palette ]
  gamelogo:draw-sprite-at palette floor (table:get obj "px" - cameraX) floor (table:get obj "py" - cameraY) (item (table:get obj "current-sprite") (table:get obj "sprites")) (table:get-or-default obj "flipped?" false)
end

to drawTile [tile x y] ; draws a tile
  gamelogo:draw-sprite-at frame-palette floor (x * 16 - cameraX) floor (y * 16 - cameraY) first tile false
end

to drawTileTinted [tile x y c] ; draws a tile tinted
  gamelogo:draw-sprite-at lerpPalette frame-palette c ifelse-value snake? [0.75] [0.25] floor (x * 16 - cameraX) floor (y * 16 - cameraY) first tile false
end

to tableChange [tbl key pro] ; changes the value of a table to the output of a procedure
  table:put tbl key (run-result pro table:get tbl key)
end

to-report clamp [v minN maxN] ; forces a number to be in an inclusive range between two other numbers
  report (ifelse-value v < minN [minN] v > maxN [maxN] [v])
end

to drawLevel [lvl] ; draws a level
  foreach (range tileCoord (cameraY + 223) (tileCoord cameraY - 1) -1) [[y]->
    foreach (range tileCoord cameraX (tileCoord (cameraX + 255) + 1)) [[x]->
      let tile getTile x y
      ifelse snake? and not dead? and not won? [
        let snakeProp getProperty tile 2
        (ifelse snakeProp = 2 [
          drawTileTinted tile x y ifelse-value (list x y) = first snakePath [[127 255 127]] [[255 255 255]]
        ] snakeProp = 1 [
          drawTileTinted tile x y [255 0 0]
        ] [
          drawTileTinted tile x y [0 0 0]
        ])
      ] [
        drawTile tile x y
      ]
    ]
  ]
end

to-report getProperty [tile index] ; gets property of a tile (list) at an index
  report ifelse-value length tile <= index [
    0
  ] [
    item index tile
  ]
end

to-report tile-in-world? [x y] ; checks whether tile coordinates x and y are in the world
  report x >= 0 and x < table:get level "width" and y >= 0 and y < table:get level "height"
end

to setProperty [x y index value] ; sets property of tile x y at an index to a value
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

to setTile [x y tile] ; sets tile x y to "tile"
  if tile-in-world? x y [
    set world-map replace-item y world-map (replace-item x (item y world-map) tile)
  ]
end

to-report getBit [num index] ; reports 1 or 0, which is the bit of num at index
  report floor(num / 2 ^ index) mod 2
end
to-report getBitBool [num index] ; returns getBit num index as a boolean
  report getBit num index = 1
end

to-report propBit [tile p i] ; combines getBitBool and getProperty for convenience
  report getBitBool (getProperty tile p) i
end

to-report tileAt [x y] ; gets tile at world coordinates x y
  report getTile (x / 16) (y / 16)
end

to-report typeAt [x y] ; gets type of tile at world coordinates x y
  report item 1 tileAt x y
end

to-report getTile [tx ty] ; gets tile at tile coordinates x y
  ifelse tx >= 0 and tx < table:get level "width" and ty >= 0 and ty < table:get level "height" [
    let output item tx item ty world-map
    if is-number? output [
      report ifelse-value output = 0 [air] [ item (output - 1) table:get level "tiles" ]
    ]
    report output
  ] [
    report air
  ]
end

to-report getTileL [tP] ; gets tile at tile coordinates represented by tP
  report getTile item 0 tP item 1 tP
end

to-report tileCoord [v] ; converts world coordinate to tile coordinate
  report floor (v / 16)
end

;;; BUNCH OF TINY HELPER FUNCTIONS FOR CONVENIENCE
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
to-report gMult report table:get-or-default currentObj "gMult" 1 end
to-report collides? report table:get-or-default currentObj "collides?" true end


to applyPhysics [obj] ; applies physics to an object
  set currentObj obj
  let d (w - 1) / 2
  table:put obj "onGround?" false
  let startY tileCoord (py - vy)
  let endY tileCoord py
  let startTop tileCoord (topSide - vy)
  let endTop tileCoord topSide
  if startY > endY [
    let cBL tileAt (lSide + 1) (botSide - 1 + vy) set cBL getProperty cBL 1 > 0 and not propBit cBL 3 3
    let cBR tileAt (rSide - 1) (botSide - 1 + vy) set cBR getProperty cBR 1 > 0 and not propBit cBR 3 3
    if cBL or cBR [ table:put obj "py" tileUpper tileCoord (botSide - 1 + vy) + 1 table:put obj "vy" 0 table:put obj "onGround?" true ]
  ]
  if startTop < endTop [
    let cTL tileAt (lSide + 2) (topSide + 1 + vy) set cTL getProperty cTL 1 > 0 and not propBit cTL 3 1
    let cTR tileAt (rSide - 2) (topSide + 1 + vy) set cTR getProperty cTR 1 > 0 and not propBit cTR 3 1
    if cTL or cTR [
      if obj = mario and not snake? [
        let hitL [-> hitTile tileCoord (lSide + 2) tileCoord (topSide + 1 + vy) obj ]
        let hitR [-> hitTile tileCoord (rSide - 2) tileCoord (topSide + 1 + vy) obj ]
        ifelse tileCoord (lSide + 2) = tileCoord (rSide - 2) [
          run hitL
        ] [
          if cTL [ run hitL ]
          if cTR [ run hitR ]
        ]
      ]
      table:put obj "py" tileLower tileCoord (topSide + 1 + vy) - h
      table:put obj "vy" -1
    ]
  ]
  let cLB tileAt (lSide - 1) (botSide + 2) set cLB getProperty cLB 1 > 0 and not propBit cLB 3 2
  let cLU tileAt (lSide - 1) (topSide - 2) set cLU getProperty cLU 1 > 0 and not propBit cLU 3 2
  let cRB tileAt (rSide + 1) (botSide + 2) set cRB getProperty cRB 1 > 0 and not propBit cRB 3 0
  let cRU tileAt (rSide + 1) (topSide - 2) set cRU getProperty cRU 1 > 0 and not propBit cRU 3 0
  if cLB and cLU and cRB and cRU [ hitObj obj ]
  if vx <= 0 and ((cLB and (not cRB or vx < 0)) or (cLU and (not cRU or vx < 0))) [
    if table:get obj "type" = "shell" and table:get obj "vx" != 0 [
      hitTile tileCoord (lSide - 1) tileCoord (botSide + 2) obj
      hitTile tileCoord (lSide - 1) tileCoord (topSide - 2) obj
    ]
    table:put obj "px" tileUpper tileCoord (lSide - 1) + d + 0.5 table:put obj "vx" 0
  ]
  if vx >= 0 and ((cRB and (not cLB or vx > 0)) or (cRU and (not cLU or vx > 0))) [
    if table:get obj "type" = "shell" and table:get obj "vx" != 0 [
      hitTile tileCoord (rSide + 1) tileCoord (botSide + 2) obj
      hitTile tileCoord (rSide + 1) tileCoord (topSide - 2) obj
    ]
    table:put obj "px" tileLower tileCoord (rSide + 1) - d - 0.5 table:put obj "vx" 0
  ]
end

to-report tileLower [tp] ; lower side of a tile coord to world coord
  report tp * 16
end

to-report tileUpper [tp] ; upper side of a tile coord to world coord
  report tp * 16 + 15
end

to-report overlapsTile [obj tx ty] ; checks whether obj overlaps tile tx ty
  let oldCurr currentObj
  set currentObj obj
  let minX px - w / 2
  let maxX px + w / 2
  let minY py
  let maxY py + h
  let output (minX < tileUpper tx - 1 and maxX > tileLower tx + 1) and (minY < tileUpper ty and maxY > tileLower ty)
  set currentObj oldCurr
  report output
end

to-report overlappingObjs [tx ty] ; reports all objects overlapping tile tx ty
  report filter [[obj]-> overlapsTile obj tx ty ] table:values objects
end

to drawXTile [x y c] ; draws an x tile at tile x y with color c
  drawXTileAt floor (x * 16) floor (y * 16) c
end

to drawXTileAt [x y c] ; draws an x tile at world coords x y with color c
  gamelogo:draw-sprite-at (list (item 0 frame-palette) c) (floor (x - cameraX)) (floor (y - cameraY)) xSprite false
end

to drawPoint [x y c] ; draws a single point at world coords x y with color c
  let p patch floor (x - cameraX) floor (y - cameraY)
  if p != nobody
  [ ask p [ set pcolor c ] ]
end

to-report boolListToNum [bools] ; converts list of bools to binary
  let bit ifelse-value last bools [1] [0]
  report ifelse-value length bools = 1 [ bit ]
  [ 2 * boolListToNum but-last bools + bit ]
end

to updateSnake ; updates the snake, checks whether broken, adjusts path
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

to collectCoin ; called when collected a coin
  gamelogo:play-clip sCollectCoin
  set score score + 200
  set coins coins + 1
  if coins >= 100 [
    set coins 0
    set lives lives + 1
    gamelogo:play-clip s1-up
  ]
end

to hitTile [tx ty hitter] ; hits a tile (mario jumps into it or shell hits it)
  let tile getTile tx ty
  let tType getProperty tile 1
  (ifelse tType = 3 [
    setProperty tx ty 0 hitQSprite
    setProperty tx ty 1 1
    spawnMushroom tx * 16 + 8 ty * 16 + 7
    ;spawnGoomba tx * 16 + 8 ty * 16 + 16
    gamelogo:play-clip sPUAppear
    bumpBlock tx ty
  ] tType = 2 [
    ifelse (hitter = mario and mario-big? and not (snakeEnd = first snakePath and tx = item 0 first snakePath and ty = item 1 first snakePath))
   or (table:get hitter "type" = "shell") [
      hitAbove tx ty
      setTile tx ty air
      createBrickParticles tx ty
      gamelogo:play-clip sBreakBlock
      updateSnake
      set score score + 50
    ] [
      bumpBlock tx ty
    ]
  ] tType = 4 [
    setProperty tx ty 0 hitQSprite
    setProperty tx ty 1 1
    bumpBlock tx ty
    collectCoin
    spawnCoin tx * 16 ty * 16 + 16
  ])
end

to snakeDrop ; drops a block behind from snake (FEATURE TESTED, REMOVED FOR RUNING PUZZLES)
  if snakeEnd != first snakePath [
    let start first snakePath
    let movingToI 1
    let movingTo item 1 snakePath
    while [start != snakeEnd] [
      if start = movingTo [
        set movingToI movingToI + 1
        set movingTo item movingToI snakePath
      ]
      let next (map moveTo start movingTo)
      if next = snakeEnd [
        setProperty (item 0 next) (item 1 next) 2 1
        set snakeEnd start
        set snakePath lput start sublist snakePath 0 movingToI
        stop
      ]
      set start next
    ]
  ]
end

to duckMario ; UNIMPLEMENTED function to force mario to duck

end

to moveSnake ; moves snake in direction snakeMoving
  let headMovesTo (map + first snakePath snakeMoving)
  if tile-in-world? (item 0 headMovesTo) (item 1 headMovesTo) [
    ifelse (map + snakeMoving snakeFacing) = [0 0] and first snakePath != snakeEnd [ ; REWINDING SNAKE
      if snakeEnd != last snakePath [ ; can't rewind if there was no previous place to rewind to
        let start first snakePath

        let lastTile air
        let movingToI 1
        let movingTo item 1 snakePath
        while [start != snakeEnd] [
          if start = movingTo [
            set movingToI movingToI + 1
            set movingTo item movingToI snakePath
          ]
          let next (map moveTo start movingTo)
          let thisTile getTileL start
          setTile (item 0 start) (item 1 start) lastTile
          set lastTile thisTile
          set start next
        ]
        repeat 2 [
          if start = movingTo [
            set movingToI movingToI + 1
            set movingTo item (min (list (length snakePath - 1) movingToI)) snakePath
          ]
          let next (map moveTo start movingTo)
          let thisTile getTileL start
          setTile (item 0 start) (item 1 start) lastTile
          set lastTile thisTile
          set snakeEnd start
          set start next
        ]
        ifelse headMovesTo = item 1 snakePath
        [ set snakePath but-first snakePath set snakeFacing (map sign (map - item 0 snakePath item 1 snakePath)) ]
        [ set snakePath replace-item 0 snakePath headMovesTo ]
      ]
    ] [
      let nextTile getTileL headMovesTo
      (ifelse getProperty nextTile 1 = 0 [ ; nothing ahead, move forward
        let x (16 * item 0 headMovesTo)
        let y (16 * item 1 headMovesTo)
        foreach overlappingObjs (item 0 headMovesTo) (item 1 headMovesTo) [[obj]->
          set currentObj obj
          if collides? [
            (ifelse snakeMoving = [0 1] [
              table:put obj "py" y + 16
            ] snakeMoving = [0 -1] [
              if obj = mario and mario-big? [
                duckMario
              ]
            ] snakeMoving = [1 0] [
              table:put obj "px" x + 16
              if table:get obj "type" = "shell" [
                gamelogo:play-clip sKick
                table:put obj "dir" 3
                table:put obj "vx" 3
              ]
            ] snakeMoving = [-1 0] [
              table:put obj "px" x
              if table:get obj "type" = "shell" [
                gamelogo:play-clip sKick
                table:put obj "dir" -3
                table:put obj "vx" -3
              ]
            ])
          ]
        ]
        ifelse snakeMoving = snakeFacing
        [ set snakePath replace-item 0 snakePath headMovesTo ]
        [ set snakePath fPut headMovesTo snakePath ]
        set snakeFacing snakeMoving
        let start first snakePath
        setProperty (item 0 start) (item 1 start) 2 2
        let movingToI 1
        let movingTo item 1 snakePath
        let moveDir snakeMoving
        while [start != snakeEnd] [
          if start = movingTo [
            set movingToI movingToI + 1
            set movingTo item movingToI snakePath
          ]
          foreach overlappingObjs (item 0 start) (item 1 start) [[obj]->
            if table:get obj "type" = "bump" [
              tableChange obj "px" subR (16 * (item 0 moveDir))
              tableChange obj "py" subR (16 * (item 1 moveDir))
            ]
          ]
          let next (map moveTo start movingTo)
          set moveDir (map - next start)
          setTile (item 0 start) (item 1 start) (getTile (item 0 next) (item 1 next))
          ifelse next = snakeEnd [
            setTile (item 0 next) (item 1 next) air
            set snakeEnd start
            foreach overlappingObjs (item 0 next) (item 1 next) [[obj]->
              if table:get obj "type" = "bump" [
                tableChange obj "px" subR (16 * (item 0 moveDir))
                tableChange obj "py" subR (16 * (item 1 moveDir))
              ]
            ]
          ] [
            set start next
          ]
        ]
      ] getProperty nextTile 2 = 1 [ ; food ahead, eat it
        ifelse snakeMoving = snakeFacing
        [ set snakePath replace-item 0 snakePath headMovesTo ]
        [ set snakePath fPut headMovesTo snakePath ]
        let start first snakePath
        setProperty (item 0 start) (item 1 start) 2 2
        set snakeFacing snakeMoving
        let movingToI 1
        let movingTo item 1 snakePath
        while [start != snakeEnd] [
          if start = movingTo [
            set movingToI movingToI + 1
            set movingTo item movingToI snakePath
          ]
          let next (map moveTo start movingTo)
          set start next
        ]
        set snakePath lput start sublist snakePath 0 movingToI
      ])
    ]
  ]
end

to-report min2 [a b] ; min of 2 numbers
  report ifelse-value a > b [b] [a]
end
to-report max2 [a b] ; max or 2 numbers
  report ifelse-value a < b [b] [a]
end

to removeObj [obj] ; removes obj from objects
  table:remove objects table:get obj "id"
end

to collectCoins ; checks whether mario overlaps any coins and collects them
  set currentObj mario
  let minTX tileCoord lSide
  let maxTX tileCoord rSide
  let minTY tileCoord botSide
  let maxTY tileCoord topSide
  foreach (range minTY (maxTY + 1)) [[y]->
    foreach (range minTX (maxTX + 1)) [[x]->
      if getProperty getTile x y 1 = 6 [
        setTile x y air
        collectCoin
      ]
    ]
  ]
end

to setMarioSprite ; sets mario's sprite appropriately
  if not dead? and not won? [
    ifelse ducking? [
      table:put mario "current-sprite" 13
      table:put mario "animationTimer" 0
    ] [
      ifelse table:get mario "onGround?" [
        (ifelse vx = 0 [
          tableChange mario "current-sprite" [[i]-> i mod 2]
          table:put mario "animationTimer" 0
        ] (vx > 0 and a? and not d?) or (vx < 0 and d? and not a?) [
          tableChange mario "current-sprite" [[i]-> i mod 2 + 10]
          table:put mario "animationTimer" 0
        ] [
          tableChange mario "animationTimer" subR abs vx
          if table:get mario "animationTimer" < 0 [
            tableChange mario "current-sprite" [[i]->  i mod 2 + 2 * ((floor (i / 2)) mod 3 + 1)]
            table:put mario "animationTimer" 10
          ]
        ])
      ] [
        table:put mario "animationTimer" 0
        tableChange mario "current-sprite" [[i]-> i mod 2 + 8]
      ]
    ]
  ]
end

to focusCamera [x y] ; moves camera only enough to clearly see point x y
  set cameraX floor clamp cameraX (x - 146) (x - 78)
  set cameraY floor clamp cameraY (y - 180) (y - 24)
  set cameraX clamp cameraX 0 (16 * length first world-map - 256)
  set cameraY clamp cameraY 8 (16 * length world-map - 224)
  ;if cameraX < 0 [set cameraX 0]
  ;if cameraY < 8 [set cameraY 8]
end

to gameOver ; when you lose all 3 lives, show game over screen
  gamelogo:fill-world [0 0 0]
  drawString 92 120 "GAME OVER"
  gamelogo:play-clip sGameover
  tick
  wait 5
  setup
end

to winAnimation ; called on go when winning, plays animation
  if time > 0 [
    let oldTime time
    set time (run-result (zerR random 10) time)
    set score score + 100 * (oldTime - time)
  ]
  set wFrame wFrame + 1
  (ifelse wFrame = 360 [
    set levelN levelN + 1
    carefully [
      reset-ticks
      clear-patches
      setupMusic
      setupLevelGlobals
      setupLevel currentLevel
      setupObjects
      setupSnake
      gamelogo:loop-clip mOverworld
      tick
    ] [
      gamelogo:fill-world [0 0 0]
      drawString 100 120 "YOU WIN"
      gamelogo:play-clip sWorldClear
      tick
      wait 8
      set levelN 1
      setup
    ]
  ])
end

to win ; called when you win
  if not dead? and not won? [
    set won? true
    set snake? false
    gamelogo:stop-loop
    gamelogo:play-clip sWin
    focusCamera table:get mario "px" table:get mario "py"
    table:put mario "vx" 2
  ]
end

to deathAnimation ; called on go when dead, plays animation
  set dFrame dFrame + 1
  (ifelse dFrame = 30 [
    table:put mario "vy" 7
    table:put mario "gMult" 1
  ] dFrame >= 150 and dFrame < 300 [
    ifelse lives <= 0 [ gameOver ]
    [
      gamelogo:fill-world [0 0 0]
      gamelogo:draw-sprite-at marioPalette 102 112 item 0 table:get mario "sprites" false
      drawString 120 120 word "|  " lives
    ]
  ] dFrame >= 300 [
    reset-ticks
    setupLevelGlobals
    setupLevel currentLevel
    setupObjects
    setupSnake
    gamelogo:loop-clip mOverworld
    tick
  ])
end

to loseLife ; called when you die
  if not dead? and not won? [
    set lives lives - 1
    set dead? true
    set snake? false
    gamelogo:stop-loop
    gamelogo:play-clip sDeath
    focusCamera table:get mario "px" table:get mario "py"
    table:put mario "current-sprite" 12
    table:put mario "collides?" false
    table:put mario "gMult" 0
    table:put mario "vx" 0
    table:put mario "vy" 0
  ]
end

to damageMario ; damages mario, potentially killing him
  if invFrames = 0 [
    ifelse mario-big? [
      gamelogo:play-clip sPipe
      table:put mario "current-sprite" 0
      table:put mario "height" 12
      set invFrames 60
    ] [
      loseLife
    ]
  ]
end

to controlSnake ; allows you to control snake
  let start first snakePath
  ifelse moveTimer = 0 [
    let keysPressed boolListToNum (list d? w? a? s?)
    ifelse keysPressed != 0 and log keysPressed 2 mod 1 = 0 [
      set snakeMoving (list (ifelse-value a? [-1] d? [1] [0]) (ifelse-value s? [-1] w? [1] [0]))
      moveSnake
      set moveTimer ifelse-value shift? [3] [6]
    ] [ set moveTimer 0 ]
  ]
  [
    set moveTimer moveTimer - 1
  ]
  let x 16 * item 0 first snakePath
  let y 16 * item 1 first snakePath
  focusCamera x y
end

to controlMario ; allows you to control mario
  set currentObj mario
  let onGround? table:get mario "onGround?"
  if vx != 0 and onGround? [ table:put mario "flipped?" (vx < 0) ]
  let maxSpeed max2 abs vx ifelse-value onGround? [ifelse-value shift? [3.5] [2]] [2]
  let acc ifelse-value abs vx < 2 [0.05] [0.075]
  let jumped? false
  ifelse onGround? [ set coyote 0 ] [ set coyote coyote + 1 ]
  ifelse w?
  [ if sinceJump < 2 and vy > 0 [ table:put mario "vy" 6 ]]
  [ set sinceJump 100 ]
  set sinceJump sinceJump + 1
  if wDown? and coyote < 4 [
    if ducking? and a? != d? [
      table:put mario "vx" ifelse-value a? [-1] [1]
    ]
    table:put mario "vy" 4
    set wDown? false
    set jumped? true
    set sinceJump 0
    gamelogo:play-clip sJump
  ]
  let dBefore ducking?
  set ducking? (s? and mario-big? and onGround?) or (dBefore and (not onGround? or not propBit (tileAt px (topSide + 16)) 3 1))
  ifelse ducking? [
    if not dBefore [ table:put mario "height" 12 ]
    ifelse onGround? [
      tableChange mario "vx" zerR 0.075
    ] [
      (ifelse a? = d? [ tableChange mario "vx" zerR ifelse-value onGround? [ ifelse-value abs vx > 2 [0.15] [0.075] ] [ 0 ] ]
        a? [ tableChange mario "vx" toR (- maxSpeed) (acc * ifelse-value vx > 0 [0.75] [1]) ]
        d? [ tableChange mario "vx" toR maxSpeed (acc * ifelse-value vx < 0 [0.75] [1]) ])
    ]
  ] [
    if dBefore [ table:put mario "height" ifelse-value mario-big? [30] [12] ]
    (ifelse a? = d? [ tableChange mario "vx" zerR ifelse-value onGround? [ ifelse-value abs vx > 2 [0.15] [0.075] ] [ 0 ] ]
      a? [ tableChange mario "vx" toR (- maxSpeed)
        (acc * ifelse-value vx > 0
          [ifelse-value onGround? [vx / 2 + 2] [0.75]]
          [1]) ]
      d? [ tableChange mario "vx" toR maxSpeed
        (acc * ifelse-value vx < 0
          [ifelse-value onGround? [vx / -2 + 2] [0.75]]
          [1]) ])
  ]

  tableChange mario "px" addR vx
  tableChange mario "py" addR vy
  applyPhysics mario

  tableChange mario "vy" (compose subR (ifelse-value vy < 0 [gravity * fallMultiplier] vy < 1 [gravity * 0.75] w? [gravity] [gravity * releaseMultiplier]) maxR -5) ; GRAVITY
  focusCamera px py
end

to-report marioStomped? ; checks whether mario would be stomping on an enemy or getting killed by it
  let difX table:get mario "px" - px
  let difY table:get mario "py" - py
  report table:get mario "vy" < 0 and difY > abs difX / 2 and difY > 1
end

to go ; THE MAIN GAME LOOP
  setFramePalette
  let skyColor item 0 frame-palette
  let snaking? snake? and not dead? and not won?
  (ifelse dead? [
    deathAnimation
  ] won? [
    winAnimation
  ] [
    ifelse snaking? [
      controlSnake
    ] [
      controlMario
    ]
  ])
  foreach table:values objects [[obj]->
    set currentObj obj
    let objType table:get obj "type"
    ifelse objType = "mario"
    [ if snaking? or dead? or won?
      [
        tableChange obj "px" addR vx
        tableChange obj "py" addR vy
        if collides? [ applyPhysics obj ]
        tableChange obj "vy" (compose subR (gravity * gMult) maxR -5)
        tableChange obj "vx" zerR ifelse-value table:get obj "onGround?" [ 0.25 ] [ 0.1 ]
      ]
      if not dead? and not won? [
        if py < (- h) [ loseLife ]
        collectCoins
        setMarioSprite
      ]
    ]
    [
      tableChange obj "px" addR vx
      tableChange obj "py" addR vy
      if collides? [ applyPhysics obj ]
      if (member? objType ["mushroom" "goomba" "koopa" "shell"]) and gMult != 0 [
        if vx = 0 [
          table:put obj "dir" (- table:get obj "dir")
          table:put obj "vx" table:get obj "dir"
          if objType = "koopa" [ tableChange obj "flipped?" [[f]-> not f] ]
        ]
      ]
      tableChange obj "vy" (compose subR (gravity * gMult) maxR -5)
    ]
    if collides? and px < w / 2 [
      table:put obj "px" w / 2
      table:put obj "vx" 0
    ]
    ifelse py < (- h) and obj != mario [
      removeObj obj
    ] [
      (ifelse objType = "bump" [
        if py mod 16 = 0 [
          table:remove objects table:get obj "id"
          setProperty tileCoord px tileCoord py 0 first table:get obj "sprites"
        ]
      ] objType = "mushroom" [
        ifelse gMult = 0 [
          if py mod 16 = 0 [
            table:put obj "vx" 1
            table:put obj "vy" 0
            table:put obj "gMult" 1
            table:put obj "background?" false
            table:put obj "collides?" true
          ]
        ] [
          if not dead? and not won? and objsOverlap obj mario [
            removeObj obj
            tableChange mario "current-sprite" [[i]-> 1 + 2 * floor (i / 2)]
            table:put mario "height" 30
            gamelogo:play-clip sPowerup
            set score score + 1000
          ]
        ]
      ] objType = "goomba" [
        checkHit obj
        tableChange obj "animationTimer" add1
        ifelse collides? [
          if table:get obj "animationTimer" > 6 [
            tableChange obj "flipped?" [[f]-> not f]
            table:put obj "animationTimer" 0
          ]
        ] [
          if table:get obj "animationTimer" > 24 [
            removeObj obj
          ]
        ]
      ] objType = "koopa" [
        checkHit obj
        tableChange obj "animationTimer" add1
        if table:get obj "animationTimer" > 6 [
          tableChange obj "current-sprite" [[i]-> 1 - i]
          table:put obj "animationTimer" 0
        ]
      ] objType = "shell" [
        if not dead? and not won? and collides? and objsOverlap obj mario [
          ifelse vx = 0 [
            table:put obj "dir" 3 * sign (px - table:get mario "px")
            table:put obj "vx" table:get obj "dir"
            gamelogo:play-clip sKick
            set score score + 100
            if not table:get mario "onGround?" [
              table:put mario "py" topSide
              table:put mario "vy" 4
            ]
          ] [
            (ifelse marioStomped? [
              gamelogo:play-clip sKick
              table:put obj "vx" 0
              table:put obj "dir" 0
              table:put mario "py" topSide
              table:put mario "vy" 4
            ] sign vx != sign (px - table:get mario "px")[
              damageMario
            ])
          ]
        ]
        if collides? and vx != 0 [
          foreach table:values objects [[otherObj]->
            if member? table:get otherObj "type" ["goomba" "koopa"] [
              if table:get-or-default otherObj "collides?" true and objsOverlap obj otherObj [
                killEnemy otherObj
              ]
            ]
          ]
        ]
      ] objType = "coin" [
        let aTimer table:get obj "animationTimer"
        ifelse aTimer > 20 [
          removeObj obj
        ] [
          table:put obj "current-sprite" (floor (aTimer / 4)) mod 4
          table:put obj "animationTimer" aTimer + 1
        ]
      ])
    ]
  ]
  if table:get mario "px" > 16 * length first world-map [
    win
  ]
  if dFrame < 150 [
    gamelogo:fill-world ifelse-value snaking? [ lerpC skyColor [0 0 0] 0.75 ] [ skyColor ]
    foreach table:values objects [[obj]->
      if table:get-or-default obj "background?" false [ drawObj obj ]
    ]
    drawLevel level
    foreach table:values objects [[obj]->
      if not table:get-or-default obj "background?" false
      and not (table:get obj "type" = "mario" and invFrames > 0 and ticks mod 4 < 2) [ drawObj obj ]
    ]
  ]
  if ticks mod 24 = 0 and not dead? and not won? [
    set time time - 1
    if time = 100 [
      gamelogo:play-clip sWarning
    ]
    if time = 0 [
      loseLife
    ]
  ]
  drawHUD
  if invFrames > 0 [ set invFrames invFrames - 1 ]
  tick
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
730
467
-1
-1
2.0
1
10
1
1
1
0
0
0
1
0
255
0
223
1
1
0
frames
60.0

BUTTON
16
27
76
60
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
102
28
165
61
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

TEXTBOX
11
92
183
218
Instructions:\nPress go, then:\n\nUse A and D to move left and right\nPress W to jump\nHold left Shift to sprint\nPress Space to toggle Snake\nPress Q while controlling snake to leave blocks behind (DISABLED)
11
0.0
1

BUTTON
28
278
169
311
stop music
gamelogo:stop-loop
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
11
224
183
257
levelN
levelN
1
3
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
