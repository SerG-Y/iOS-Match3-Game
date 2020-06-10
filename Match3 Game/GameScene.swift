//
//  GameScene.swift
//  Match3 Game
//
//  Created by Serhiy Yashchuk
//

import SpriteKit

class GameScene: SKScene {
  
  var level: Level!
  
  let tileWidth: CGFloat = 32.0
  let tileHeight: CGFloat = 36.0
  
  let gameLayer = SKNode()
  let cookiesLayer = SKNode()
  
  let tilesLayer = SKNode()
  let cropLayer = SKCropNode()
  let maskLayer = SKNode()
  
  let swapSound = SKAction.playSoundFileNamed("Chomp.wav", waitForCompletion: false)
  let invalidSwapSound = SKAction.playSoundFileNamed("Error.wav", waitForCompletion: false)
  let matchSound = SKAction.playSoundFileNamed("Ka-Ching.wav", waitForCompletion: false)
  let fallingCookieSound = SKAction.playSoundFileNamed("Scrape.wav", waitForCompletion: false)
  let addCookieSound = SKAction.playSoundFileNamed("Drip.wav", waitForCompletion: false)
  
  var swipeHandler: ((Swap) -> Void)?
  
  private var swipeFromColumn: Int?
  private var swipeFromRow: Int?
  
  private var selectionSprite = SKSpriteNode()
  
  override init(size: CGSize) {
    super.init(size: size)
    
    anchorPoint = CGPoint(x: 0.5, y: 0.5)
    
    let background = SKSpriteNode(imageNamed: "Background")
    background.size = size
    
    addChild(background)
    addChild(gameLayer)
    gameLayer.isHidden = true
    
    let layerPosition = CGPoint(
      x: -tileWidth * CGFloat(numColumns) / 2,
      y: -tileHeight * CGFloat(numRows) / 2
    )
    
    tilesLayer.position = layerPosition
    maskLayer.position = layerPosition
    cropLayer.maskNode = maskLayer
    
    gameLayer.addChild(tilesLayer)
    gameLayer.addChild(cropLayer)
    
    cookiesLayer.position = layerPosition
    cropLayer.addChild(cookiesLayer)
    
    let _ = SKLabelNode(fontNamed: "GillSans-BoldItalic")
  }
  
  func addSprites(for cookies: Set<Cookie>) {
    for cookie in cookies {
      let sprite = SKSpriteNode(imageNamed: cookie.cookieType.spriteName)
      
      sprite.size = CGSize(width: tileWidth, height: tileHeight)
      sprite.position = pointFor(column: cookie.column, row: cookie.row)
      cookiesLayer.addChild(sprite)
      cookie.sprite = sprite
      
      // Give each cookie sprite a small, random delay. Then fade them in.
      sprite.alpha = 0
      sprite.xScale = 0.5
      sprite.yScale = 0.5
      
      sprite.run(
        SKAction.sequence([
          SKAction.wait(forDuration: 0.25, withRange: 0.5),
          SKAction.group([
            SKAction.fadeIn(withDuration: 0.25),
            SKAction.scale(to: 1.0, duration: 0.25)
          ])
        ]))
    }
  }
  
  private func pointFor(column: Int, row: Int) -> CGPoint {
    return CGPoint(
      x: CGFloat(column) * tileWidth + tileWidth / 2,
      y: CGFloat(row) * tileHeight + tileHeight / 2
    )
  }
  
  func addTiles() {
    for row in 0 ..< numRows {
      for column in 0 ..< numColumns {
        if level.tileAt(column: column, row: row) != nil {
          let tileNode = SKSpriteNode(imageNamed: "MaskTile")
          tileNode.size = CGSize(width: tileWidth, height: tileHeight)
          tileNode.position = pointFor(column: column, row: row)
          maskLayer.addChild(tileNode)
        }
      }
    }
    
    for row in 0 ... numRows {
      for column in 0 ... numColumns {
        let topLeft = (column > 0) && (row < numRows)
          && level.tileAt(column: column - 1, row: row) != nil
        let bottomLeft = (column > 0) && (row > 0)
          && level.tileAt(column: column - 1, row: row - 1) != nil
        let topRight = (column < numColumns) && (row < numRows)
          && level.tileAt(column: column, row: row) != nil
        let bottomRight = (column < numColumns) && (row > 0)
          && level.tileAt(column: column, row: row - 1) != nil
        
        var value = topLeft.intVal
        value = value | topRight.intVal << 1
        value = value | bottomLeft.intVal << 2
        value = value | bottomRight.intVal << 3
        
        if value != 0 && value != 6 && value != 9 {
          let name = String(format: "Tile_%ld", value)
          let tileNode = SKSpriteNode(imageNamed: name)
          
          tileNode.size = CGSize(width: tileWidth, height: tileHeight)
          var point = pointFor(column: column, row: row)
          point.x -= tileWidth / 2
          point.y -= tileHeight / 2
          tileNode.position = point
          tilesLayer.addChild(tileNode)
        }
      }
    }
  }
  
  private func convertPoint(_ point: CGPoint) -> (success: Bool, column: Int, row: Int) {
    if point.x >= 0 && point.x < CGFloat(numColumns) * tileWidth &&
      point.y >= 0 && point.y < CGFloat(numRows) * tileHeight {
      return (true, Int(point.x / tileWidth), Int(point.y / tileHeight))
    } else {
      return (false, 0, 0)  // invalid location
    }
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let location = touch.location(in: cookiesLayer)
    let (success, column, row) = convertPoint(location)
    
    if success {
      if let cookie = level.cookie(atColumn: column, row: row) {
        swipeFromColumn = column
        swipeFromRow = row
        showSelectionIndicator(of: cookie)
      }
    }
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard swipeFromColumn != nil else { return }
    guard let touch = touches.first else { return }
    let location = touch.location(in: cookiesLayer)
    let (success, column, row) = convertPoint(location)
    
    if success {
      var horizontalDelta = 0, verticalDelta = 0
      
      if column < swipeFromColumn! {          // swipe left
        horizontalDelta = -1
      } else if column > swipeFromColumn! {   // swipe right
        horizontalDelta = 1
      } else if row < swipeFromRow! {         // swipe down
        verticalDelta = -1
      } else if row > swipeFromRow! {         // swipe up
        verticalDelta = 1
      }
      
      if horizontalDelta != 0 || verticalDelta != 0 {
        trySwap(horizontalDelta: horizontalDelta, verticalDelta: verticalDelta)
        hideSelectionIndicator()
        swipeFromColumn = nil
      }
    }
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    if selectionSprite.parent != nil && swipeFromColumn != nil {
      hideSelectionIndicator()
    }
    
    swipeFromColumn = nil
    swipeFromRow = nil
  }
  
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    touchesEnded(touches, with: event)
  }
  
  private func trySwap(horizontalDelta: Int, verticalDelta: Int) {
    let toColumn = swipeFromColumn! + horizontalDelta
    let toRow = swipeFromRow! + verticalDelta
    
    guard toColumn >= 0 && toColumn < numColumns else { return }
    guard toRow >= 0 && toRow < numRows else { return }
    
    if let toCookie = level.cookie(atColumn: toColumn, row: toRow),
      let fromCookie = level.cookie(atColumn: swipeFromColumn!, row: swipeFromRow!) {
      
      if let handler = swipeHandler {
        let swap = Swap(cookieA: fromCookie, cookieB: toCookie)
        handler(swap)
      }
    }
  }
  
  func animate(_ swap: Swap, completion: @escaping () -> Void) {
    let spriteA = swap.cookieA.sprite!
    let spriteB = swap.cookieB.sprite!
    
    spriteA.zPosition = 100
    spriteB.zPosition = 90
    
    let duration: TimeInterval = 0.3
    
    let moveA = SKAction.move(to: spriteB.position, duration: duration)
    moveA.timingMode = .easeOut
    spriteA.run(moveA, completion: completion)
    
    let moveB = SKAction.move(to: spriteA.position, duration: duration)
    moveB.timingMode = .easeOut
    spriteB.run(moveB)
    
    run(swapSound)
  }
  
  func animateInvalidSwap(_ swap: Swap, completion: @escaping () -> Void) {
    let spriteA = swap.cookieA.sprite!
    let spriteB = swap.cookieB.sprite!
    
    spriteA.zPosition = 100
    spriteB.zPosition = 90
    
    let duration: TimeInterval = 0.2
    
    let moveA = SKAction.move(to: spriteB.position, duration: duration)
    moveA.timingMode = .easeOut
    
    let moveB = SKAction.move(to: spriteA.position, duration: duration)
    moveB.timingMode = .easeOut
    
    spriteA.run(SKAction.sequence([moveA, moveB]), completion: completion)
    spriteB.run(SKAction.sequence([moveB, moveA]))
    
    run(invalidSwapSound)
  }
  
  func showSelectionIndicator(of cookie: Cookie) {
    if selectionSprite.parent != nil {
      selectionSprite.removeFromParent()
    }
    
    if let sprite = cookie.sprite {
      let texture = SKTexture(imageNamed: cookie.cookieType.highlightedSpriteName)
      selectionSprite.size = CGSize(width: tileWidth, height: tileHeight)
      selectionSprite.run(SKAction.setTexture(texture))
      
      sprite.addChild(selectionSprite)
      selectionSprite.alpha = 1.0
    }
  }
  
  func hideSelectionIndicator() {
    selectionSprite.run(SKAction.sequence([
      SKAction.fadeOut(withDuration: 0.3),
      SKAction.removeFromParent()]))
  }
  
  func animateMatchedCookies(for chains: Set<Chain>, completion: @escaping () -> Void) {
    for chain in chains {
      animateScore(for: chain)
      
      for cookie in chain.cookies {
        if let sprite = cookie.sprite {
          if sprite.action(forKey: "removing") == nil {
            let scaleAction = SKAction.scale(to: 0.1, duration: 0.3)
            scaleAction.timingMode = .easeOut
            sprite.run(SKAction.sequence([scaleAction, SKAction.removeFromParent()]),
                       withKey: "removing")
          }
        }
      }
    }
    
    run(matchSound)
    run(SKAction.wait(forDuration: 0.3), completion: completion)
  }
  
  func animateFallingCookies(in columns: [[Cookie]], completion: @escaping () -> Void) {
    var longestDuration: TimeInterval = 0
    for array in columns {
      for (index, cookie) in array.enumerated() {
        let newPosition = pointFor(column: cookie.column, row: cookie.row)
        let delay = 0.05 + 0.15 * TimeInterval(index)
        let sprite = cookie.sprite!
        let duration = TimeInterval(((sprite.position.y - newPosition.y) / tileHeight) * 0.1)
        
        longestDuration = max(longestDuration, duration + delay)
        
        let moveAction = SKAction.move(to: newPosition, duration: duration)
        moveAction.timingMode = .easeOut
        sprite.run(
          SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.group([moveAction, fallingCookieSound])])
        )
      }
    }
    
    run(SKAction.wait(forDuration: longestDuration), completion: completion)
  }
  
  func animateNewCookies(in columns: [[Cookie]], completion: @escaping () -> Void) {
    var longestDuration: TimeInterval = 0
    
    for array in columns {
      let startRow = array[0].row + 1
      
      for (index, cookie) in array.enumerated() {
        let sprite = SKSpriteNode(imageNamed: cookie.cookieType.spriteName)
        
        sprite.size = CGSize(width: tileWidth, height: tileHeight)
        sprite.position = pointFor(column: cookie.column, row: startRow)
        cookiesLayer.addChild(sprite)
        cookie.sprite = sprite

        let delay = 0.1 + 0.2 * TimeInterval(array.count - index - 1)
        let duration = TimeInterval(startRow - cookie.row) * 0.1
        
        longestDuration = max(longestDuration, duration + delay)

        let newPosition = pointFor(column: cookie.column, row: cookie.row)
        let moveAction = SKAction.move(to: newPosition, duration: duration)
        moveAction.timingMode = .easeOut
        sprite.alpha = 0
        sprite.run(
          SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.group([
              SKAction.fadeIn(withDuration: 0.05),
              moveAction,
              addCookieSound])
          ]))
      }
    }

    run(SKAction.wait(forDuration: longestDuration), completion: completion)
  }
  
  func animateScore(for chain: Chain) {
    // Figure out what the midpoint of the chain is
    let firstSprite = chain.firstCookie().sprite!
    let lastSprite = chain.lastCookie().sprite!
    let centerPosition = CGPoint(
      x: (firstSprite.position.x + lastSprite.position.x)/2,
      y: (firstSprite.position.y + lastSprite.position.y)/2 - 8)
    
    // Add a label for the score that slowly floats up
    let scoreLabel = SKLabelNode(fontNamed: "GillSans-BoldItalic")
    scoreLabel.fontSize = 16
    scoreLabel.text = String(format: "%ld", chain.score)
    scoreLabel.position = centerPosition
    scoreLabel.zPosition = 300
    cookiesLayer.addChild(scoreLabel)
    
    let moveAction = SKAction.move(by: CGVector(dx: 0, dy: 3), duration: 0.7)
    moveAction.timingMode = .easeOut
    scoreLabel.run(SKAction.sequence([moveAction, SKAction.removeFromParent()]))
  }
  
  func animateGameOver(_ completion: @escaping () -> Void) {
    let action = SKAction.move(by: CGVector(dx: 0, dy: -size.height), duration: 0.3)
    action.timingMode = .easeIn
    gameLayer.run(action, completion: completion)
  }
  
  func animateBeginGame(_ completion: @escaping () -> Void) {
    gameLayer.isHidden = false
    gameLayer.position = CGPoint(x: 0, y: size.height)
    let action = SKAction.move(by: CGVector(dx: 0, dy: -size.height), duration: 0.3)
    action.timingMode = .easeOut
    gameLayer.run(action, completion: completion)
  }
  
  func removeAllCookieSprites() {
    cookiesLayer.removeAllChildren()
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder: NSCoder) has not been implemented")
  }
}

extension Bool {
  var intVal: Int {
    return self ? 1 : 0
  }
}
