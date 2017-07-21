import UIKit

open class ImageCache {
    
    open static let `default` = ImageCache()
    
    var queue = DispatchQueue(label: "ImageCache")
    var workItems = NSCache<NSString, DispatchWorkItem>()
    var images = NSCache<NSString, UIImage>()
    
    public init() {
    }
    
    open func loadImage(atUrl url: URL, completion: @escaping (UIImage?) -> Void) {
        let urlString = url.absoluteString
        if let image = images.object(forKey: urlString as NSString) {
            completion(image)
            return
        }
        if let workItem = workItems.object(forKey: urlString as NSString) {
            workItem.notify(queue: queue, execute: { [weak self] in
                if let image = self?.images.object(forKey: urlString as NSString) {
                    DispatchQueue.main.async {
                        completion(image)
                    }
                }
            })
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            do {
                let data = try Data(contentsOf: url)
                if let image = UIImage(data: data) {
                    self?.images.setObject(image, forKey: urlString as NSString)
                    DispatchQueue.main.async {
                        completion(image)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch ( _) {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
        workItems.setObject(workItem, forKey: urlString as NSString)
        queue.async(execute: workItem)
    }
    
    open func clear() {
        workItems.removeAllObjects()
        images.removeAllObjects()
    }
}
