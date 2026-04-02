//
//  CMRulerView.swift
//  Comet Camera
//
import UIKit

// MARK: - 刻度盘布局
final class RulerLayout: UICollectionViewFlowLayout {
    
    var itemWidth: CGFloat = 2
    var itemSpacing: CGFloat = 10
    
    // 左右边距，让首尾刻度能居中
    var edgePadding: CGFloat = 0
    
    private var cache: [UICollectionViewLayoutAttributes] = []
    private var contentWidth: CGFloat = 0
    
    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: collectionView?.bounds.height ?? 0)
    }
    
    override func prepare() {
        super.prepare()
        guard let collectionView = collectionView else { return }
        
        cache.removeAll()
        scrollDirection = .horizontal
        minimumLineSpacing = itemSpacing
        itemSize = CGSize(width: itemWidth, height: collectionView.bounds.height)
        
        let numberOfItems = collectionView.numberOfItems(inSection: 0)
        
        // 计算总宽度：边距 + 所有item + 边距
        let itemsWidth = CGFloat(numberOfItems) * itemWidth
        let spacingWidth = CGFloat(numberOfItems - 1) * itemSpacing
        contentWidth = edgePadding * 2 + itemsWidth + spacingWidth
        
        for item in 0..<numberOfItems {
            let indexPath = IndexPath(item: item, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            let x = edgePadding + CGFloat(item) * (itemWidth + itemSpacing)
            attributes.frame = CGRect(x: x, y: 0, width: itemWidth, height: collectionView.bounds.height)
            cache.append(attributes)
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cache.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.item < cache.count else { return nil }
        return cache[indexPath.item]
    }
    
    // 添加这个方法确保边界可滚动
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView else { return proposedContentOffset }
        
        let targetX = proposedContentOffset.x + collectionView.bounds.width / 2
        let itemWidthPlusSpacing = itemWidth + itemSpacing
        
        // 计算最近的索引
        let index = round((targetX - edgePadding - itemWidth / 2) / itemWidthPlusSpacing)
        let clampedIndex = max(0, min(CGFloat(cache.count - 1), index))
        
        let newOffset = edgePadding + clampedIndex * itemWidthPlusSpacing - collectionView.bounds.width / 2 + itemWidth / 2
        
        return CGPoint(x: newOffset, y: 0)
    }
}

// MARK: - 刻度单元格
final class RulerCell: UICollectionViewCell {
    
    static let reuseIdentifier = "RulerCell"
    
    private let lineLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.systemGray3.cgColor
        return layer
    }()
    
    private let label: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .label
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
    }
    
    func configure(value: Int, type: RulerMarkType) {
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

enum RulerMarkType {
    case long, medium, short
}

// MARK: - 刻度盘视图
final class RulerView: UIView {
    
    struct Configuration {
        var minValue: Int = 0
        var maxValue: Int = 1000
        var majorStep: Int = 10
        var mediumStep: Int = 5
        var valueChanged: ((Int) -> Void)?
    }
    
    var configuration: Configuration = Configuration() {
        didSet {
            updateRange()
        }
    }
    
    var currentValue: Int {
        guard collectionView.bounds.width > 0 else { return configuration.minValue }
        
        let offset = collectionView.contentOffset.x + centerIndicatorOffset - layout.edgePadding
        let index = Int(round(offset / (layout.itemWidth + layout.itemSpacing)))
        let value = index + configuration.minValue
        return min(max(value, configuration.minValue), configuration.maxValue)
    }
    
    private let layout = RulerLayout()
    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.decelerationRate = .normal // 改为 normal 让系统处理吸附
        cv.delegate = self
        cv.dataSource = self
        cv.register(RulerCell.self, forCellWithReuseIdentifier: RulerCell.reuseIdentifier)
        return cv
    }()
    
    private let centerIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .systemRed
        view.layer.cornerRadius = 2
        return view
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()
    
    private var centerIndicatorOffset: CGFloat {
        return collectionView.bounds.width / 2
    }
    
    private var pendingValue: Int?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        addSubview(collectionView)
        addSubview(centerIndicator)
        addSubview(valueLabel)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        centerIndicator.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 70),
            
            centerIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerIndicator.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: -10),
            centerIndicator.widthAnchor.constraint(equalToConstant: 4),
            centerIndicator.heightAnchor.constraint(equalToConstant: 45),
            
            valueLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: collectionView.topAnchor, constant: -10)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let oldPadding = layout.edgePadding
        layout.edgePadding = centerIndicatorOffset
        
        // 只在 padding 变化时重新布局
        if oldPadding != layout.edgePadding {
            collectionView.collectionViewLayout.invalidateLayout()
            
            // 如果有待设置的值，现在应用
            if let pending = pendingValue {
                pendingValue = nil
                setValue(pending, animated: false)
            }
        }
    }
    
    func setValue(_ value: Int, animated: Bool = true) {
        let clampedValue = min(max(value, configuration.minValue), configuration.maxValue)
        
        // 如果还未布局，先保存待设置
        guard collectionView.bounds.width > 0, layout.edgePadding > 0 else {
            pendingValue = clampedValue
            return
        }
        
        let index = clampedValue - configuration.minValue
        let offset = layout.edgePadding + CGFloat(index) * (layout.itemWidth + layout.itemSpacing) - centerIndicatorOffset + layout.itemWidth / 2
        
        // 限制 contentOffset 范围
        let maxOffset = collectionView.contentSize.width - collectionView.bounds.width
        let finalOffset = max(0, min(offset, maxOffset))
        
        collectionView.setContentOffset(CGPoint(x: finalOffset, y: 0), animated: animated)
        updateValueLabel(clampedValue)
    }
    
    private func updateRange() {
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        updateValueLabel(configuration.minValue)
    }
    
    private func updateValueLabel(_ value: Int) {
        valueLabel.text = "\(value)"
        configuration.valueChanged?(value)
    }
}

// MARK: - UICollectionViewDataSource
extension RulerView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return configuration.maxValue - configuration.minValue + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RulerCell.reuseIdentifier, for: indexPath) as! RulerCell
        
        let value = configuration.minValue + indexPath.item
        let type: RulerMarkType
        
        if value % configuration.majorStep == 0 {
            type = .long
        } else if value % configuration.mediumStep == 0 {
            type = .medium
        } else {
            type = .short
        }
        
        cell.configure(value: value, type: type)
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension RulerView: UICollectionViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateValueLabel(currentValue)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // 使用 layout 的 targetContentOffset 自动处理吸附
        // 这里只需要更新数值显示
        updateValueLabel(currentValue)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            snapToNearest()
        }
    }
    
    private func snapToNearest() {
        let targetOffset = layout.targetContentOffset(
            forProposedContentOffset: collectionView.contentOffset,
            withScrollingVelocity: .zero
        )
        collectionView.setContentOffset(targetOffset, animated: true)
    }
}

// MARK: - 使用示例
class CMRulerViewController: UIViewController {
    
    private let rulerView = RulerView()
    private let resultLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupUI()
        
        rulerView.configuration = RulerView.Configuration(
            minValue: 0,
            maxValue: 100,
            majorStep: 10,
            mediumStep: 5
        ) { [weak self] value in
            self?.resultLabel.text = "选中: \(value)"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 在 view 完全布局后设置初始值
        rulerView.setValue(0, animated: true)
    }
    
    private func setupUI() {
        rulerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rulerView)
        
        resultLabel.font = .systemFont(ofSize: 18, weight: .medium)
        resultLabel.textColor = .secondaryLabel
        resultLabel.textAlignment = .center
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resultLabel)
        
        NSLayoutConstraint.activate([
            rulerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            rulerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rulerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rulerView.heightAnchor.constraint(equalToConstant: 140),
            
            resultLabel.topAnchor.constraint(equalTo: rulerView.bottomAnchor, constant: 30),
            resultLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
}

import SwiftUI

struct CMRulerViewPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CMRulerViewController {
        let vc = CMRulerViewController()
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CMRulerViewController, context: Context) {
        
    }
}

#Preview {
    CMRulerViewPreview()
}
