//
//  CMRulerCell.swift
//  Comet Camera
//

import Foundation
import UIKit

// MARK: - 刻度单元格
final class CMRulerCell: UICollectionViewCell {
    
    static let reuseIdentifier = "RulerCell"
    
    private let lineLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.systemGray3.cgColor
        return layer
    }()
    
    private let label: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.addSublayer(lineLayer)
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        lineLayer.path = nil
        label.text = nil
        // 重置变换
        transform = .identity
        alpha = 1
    }
    
    func configure(value: Int, type: CMRulerMarkType) {
        label.text = type == .long ? "\(value)" : ""
        label.isHidden = type != .long
        
        let path = UIBezierPath()
        let width = contentView.bounds.width
        let height = contentView.bounds.height
        let bottomY = height - 10
        
        switch type {
        case .long:
            let lineHeight: CGFloat = 35
            path.move(to: CGPoint(x: width/2, y: bottomY - lineHeight))
            path.addLine(to: CGPoint(x: width/2, y: bottomY))
            lineLayer.strokeColor = UIColor.label.cgColor
            lineLayer.lineWidth = 2
            
        case .medium:
            let lineHeight: CGFloat = 22
            path.move(to: CGPoint(x: width/2, y: bottomY - lineHeight))
            path.addLine(to: CGPoint(x: width/2, y: bottomY))
            lineLayer.strokeColor = UIColor.systemGray.cgColor
            lineLayer.lineWidth = 1.5
            
        case .short:
            let lineHeight: CGFloat = 12
            path.move(to: CGPoint(x: width/2, y: bottomY - lineHeight))
            path.addLine(to: CGPoint(x: width/2, y: bottomY))
            lineLayer.strokeColor = UIColor.systemGray3.cgColor
            lineLayer.lineWidth = 1
        }
        
        lineLayer.path = path.cgPath
    }
}
