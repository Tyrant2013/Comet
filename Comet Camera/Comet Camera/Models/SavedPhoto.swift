//
//  SavedPhoto.swift
//  Comet Camera
//

import Foundation
import CoreData
import UIKit

@objc(SavedPhoto)
public class SavedPhoto: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var imageData: Data?
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var width: Int32
    @NSManaged public var height: Int32
    @NSManaged public var editMetadata: String? // JSON string for edit operations
}

extension SavedPhoto {
    static func fetchRequest(
        sortBy dateSort: NSSortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
    ) -> NSFetchRequest<SavedPhoto> {
        let request: NSFetchRequest<SavedPhoto> = SavedPhoto.fetchRequest()
        request.sortDescriptors = [dateSort]
        return request
    }
    
    var image: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }
    
    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }
}
