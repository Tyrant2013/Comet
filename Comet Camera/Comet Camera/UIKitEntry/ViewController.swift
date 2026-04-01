//
//  ViewController.swift
//  Comet Camera
//
//  Created by 桃园谷 on 2026/3/26.
//

import UIKit

class ViewController: UIViewController {

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let btn = UIButton(type: .system)
        btn.setTitle("剪裁图片", for: .normal)
        btn.addTarget(self, action: #selector(buttonClick), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(btn)
        
        NSLayoutConstraint.activate([
            btn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            btn.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            btn.widthAnchor.constraint(equalToConstant: 200),
            btn.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        let editButton = UIHostingController(rootView: DemoButton(title: "编辑", action: { [weak self] in
            let vc = CMPhotoEditViewController(image: UIImage(named: "PreviewImage")!)
            guard let strongSelf = self else { return }
            strongSelf.present(vc, animated: true)
        })).view!
        editButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(editButton)
        NSLayoutConstraint.activate([
            editButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            editButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 80),
            
        ])
    }
    
    @objc
    private func buttonClick(_ sender: UIButton) {
        if let image = UIImage(named: "PreviewImage") {
            let vc = CMCropViewController(croppingStyle: .default, image: image)
            present(vc, animated: true)
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

import SwiftUI

struct DemoButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.black)
                .frame(width: 120, height: 40)
                .background(.orange, in: .rect(cornerRadius: 6))
        }
    }
}
