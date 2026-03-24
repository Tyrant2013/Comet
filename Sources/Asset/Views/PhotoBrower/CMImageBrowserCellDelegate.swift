//
//  File.swift
//  Comet
//

import Foundation

// MARK: - 代理协议
protocol CMImageBrowserCellDelegate: AnyObject {
    func CMImageBrowserCellDidZoom(_ cell: CMImageBrowserCell)
}
