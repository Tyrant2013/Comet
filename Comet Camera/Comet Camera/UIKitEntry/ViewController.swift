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
