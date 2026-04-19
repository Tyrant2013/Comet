//
//  PhotoStorageService.swift
//  Comet Camera
//

import Foundation
import CoreData
import UIKit

class PhotoStorageService {
    static let shared = PhotoStorageService()
    
    private let context: NSManagedObjectContext
    
    private init() {
        self.context = PersistenceController.shared.container.viewContext
    }
    
    // MARK: - Save Photo
    
    func savePhoto(image: UIImage, editMetadata: [String: Any]? = nil) async throws -> SavedPhoto {
        return try await context.perform {
            let photo = SavedPhoto(context: self.context)
            photo.id = UUID().uuidString
            photo.createdAt = Date()
            photo.updatedAt = Date()
            photo.width = Int32(image.size.width)
            photo.height = Int32(image.size.height)
            
            // Convert image to data
            guard let imageData = image.jpegData(compressionQuality: 0.9) else {
                throw PhotoStorageError.imageConversionFailed
            }
            photo.imageData = imageData
            
            // Create thumbnail
            if let thumbnailImage = self.createThumbnail(from: image) {
                photo.thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.7)
            }
            
            // Save edit metadata
            if let metadata = editMetadata {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: metadata)
                    photo.editMetadata = String(data: jsonData, encoding: .utf8)
                } catch {
                    print("Failed to serialize edit metadata: \(error)")
                }
            }
            
            try self.context.save()
            return photo
        }
    }
    
    // MARK: - Fetch Photos
    
    func fetchPhotos(limit: Int = 100, offset: Int = 0) async throws -> [SavedPhoto] {
        return try await context.perform {
            let request = SavedPhoto.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            request.fetchLimit = limit
            request.fetchOffset = offset
            
            return try self.context.fetch(request)
        }
    }
    
    func fetchPhoto(byId id: String) async throws -> SavedPhoto? {
        return try await context.perform {
            let request = SavedPhoto.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)
            request.fetchLimit = 1
            
            let results = try self.context.fetch(request)
            return results.first
        }
    }
    
    // MARK: - Delete Photo
    
    func deletePhoto(_ photo: SavedPhoto) async throws {
        try await context.perform {
            self.context.delete(photo)
            try self.context.save()
        }
    }
    
    func deleteAllPhotos() async throws {
        try await context.perform {
            let request = SavedPhoto.fetchRequest()
            let photos = try self.context.fetch(request)
            photos.forEach { self.context.delete($0) }
            try self.context.save()
        }
    }
    
    // MARK: - Update Photo
    
    func updatePhoto(_ photo: SavedPhoto, with image: UIImage, editMetadata: [String: Any]? = nil) async throws {
        try await context.perform {
            photo.updatedAt = Date()
            photo.width = Int32(image.size.width)
            photo.height = Int32(image.size.height)
            
            guard let imageData = image.jpegData(compressionQuality: 0.9) else {
                throw PhotoStorageError.imageConversionFailed
            }
            photo.imageData = imageData
            
            if let thumbnailImage = self.createThumbnail(from: image) {
                photo.thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.7)
            }
            
            if let metadata = editMetadata {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: metadata)
                    photo.editMetadata = String(data: jsonData, encoding: .utf8)
                } catch {
                    print("Failed to serialize edit metadata: \(error)")
                }
            }
            
            try self.context.save()
        }
    }
    
    // MARK: - Helper Methods
    
    private func createThumbnail(from image: UIImage, maxSize: CGFloat = 200) -> UIImage? {
        let width = image.size.width
        let height = image.size.height
        
        var thumbnailWidth = width
        var thumbnailHeight = height
        
        if width > height {
            if width > maxSize {
                thumbnailWidth = maxSize
                thumbnailHeight = (height / width) * maxSize
            }
        } else {
            if height > maxSize {
                thumbnailHeight = maxSize
                thumbnailWidth = (width / height) * maxSize
            }
        }
        
        let size = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return thumbnail
    }
}

// MARK: - Errors

enum PhotoStorageError: Error, LocalizedError {
    case imageConversionFailed
    case saveFailed
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "图片转换失败"
        case .saveFailed:
            return "保存失败"
        case .notFound:
            return "照片不存在"
        }
    }
}
