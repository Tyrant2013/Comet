//
//  CMRulerPreview.swift
//  Comet Camera
//

import SwiftUI

// MARK: - 使用示例
class CMRulerViewController: UIViewController {
    
    private let rulerView = CMRulerView()
    private let resultLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupUI()
        
        // 配置带肉卷效果的刻度盘
        rulerView.configuration = CMRulerView.Configuration(
            minValue: -100,
            maxValue: 100,
            majorStep: 10,
            mediumStep: 5,
            valueChanged: { [weak self] value in
                self?.resultLabel.text = "选中: \(value)"
            },
            fadeEffectEnabled: false,    // 启用肉卷效果
            fadeDistance: 120,         // 120pt 外开始淡出
            minScale: 0.4,             // 最小缩放到 40%
            minAlpha: 0.1              // 最小透明度 20%
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
        
        let normalStyle = UIButton(type: .system)
        normalStyle.addTarget(self, action: #selector(normalButtonClick), for: .touchUpInside)
        normalStyle.setTitle("默认样式", for: .normal)
        let fadeStyle = UIButton(type: .system)
        fadeStyle.addTarget(self, action: #selector(fadeButtonClick), for: .touchUpInside)
        fadeStyle.setTitle("特殊样式", for: .normal)
        
        normalStyle.translatesAutoresizingMaskIntoConstraints = false
        fadeStyle.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(normalStyle)
        view.addSubview(fadeStyle)
        
        NSLayoutConstraint.activate([
            normalStyle.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 20),
            normalStyle.trailingAnchor.constraint(equalTo: resultLabel.centerXAnchor, constant: -10),
            normalStyle.widthAnchor.constraint(equalToConstant: 120),
            normalStyle.heightAnchor.constraint(equalToConstant: 30),
            
            fadeStyle.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 20),
            fadeStyle.leftAnchor.constraint(equalTo: resultLabel.centerXAnchor, constant: 10),
            fadeStyle.widthAnchor.constraint(equalToConstant: 120),
            fadeStyle.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    @objc
    private func normalButtonClick(_ sender: UIButton) {
        rulerView.configuration = CMRulerView.Configuration(
            minValue: -100,
            maxValue: 100,
            majorStep: 10,
            mediumStep: 5,
            valueChanged: { [weak self] value in
                self?.resultLabel.text = "选中: \(value)"
            },
            fadeEffectEnabled: false,    // 启用肉卷效果
            fadeDistance: 120,         // 120pt 外开始淡出
            minScale: 0.4,             // 最小缩放到 40%
            minAlpha: 0.1              // 最小透明度 20%
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.rulerView.setValue(0)
        }
    }
    
    @objc
    private func fadeButtonClick(_ sender: UIButton) {
        
        rulerView.configuration = CMRulerView.Configuration(
            minValue: 0,
            maxValue: 100,
            majorStep: 10,
            mediumStep: 5,
            valueChanged: { [weak self] value in
                self?.resultLabel.text = "选中: \(value)"
            },
            fadeEffectEnabled: true,    // 启用肉卷效果
            fadeDistance: 120,         // 120pt 外开始淡出
            minScale: 0.4,             // 最小缩放到 40%
            minAlpha: 0.1              // 最小透明度 20%
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.rulerView.setValue(0)
        }
    }
}

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
