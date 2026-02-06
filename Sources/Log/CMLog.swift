//
//  File.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/2/6.
//

import Foundation

let cmLog = CMLog()
public class CMLog: Sendable {
    func log(_ msg: String) {
        print("Comet:", msg)
    }
}
