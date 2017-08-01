import UIKit

open class ImageCache {
    
    open static let `default` = ImageCache()
    
    var queue = DispatchQueue(label: "ImageCache")
    var workItems = NSCache<NSString, DispatchWorkItem>()
    var images = NSCache<NSString, UIImage>()
    
    open var cacheType = CacheType.disk
    
    public init() {
    }
    
    func addObservers() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidReceiveMemoryWarning,
                                               object: self, queue: nil) {
            notification in
        }
    }
    
    open func loadImage(atUrl url: URL, completion: ((String, UIImage?) -> Void)? = nil) {
        let urlString = url.absoluteString
        let key = urlString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? urlString
        DispatchQueue(label: "SwiftyImageCache").async { [weak self] in
            guard self != nil else {
                return
            }
            if let image = self!.image(of: key) {
                DispatchQueue.main.async {
                    completion?(urlString, image)
                }
                return
            }
            
            if let workItem = self!.workItems.object(forKey: key as NSString) {
                workItem.notify(queue: self!.queue, execute: { [weak self] in
                    if let image = self?.images.object(forKey: key as NSString) {
                        DispatchQueue.main.async {
                            completion?(urlString, image)
                        }
                    }
                })
                return
            }
            let workItem = DispatchWorkItem { [weak self] in
                do {
                    let data = try Data(contentsOf: url)
                    if let image = self?.cacheImage(data: data, key: key) ?? UIImage(data: data) {
                        DispatchQueue.main.async {
                            completion?(urlString, image)
                        }
                        return
                    }
                } catch (let error) {
                    print(error.localizedDescription)
                }
                DispatchQueue.main.async {
                    completion?(urlString, nil)
                }
            }
            self!.workItems.setObject(workItem, forKey: key as NSString)
            self!.queue.async(execute: workItem)
        }
    }
    
    open func clear() {
        workItems.removeAllObjects()
        images.removeAllObjects()
    }
    
    open func image(of key: String, fitSize size: CGSize? = nil) -> UIImage? {
        if let image = images.object(forKey: key as NSString) {
            return image
        }
        let fileURL = cacheFileUrl(key)
        do {
            let data = try Data(contentsOf: fileURL)
            let image = UIImage(data: data)
            return size != nil ? image?.scaleToFit(in: size!) : image
        } catch (let error) {
            print("Can read with error \(error.localizedDescription)")
        }
        return nil
    }
    
    func cacheImage(data: Data, key: String) -> UIImage? {
        switch cacheType {
        case .ram:
            if let image = UIImage(data: data) {
                images.setObject(image, forKey: key as NSString)
                return image
            }
        case .disk:
            let fileURL = cacheFileUrl(key)
            do {
                try data.write(to: fileURL, options: Data.WritingOptions.atomic)
            } catch (let error) {
                print("Error write file \(error.localizedDescription)")
            }
        }
        return nil
    }
}
