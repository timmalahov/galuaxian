-- Settings
local settings = {
  lowFps = false,
  targetSideMotion = true,
  fancyProjectile = true,
  easyMode = false,
  lowQuality = false
}
local targetSideMotionAmplitude = 2 -- better not make it bigger, otherwise targets will start to teleport side to side every other frame

-- Program
local shipPosition = {x = 0, y = 0}
local SCALE = 1
local actionAreaWidthStart = 0
local actionAreaHeightStart = LCD_H * 0.25
local backgroundSpeed = 2
local projectileCount = 3 -- 6
local targetCount = 4 -- 10
local targetWidth = 16
local targetHeight = 10
local projectileLength = 8
local gameOver = true
local targets = {}
local projectiles = {}
local backgrounds = {}
local lowBackgrounds = {}
local backgroundCount = 20
local bestResultPath = "/galuaxian-results.txt"
local debug = false -- true -> draw borders around objects
local shipCollisionMargin = 0
local fpsCounter = 0
local menuPage = false
local menuItemsCount = 4
local menuPosition = 0
local menuPadding = 2
local menuOpened = false -- dirty hack to avoid EVT_ENTER_BREAK trigger settings change on initial menu open

-- Returns color flag
local function getActiveColor(accent)
  if SCALE <= 1 or settings.lowQuality then
    return 0
  end
  if accent == "RED" then
    return RED
  end
  if accent == "YELLOW" then
    return RED
  end
  return WHITE
end

local function loadBestResult()
  local f = io.open(bestResultPath, "r")
  if f == nil then
    return nil
  end
  result = tonumber(io.read(f, 3))
  return result
end

local function saveBestResult(result)
   local f = io.open(bestResultPath, "w")
   io.write(f, string.format("%3d", result))
   io.close(f)
end

local function initWithScale(scale)
  shipWidth = 10 * scale
  shipHeight = 7 * scale
  projectileLength = scale * 4
  projectileWidth = scale * 2
  targetSideMotionAmplitude = scale * 0.5
  targetWidth = 4 * scale
  targetHeight = 4 * scale

  if SCALE > 1 then
    menuItemsCount = menuItemsCount + 1
  end

  if ship and not settings.lowQuality then
    shipWidth = 30 * scale
    shipHeight = 20 * scale
    targetWidth = 16 * scale
    targetHeight = 10 * scale
    shipCollisionMargin = 4 * scale
  end

  shipHalfWidth = shipWidth / 2
  targetHalfWidth = targetWidth / 2
  targetHalfHeight = targetHeight / 2

  actionAreaWidthEnd = LCD_W - shipWidth
  actionAreaHeightEnd = LCD_H - shipHeight
end

local function initBitmaps()
  ship = Bitmap.open('./IMAGES/ship.png')
  background = Bitmap.open('./IMAGES/back.png')
  target = Bitmap.open('./IMAGES/target.png')
end

local function init_func()
  pcall(initBitmaps)

  bestResult = loadBestResult()
  hits = 0
  gameStarted = false

  if LCD_W >= 480 then
    SCALE = 2
  end
  initWithScale(SCALE)

  if SCALE == 1 then
    for i = 0, projectileCount do
      projectiles[i] = { x = LCD_W/2, y = - LCD_H, velocity = -4, travelDistance = 1000, delay = i * (-4) }
    end
  else
    for i = 0, projectileCount do
      projectiles[i] = { x = LCD_W/2, y = - LCD_H, velocity = SCALE * (-10), travelDistance = 1000, delay = i * (-4) }
    end
  end

  for i = 0, targetCount do
    targets[i] = { x = math.random(0, LCD_W - targetWidth), y = math.random(0, LCD_H), sideVelocity = SCALE * 1, velocity = SCALE * 4, travelDistance = 1000, delay = i * (-4), dead = true }
  end

  for i = 0, 20 do
    lowBackgrounds[i] = { x = math.random(0, LCD_W), y = math.random(0, LCD_H) }
  end
  backgrounds[0] = { y = -LCD_H }
  backgrounds[1] = { y = 0 }

  initTime = getTime()
end

local function drawProjectile(projectile, x, y)
  if projectile.delay <= 0 then
    projectile.delay = projectile.delay + 1
    return
  end

  if projectile.travelDistance >= LCD_H then
    projectile.y = y
    projectile.x = x
    projectile.travelDistance = 0
  else
    projectile.y = projectile.y + projectile.velocity
    projectile.travelDistance = projectile.travelDistance + projectile.velocity * -1 -- because of negative velocity
  end

  if settings.fancyProjectile then -- /_|_\
    lcd.drawLine(projectile.x, projectile.y, projectile.x + projectileWidth / 2, projectile.y + projectileLength, SOLID, getActiveColor()) -- \
    lcd.drawLine(projectile.x + projectileWidth / 2, projectile.y + projectileLength, projectile.x - projectileWidth / 2, projectile.y + projectileLength, SOLID, getActiveColor("YELLOW")) -- __
    lcd.drawLine(projectile.x - projectileWidth / 2, projectile.y + projectileLength, projectile.x, projectile.y, SOLID, getActiveColor()) -- /
    lcd.drawLine(projectile.x, projectile.y, projectile.x, projectile.y + projectileLength, SOLID, getActiveColor("RED")) -- |
    return
  end

  lcd.drawRectangle(projectile.x - projectileWidth / 2, projectile.y, projectileWidth, projectileLength, getActiveColor())
end

local function drawShip(x, y)
  if debug then
    lcd.drawRectangle(x, y, shipWidth, shipHeight)
  end
  if ship and not settings.lowQuality then
    lcd.drawBitmap(ship, x, y, SCALE * 100)
    return 0
  end

  -- graphic fallback, primitive ship render
  lcd.drawLine(x + shipHalfWidth, y, x + shipWidth, y + shipHeight, SOLID, FORCE)
  lcd.drawLine(x + shipWidth, y + shipHeight, x + shipHalfWidth, y + shipHeight * 3 / 4, SOLID, FORCE)
  lcd.drawLine(x + shipHalfWidth, y + shipHeight * 3 / 4, x, y + shipHeight, SOLID, FORCE)
  lcd.drawLine(x, y + shipHeight, x + shipHalfWidth, y, SOLID, FORCE)
end

local function drawTarget(x, y)
  if debug then
    lcd.drawRectangle(x, y, targetWidth, targetHeight)
  end
  if target and not settings.lowQuality then
    lcd.drawBitmap(target, x, y, SCALE * 100)
    return 0
  end
  -- graphic fallback, primitive target render
  lcd.drawLine(x, y, x + targetHalfWidth, y + targetHalfWidth, SOLID, FORCE)
  lcd.drawLine(x + targetHalfWidth, y + targetHalfWidth, x + targetWidth, y, SOLID, FORCE)
  lcd.drawLine(x + targetWidth, y, x + targetHalfWidth, y + targetHeight, SOLID, FORCE)
  lcd.drawLine(x + targetHalfWidth, y + targetHeight, x, y, SOLID, FORCE)
end

local function drawBackground()
  if not background or settings.lowQuality then -- fallback to pixel stars
    for i = 0, backgroundCount do
      lowBackgrounds[i].y = lowBackgrounds[i].y + backgroundSpeed
      if lowBackgrounds[i].y == LCD_H then
        lowBackgrounds[i].y = 0
      end
      lcd.drawPoint(lowBackgrounds[i].x, lowBackgrounds[i].y)
    end
    return 0
  end

  for i = 0, 1 do
    backgrounds[i].y = backgrounds[i].y + backgroundSpeed
    if backgrounds[i].y == LCD_H then
      backgrounds[i].y = -LCD_H
    end
    lcd.drawBitmap(background, 0, backgrounds[i].y)
  end
end

local function detectOverlap(xl1, yl1, xl2, yl2, xr1, yr1, xr2, yr2) -- TODO pass an object instead
  --                    ┌─────────────┐r2
  --  -y                │      [ship] │
  --   △    ┌───────────┼───┐r1       │
  --   │    │ [target]  │   │         │
  --   │    │         l2└───┼─────────┘
  --   │    │               │
  --   │  l1└───────────────┘
  --   ┼────────────▷ x

  -- if rectangle has area 0, no overlap -- could be eliminated if we know rectangles have some area
  -- if xl1 == xr1 or yl1 == yr1 or xr2 == xl2 or yl2 == yr2 then
  --     return false
  -- end

  -- If one rectangle is on left side of other
  if xl1 > xr2 or xl2 > xr1 then
    return false
  end

  -- If one rectangle is above other
  if yr1 > yl2 or yr2 > yl1 then
    return false
  end
  return true
end

local function drawTargets()
  for i = 0, targetCount do
    targets[i].y = targets[i].y + targets[i].velocity

    if settings.targetSideMotion then
      targets[i].x = targets[i].x + targets[i].sideVelocity + math.random(targetSideMotionAmplitude * -1, targetSideMotionAmplitude)

      if targets[i].x <= shipHalfWidth or targets[i].x + targetWidth > LCD_W - shipHalfWidth then -- detect wall approach and reverse side motion direction
        targets[i].sideVelocity = targets[i].sideVelocity * -1
      end
    end

    for j = 0, projectileCount do -- projectile/target collision detection, forgiving hitboxes
      if not targets[i].dead
              and projectiles[j].x >= targets[i].x - 10
              and projectiles[j].x + projectileWidth <= targets[i].x + targetWidth + 10
              and projectiles[j].y >= targets[i].y - (projectileLength + projectiles[j].velocity * -1) -- adjustement for projectile skips
              and projectiles[j].y <= targets[i].y + targetHeight + projectiles[j].velocity * -1 then
        targets[i].dead = true
        targets[i].sideVelocity = targets[i].sideVelocity * -1
        playTone(450, 50, 0)
        hits = hits + 1
      end
    end

    if not targets[i].dead and (detectOverlap(
            targets[i].x + shipCollisionMargin, -- l1
            targets[i].y,
            shipPosition.x, -- l2
            shipPosition.y + shipCollisionMargin,
            targets[i].x + targetWidth - shipCollisionMargin, -- r1
            targets[i].y - targetHeight,
            shipPosition.x + shipWidth - shipCollisionMargin, -- r2
            shipPosition.y + shipCollisionMargin - shipHeight
    )) then
      gameOver = true
      playHaptic(50, 0, PLAY_NOW)
    end

    if targets[i].y >= LCD_H then
      local offset = shipHalfWidth
      targets[i].y = -targetHeight
      targets[i].x = math.random(offset, LCD_W - targetWidth - offset)
      if not targets[i].dead then
        hits = hits - 1
        playTone(150, 50, 0)
      end
      targets[i].dead = false
    end

    if not targets[i].dead then
      drawTarget(targets[i].x, targets[i].y)
    end
  end
end

local function mapInputToActionAreaPosition(value, newRangeStart, newRangeEnd)
  return newRangeStart + (newRangeEnd - newRangeStart) * ((value + 1024) / 2048); -- 2048 - stick input rage
end

local function renderHome(event)
  if SCALE == 1 then -- smaller screen -- bad lazy duplicacy -- TODO refactor if you feel like it
    if gameStarted then
      lcd.drawText(LCD_W / 2 - 40, LCD_H / 4, "Game Over", BOLD + MIDSIZE )
      lcd.drawText(LCD_W / 2 - 40, LCD_H * 2 / 4, string.format("Points: %.0f", hits), BOLD)

      if (not bestResult) or (hits > bestResult) then
        saveBestResult(hits)
      end
    else
      lcd.drawScreenTitle("[GaLuaxian]", 0, 0)
      lcd.drawText(LCD_W / 2 - 40, LCD_H / 4, "SHOOT 'EM UP!")
      if bestResult then
        lcd.drawText(LCD_W / 2 - 40, LCD_H / 4 + 12, string.format("Best result: %.0f", bestResult))
      end
    end

    lcd.drawText(4, LCD_H - 20 , "Press [Enter] to start", BOLD + BLINK)
    lcd.drawText(10, LCD_H - 10 , "(Hold for settings)", BOLD)
    return 0
  else -- big screen size
    if gameStarted then
      lcd.drawText(LCD_W / 2 - 80, LCD_H / 2 - 40, "Game Over", BOLD + MIDSIZE + getActiveColor("RED") )
      lcd.drawText(LCD_W / 2 - 80, LCD_H * 2 / 3 - 40, string.format("Points: %.0f", hits), BOLD + SMLSIZE + getActiveColor())

      if (not bestResult) or (hits > bestResult) then
        saveBestResult(hits)
      end
    else
      lcd.drawRectangle(LCD_W / 2 - 90, LCD_H / 2 - 48, 170, 60, SOLID + getActiveColor())
      lcd.drawRectangle(LCD_W / 2 - 88, LCD_H / 2 - 46, 170, 60, SOLID + getActiveColor("YELLOW"))

      -- lcd.drawLine(LCD_W / 2 - 95, LCD_H / 2 + 18, LCD_W / 2 - 90 + 170 + 5, LCD_H / 2 + 18, SOLID, FORCE)
      -- lcd.drawLine(LCD_W / 2 - 100, LCD_H / 2 + 23, LCD_W / 2 - 90 + 170 + 10, LCD_H / 2 + 23, SOLID, FORCE)

      lcd.drawText(LCD_W / 2 - 75, LCD_H / 2 - 40, "Galuaxian", BOLD + MIDSIZE + getActiveColor() )
      lcd.drawText(LCD_W / 2 - 75, LCD_H / 2 - 10, "SHOOT 'EM UP!", SMLSIZE + getActiveColor())
      if bestResult then
        lcd.drawText(LCD_W / 2 - 60, LCD_H / 2 + 60, string.format("Best result: %.0f", bestResult), SMLSIZE + getActiveColor())
      end
    end

    lcd.drawText(LCD_W / 3 + 4, LCD_H - 53, "Press [Enter] to start", BOLD + BLINK + getActiveColor())
    lcd.drawText(LCD_W / 3, LCD_H - 30, "Hold [Enter] for settings", BOLD + getActiveColor())
    return 0
  end
end

local function drawTick(x,y)
  lcd.drawLine(x + menuPadding + 3, y + menuPadding + 5, x + 9, y + 13, SOLID, getActiveColor())
  lcd.drawLine(x + 9, y + 13, x + 17, y + menuPadding + 3, SOLID, getActiveColor())
  -- bold
  lcd.drawLine(x + menuPadding + 3, y + menuPadding + 6, x + 9, y + 14, SOLID, getActiveColor())
  lcd.drawLine(x + 9, y + 14, x + 17, y + menuPadding + 4, SOLID, getActiveColor())
end

local function drawBooleanField(x,y, text, value) -- selected
  lcd.drawText(x + menuPadding, y + menuPadding, text, getActiveColor())
  lcd.drawRectangle(LCD_W - menuPadding - 19, y + menuPadding, 19, 19, getActiveColor())
  lcd.drawRectangle(LCD_W - menuPadding - 18, y + menuPadding + 1, 17, 17, getActiveColor())

  if value then
    drawTick(LCD_W - 23, y + menuPadding)
  end
end

local function drawLowScaleTick(x,y)
  lcd.drawLine(x-1, y+2, x+3, y+5, SOLID, FORCE)
  lcd.drawLine(x+3, y+5, x + 8, y - 1, SOLID, FORCE)
  -- lcd.drawLine(x + menuPadding + 3, y + menuPadding + 6, x + 9, y + 14, SOLID, FORCE)
  -- lcd.drawLine(x + 9, y + 14, x + 17, y + menuPadding + 4, SOLID, FORCE)
end

local function drawLowScaleBooleanField(x,y, text, value) -- selected
  lcd.drawText(x + menuPadding, y + menuPadding, text)
  lcd.drawRectangle(LCD_W - menuPadding - 8, y + menuPadding, 8, 8)
  -- lcd.drawRectangle(LCD_W - menuPadding - 8, y + menuPadding + 1, 17, 17)

  if value then
    drawLowScaleTick(LCD_W - 10, y + menuPadding)
  end
end

local function renderMenu(event)
  if event == EVT_ROT_LEFT or event == EVT_MINUS_FIRST then
    menuPosition = menuPosition - 1
    if menuPosition < 0 then
      menuPosition = menuItemsCount - 1
    end
  end
  if event == EVT_ROT_RIGHT or event == EVT_PLUS_FIRST then
    menuPosition = menuPosition + 1
    if menuPosition > menuItemsCount - 1 then
      menuPosition = 0
    end
  end
  if event == EVT_ENTER_BREAK and menuPage then -- very bad menu items handling
    if menuPosition == 0 and menuOpened then
      settings.lowFps = not settings.lowFps
    end
    if menuPosition == 1 and menuOpened then
      settings.targetSideMotion = not settings.targetSideMotion
    end
    if menuPosition == 2 and menuOpened then
      settings.fancyProjectile = not settings.fancyProjectile
    end
    if menuPosition == 3 and menuOpened then
      settings.easyMode = not settings.easyMode
    end
    if menuPosition == 4 and menuOpened then
      settings.lowQuality = not settings.lowQuality
    end
    menuOpened = true
  end
  if event == EVT_EXIT_BREAK then -- exit the settings menu
    menuPage = false
    menuOpened = false
  end

  if SCALE > 1 then
    lcd.drawFilledRectangle(0, 0, LCD_W, 40, getActiveColor())
    lcd.drawText(0, 0, "Settings",  BOLD + MIDSIZE + INVERS + getActiveColor())
    drawBooleanField(2,47,"Low FPS: ", settings.lowFps)
    drawBooleanField(2,76,"Target side motion: ", settings.targetSideMotion)
    drawBooleanField(2,105,"Fancy projectile: ", settings.fancyProjectile)
    drawBooleanField(2, 134,"Easy mode: ", settings.easyMode)
    drawBooleanField(2, 163,"Low Quality: ", settings.lowQuality)
    lcd.drawRectangle(1, 46 + 29 * menuPosition, LCD_W - 1, 25, SOLID + getActiveColor()) -- selected field frame
    return 0
  end

  lcd.drawScreenTitle("Settings", 0, 0)
  drawLowScaleBooleanField(2,11,"Low FPS: ", settings.lowFps)
  drawLowScaleBooleanField(2,22,"Target side motion: ", settings.targetSideMotion)
  drawLowScaleBooleanField(2,33,"Fancy projectile: ", settings.fancyProjectile)
  drawLowScaleBooleanField(2,44,"Easy mode: ", settings.easyMode)
  lcd.drawRectangle(0, 11 + 11 * menuPosition, LCD_W, 12, SOLID) -- selected field frame
end

local function run_func(event)
  shipPosition.x = mapInputToActionAreaPosition(getValue('ail'), actionAreaWidthStart, actionAreaWidthEnd) -- roll (left-right)
  shipPosition.y = mapInputToActionAreaPosition(getValue('ele') * -1, actionAreaHeightStart, actionAreaHeightEnd) -- pitch (up/down)
  currentTime = getTime()
  timerValue = (currentTime - initTime) / 100 + 1

  if gameOver == true then
    lcd.clear()
    drawBackground()

    if not menuPage then
      renderHome(event)
    else
      renderMenu(event)
    end

    if event == EVT_ENTER_BREAK and not menuPage then
      gameOver = false
      gameStarted = true
      hits = 0
      for i = 0, targetCount do
        targets[i].dead = true
      end
    end
    if event == EVT_ENTER_LONG then
      menuPage = true
    end
    return 0
  end

  if settings.easyMode and targetCount ~= 2 then
    for i = 0, targetCount do
      targets[i].velocity = SCALE * 1
    end
    targetCount = 2
  end

  if not settings.easyMode and targetCount ~= 4 then
    targetCount = 4
    for i = 0, targetCount do
      targets[i].velocity = SCALE * 4
    end
  end

  if event == EVT_EXIT_BREAK then
    gameOver = true
  end

  if settings.lowFps then
    fpsCounter = fpsCounter + 1
    if fpsCounter == 2 then
      fpsCounter = 0
      return 0 -- basically skip every other frame
    end
  end

  lcd.clear()
  drawBackground()

  lcd.drawText(1, 1,string.format("TOTAL HITS:  %.0f", hits), INVERS)
  drawShip(shipPosition.x, shipPosition.y)

  for i = 0, projectileCount do
    drawProjectile(projectiles[i], shipPosition.x + shipHalfWidth, shipPosition.y)
  end

  drawTargets()
  return 0
end

return { init=init_func, run=run_func }
