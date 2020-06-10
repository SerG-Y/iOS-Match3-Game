//
//  Swap.swift
//  Match3 Game
//
//  Created by Serhiy Yashchuk

import Foundation

struct Swap: CustomStringConvertible, Hashable {
  
  let cookieA: Cookie
  let cookieB: Cookie
  
  init(cookieA: Cookie, cookieB: Cookie) {
    self.cookieA = cookieA
    self.cookieB = cookieB
  }
  
  var description: String {
    return "swap \(cookieA) with \(cookieB)"
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(self.cookieA.hashValue)
    hasher.combine(self.cookieB.hashValue)
  }
  
  static func == (lhs: Swap, rhs: Swap) -> Bool {
    return (lhs.cookieA == rhs.cookieA && lhs.cookieB == rhs.cookieB) ||
      (lhs.cookieB == rhs.cookieA && lhs.cookieA == rhs.cookieB)
  }
}
