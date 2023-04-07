//
//  CacheAction.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/4.
//

import Foundation

enum CacheActionType {
    case local
    case remote
}

struct CacheAction: Equatable {
   
    let actionType: CacheActionType
    let range: NSRange
    init(actionType: CacheActionType, range: NSRange) {
        self.actionType = actionType
        self.range = range
    }
    
    static func == (lhs: CacheAction, rhs: CacheAction) -> Bool {
        return (lhs.actionType == rhs.actionType) && (lhs.range == rhs.range)
    }
    
}
