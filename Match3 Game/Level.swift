//
//  LevelSwift.swift
//  Match3 Game
//
//  Created by Serhiy Yashchuk
//

import Foundation

let numColumns = 9
let numRows = 9
let numLevels = 4

class Level {
  
  private var cookies = Grid2D<Cookie>(columns: numColumns, rows: numRows)
  private var tiles = Grid2D<Tile>(columns: numColumns, rows: numRows)
  private var possibleSwaps: Set<Swap> = []
  private var comboMultiplier = 0
  var targetScore = 0
  var maximumMoves = 0

  init(filename: String) {
    guard let levelData = LevelData.loadFrom(file: filename) else { return }
    let tilesGrid = levelData.tiles
    
    for (row, rowArray) in tilesGrid.enumerated() {
      let tileRow = numRows - row - 1
      
      for (column, value) in rowArray.enumerated() {
        if value == 1 {
          tiles[column, tileRow] = Tile()
        }
      }
    }
    
    targetScore = levelData.targetScore
    maximumMoves = levelData.moves
  }
  
  func cookie(atColumn column: Int, row: Int) -> Cookie? {
    precondition(column >= 0 && column < numColumns)
    precondition(row >= 0 && row < numRows)
    
    return cookies[column, row]
  }
  
  func shuffle() -> Set<Cookie> {
    var set: Set<Cookie>
    
    repeat {
      set = createInitialCookies()
      detectPossibleSwaps()
      print("possible swaps: \(possibleSwaps)")
    } while possibleSwaps.count == 0
    
    return set
  }
  
  func detectPossibleSwaps() {
    var set: Set<Swap> = []
    
    for row in 0..<numRows {
      for column in 0..<numColumns {
        if let cookie = cookies[column, row] {
          if column < numColumns - 1,
            let other = cookies[column + 1, row] {
            // Swap them
            cookies[column, row] = other
            cookies[column + 1, row] = cookie
            
            // Is either cookie now part of a chain?
            if hasChain(atColumn: column + 1, row: row) ||
              hasChain(atColumn: column, row: row) {
              set.insert(Swap(cookieA: cookie, cookieB: other))
            }
            
            // Swap them back
            cookies[column, row] = cookie
            cookies[column + 1, row] = other
          }
          
          if row < numRows - 1,
            let other = cookies[column, row + 1] {
            cookies[column, row] = other
            cookies[column, row + 1] = cookie
            
            // Is either cookie now part of a chain?
            if hasChain(atColumn: column, row: row + 1) ||
              hasChain(atColumn: column, row: row) {
              set.insert(Swap(cookieA: cookie, cookieB: other))
            }
            
            // Swap them back
            cookies[column, row] = cookie
            cookies[column, row + 1] = other
          }
        }
        else if column == numColumns - 1, let cookie = cookies[column, row] {
          if row < numRows - 1,
            let other = cookies[column, row + 1] {
            cookies[column, row] = other
            cookies[column, row + 1] = cookie
            
            // Is either cookie now part of a chain?
            if hasChain(atColumn: column, row: row + 1) ||
              hasChain(atColumn: column, row: row) {
              set.insert(Swap(cookieA: cookie, cookieB: other))
            }
            
            // Swap them back
            cookies[column, row] = cookie
            cookies[column, row + 1] = other
          }
          
          
        }
      }
    }
    
    possibleSwaps = set
  }
  
  private func hasChain(atColumn column: Int, row: Int) -> Bool {
    let cookieType = cookies[column, row]!.cookieType
    
    // Horizontal chain check
    var horizontalLength = 1
    
    // Left
    var i = column - 1
    while i >= 0 && cookies[i, row]?.cookieType == cookieType {
      i -= 1
      horizontalLength += 1
    }
    
    // Right
    i = column + 1
    while i < numColumns && cookies[i, row]?.cookieType == cookieType {
      i += 1
      horizontalLength += 1
    }
    if horizontalLength >= 3 { return true }
    
    // Vertical chain check
    var verticalLength = 1
    
    // Down
    i = row - 1
    while i >= 0 && cookies[column, i]?.cookieType == cookieType {
      i -= 1
      verticalLength += 1
    }
    
    // Up
    i = row + 1
    while i < numRows && cookies[column, i]?.cookieType == cookieType {
      i += 1
      verticalLength += 1
    }
    return verticalLength >= 3
  }
  
  func isPossibleSwap(_ swap: Swap) -> Bool {
    return possibleSwaps.contains(swap)
  }
  
  private func createInitialCookies() -> Set<Cookie> {
    var set: Set<Cookie> = []
    
    for row in 0 ..< numRows {
      for column in 0 ..< numColumns {
        if tiles[column, row] != nil {
          var cookieType: CookieType
          repeat {
            cookieType = CookieType.random()
          } while (column >= 2 &&
            cookies[column - 1, row]?.cookieType == cookieType &&
            cookies[column - 2, row]?.cookieType == cookieType)
            || (row >= 2 &&
              cookies[column, row - 1]?.cookieType == cookieType &&
              cookies[column, row - 2]?.cookieType == cookieType)
          
          let cookie = Cookie(column: column, row: row, cookieType: cookieType)
          
          cookies[column, row] = cookie
          set.insert(cookie)
        }
      }
    }
    
    return set
  }
  
  func tileAt(column: Int, row: Int) -> Tile? {
    precondition(column >= 0 && column < numColumns)
    precondition(row >= 0 && row < numRows)
    return tiles[column, row]
  }
  
  func performSwap(_ swap: Swap) {
    let columnA = swap.cookieA.column
    let rowA = swap.cookieA.row
    let columnB = swap.cookieB.column
    let rowB = swap.cookieB.row
    
    cookies[columnA, rowA] = swap.cookieB
    swap.cookieB.column = columnA
    swap.cookieB.row = rowA
    
    cookies[columnB, rowB] = swap.cookieA
    swap.cookieA.column = columnB
    swap.cookieA.row = rowB
  }
  
  private func detectHorizontalMatches() -> Set<Chain> {
    var set: Set<Chain> = []

    for row in 0..<numRows {
      var column = 0
      while column < numColumns-2 {

        if let cookie = cookies[column, row] {
          let matchType = cookie.cookieType

          if cookies[column + 1, row]?.cookieType == matchType &&
            cookies[column + 2, row]?.cookieType == matchType {

            let chain = Chain(chainType: .horizontal)
            repeat {
              chain.add(cookie: cookies[column, row]!)
              column += 1
            } while column < numColumns && cookies[column, row]?.cookieType == matchType

            set.insert(chain)
            continue
          }
        }

        column += 1
      }
    }
    return set
  }
  
  private func detectVerticalMatches() -> Set<Chain> {
    var set: Set<Chain> = []

    for column in 0..<numColumns {
      var row = 0
      while row < numRows-2 {
        if let cookie = cookies[column, row] {
          let matchType = cookie.cookieType

          if cookies[column, row + 1]?.cookieType == matchType &&
            cookies[column, row + 2]?.cookieType == matchType {
            let chain = Chain(chainType: .vertical)
            repeat {
              chain.add(cookie: cookies[column, row]!)
              row += 1
            } while row < numRows && cookies[column, row]?.cookieType == matchType

            set.insert(chain)
            continue
          }
        }
        row += 1
      }
    }
    return set
  }
  
  func removeMatches() -> Set<Chain> {
    let horizontalChains = detectHorizontalMatches()
    let verticalChains = detectVerticalMatches()

    removeCookies(in: horizontalChains)
    removeCookies(in: verticalChains)
    calculateScores(for: horizontalChains)
    calculateScores(for: verticalChains)
    
    return horizontalChains.union(verticalChains)
  }
  
  private func removeCookies(in chains: Set<Chain>) {
    for chain in chains {
      for cookie in chain.cookies {
        cookies[cookie.column, cookie.row] = nil
      }
    }
  }
  
  func fillHoles() -> [[Cookie]] {
      var columns: [[Cookie]] = []

      for column in 0..<numColumns {
        var array: [Cookie] = []
        for row in 0..<numRows {
          if tiles[column, row] != nil && cookies[column, row] == nil {
            for lookup in (row + 1)..<numRows {
              if let cookie = cookies[column, lookup] {
                cookies[column, lookup] = nil
                cookies[column, row] = cookie
                cookie.row = row
                array.append(cookie)
                break
              }
            }
          }
        }
        
        if !array.isEmpty {
          columns.append(array)
        }
      }
      return columns
  }
  
  func topUpCookies() -> [[Cookie]] {
    var columns: [[Cookie]] = []
    var cookieType: CookieType = .unknown

    for column in 0..<numColumns {
      var array: [Cookie] = []

      var row = numRows - 1
      while row >= 0 && cookies[column, row] == nil {
        if tiles[column, row] != nil {
          var newCookieType: CookieType
          repeat {
            newCookieType = CookieType.random()
          } while newCookieType == cookieType
          cookieType = newCookieType

          let cookie = Cookie(column: column, row: row, cookieType: cookieType)
          cookies[column, row] = cookie
          array.append(cookie)
        }

        row -= 1
      }

      if !array.isEmpty {
        columns.append(array)
      }
    }
    return columns
  }
  
 private func calculateScores(for chains: Set<Chain>) {
    // 3-chain is 60 pts, 4-chain is 120, 5-chain is 180, and so on
    for chain in chains {
      chain.score = 60 * (chain.length - 2) * comboMultiplier
      comboMultiplier += 1
    }
  }
  
  func resetComboMultiplier() {
    comboMultiplier = 1
  }
}
