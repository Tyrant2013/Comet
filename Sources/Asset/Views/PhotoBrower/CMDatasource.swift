//
//  File.swift
//  Comet
//
//  Created by 桃园谷 on 2026/3/24.
//

import Foundation
import Photos
import UIKit

class CMDatasource: NSObject, UICollectionViewDataSource, CMDatasourceProtocol {
    private(set) var fetchResult: CMFetchResult<PHAsset>
    
    weak var collectionView: UICollectionView?
    
    var count: Int { fetchResult.count }
    
    init(fetchResult: CMFetchResult<PHAsset>) {
        self.fetchResult = fetchResult
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchResult.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CMImageBrowserCell.identifier, for: indexPath) as! CMImageBrowserCell
        if let phAsset = fetchResult.object(at: indexPath.row) {
            let asset = CMAsset(phAsset: phAsset)
            cell.confige(with: asset)
            cell.zoomDelegate = self
        }
        return cell
    }
}

extension CMDatasource: CMImageBrowserCellDelegate {
    func CMImageBrowserCellDidZoom(_ cell: CMImageBrowserCell) {
        collectionView?.isScrollEnabled = !cell.isZoomed
    }
}
