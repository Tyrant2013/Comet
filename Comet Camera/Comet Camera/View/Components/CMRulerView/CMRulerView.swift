//
//  CMRulerView.swift
//  Comet Camera
//
import UIKit

enum CMRulerMarkType {
    case long, medium, short
}

// MARK: - 刻度盘视图
final class CMRulerView: UIView {
    
    struct Configuration {
        var minValue: Int = -100
        var maxValue: Int = 100
        var majorStep: Int = 10
        var mediumStep: Int = 5
        var textColor: UIColor = .white
        var valueChanged: ((Int) -> Void)?
        
        // 肉卷效果配置
        var fadeEffectEnabled: Bool = true      // 是否启用肉卷效果
        var fadeDistance: CGFloat = 150         // 淡出距离（点）
        var minScale: CGFloat = 0.5               // 最小缩放
        var minAlpha: CGFloat = 0.3                 // 最小透明度
    }
    
    var configuration: Configuration = Configuration() {
        didSet {
            updateConfiguration()
        }
    }
    
    var currentValue: Int {
        guard collectionView.bounds.width > 0 else { return configuration.minValue }
        
        let offset = collectionView.contentOffset.x + centerIndicatorOffset - layout.edgePadding
        let index = Int(round(offset / (layout.itemWidth + layout.itemSpacing)))
        let value = index + configuration.minValue
        return min(max(value, configuration.minValue), configuration.maxValue)
    }
    
    private var lastValue: Int = .max
    
    private let layout = CMRulerLayout()
    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.decelerationRate = .normal
        cv.delegate = self
        cv.dataSource = self
        cv.register(CMRulerCell.self, forCellWithReuseIdentifier: CMRulerCell.reuseIdentifier)
        return cv
    }()
    
    private let centerIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .systemRed
        view.layer.cornerRadius = 2
        return view
    }()
    
    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = configuration.textColor
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
        backgroundColor = .clear
        
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
            centerIndicator.heightAnchor.constraint(equalToConstant: 35),
            
            valueLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: collectionView.topAnchor, constant: -10)
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setValue(0, animated: false)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let oldPadding = layout.edgePadding
        layout.edgePadding = centerIndicatorOffset
        
        if oldPadding != layout.edgePadding {
            collectionView.collectionViewLayout.invalidateLayout()
            
            if let pending = pendingValue {
                pendingValue = nil
                setValue(pending, animated: false)
            }
        }
    }
    
    private func updateConfiguration() {
        layout.fadeEffectEnabled = configuration.fadeEffectEnabled
        layout.fadeDistance = configuration.fadeDistance
        layout.minScale = configuration.minScale
        layout.minAlpha = configuration.minAlpha
        
        collectionView.reloadData()
        updateValueLabel(currentValue)
    }
    
    func setValue(_ value: Int, animated: Bool = true) {
        let clampedValue = min(max(value, configuration.minValue), configuration.maxValue)
        
        guard collectionView.bounds.width > 0, layout.edgePadding > 0 else {
            pendingValue = clampedValue
            return
        }
        
        let index = clampedValue - configuration.minValue
        let offset = layout.edgePadding + CGFloat(index) * (layout.itemWidth + layout.itemSpacing) - centerIndicatorOffset + layout.itemWidth / 2
        
        let maxOffset = collectionView.contentSize.width - collectionView.bounds.width
        let finalOffset = max(0, min(offset, maxOffset))
        
        collectionView.setContentOffset(CGPoint(x: finalOffset, y: 0), animated: animated)
        updateValueLabel(clampedValue)
    }
    
    private func updateValueLabel(_ value: Int) {
        valueLabel.text = "\(value)"
        guard lastValue != value else { return }
        lastValue = value
        configuration.valueChanged?(value)
    }
    
    private func snapToNearest() {
        let targetOffset = layout.targetContentOffset(
            forProposedContentOffset: collectionView.contentOffset,
            withScrollingVelocity: .zero
        )
        collectionView.setContentOffset(targetOffset, animated: true)
    }
}

// MARK: - UICollectionViewDataSource
extension CMRulerView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return configuration.maxValue - configuration.minValue + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CMRulerCell.reuseIdentifier, for: indexPath) as! CMRulerCell
        
        let value = configuration.minValue + indexPath.item
        let type: CMRulerMarkType
        
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
extension CMRulerView: UICollectionViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 滚动时实时更新肉卷效果
        if configuration.fadeEffectEnabled {
            collectionView.collectionViewLayout.invalidateLayout()
        }
        
        updateValueLabel(currentValue)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateValueLabel(currentValue)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            snapToNearest()
        }
    }
}
