//
//  LevelData.swift
//  Match3 Game
//
//  Created by Serhiy Yashchuk
//

import Foundation

class LevelData: Codable {
  
  let tiles: [[Int]]
  let targetScore: Int
  let moves: Int
  
  static func loadFrom(file filename: String) -> LevelData? {
    var data: Data
    var levelData: LevelData?
    
    if let path = Bundle.main.url(forResource: filename, withExtension: "json") {
      do {
        data = try Data(contentsOf: path)
      } catch {
        print("Could not load level file: \(filename), error: \(error)")
        return nil
      }
      
      do {
        levelData = try JSONDecoder().decode(LevelData.self, from: data)
      } catch {
        print("Level file '\(filename)' is not valid JSON: \(error)")
        return nil
      }
    }
    
    return levelData
  }
}
