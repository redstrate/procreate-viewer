import Cocoa
import Quartz
import ZIPFoundation

class PreviewViewController: NSViewController, QLPreviewingController {
    @IBOutlet weak var imageView: NSImageView!
    
    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }
    
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let fc: NSFileCoordinator = NSFileCoordinator()
        let intent: NSFileAccessIntent = NSFileAccessIntent.readingIntent(with: url)
        fc.coordinate(with: [intent], queue: .main) { (err) in
            if err == nil {
                do {
                    let standardError = NSError(domain: "procreate-viewer", code: 1, userInfo: nil)

                    guard let archive = Archive(data: try Data(contentsOf: intent.url), accessMode: Archive.AccessMode.read) else {
                        throw standardError
                    }
                    
                    guard let entry = archive[ThumbnailPath] else {
                        throw standardError
                    }
                    
                    guard let thumbnailData = readData(archive: archive, entry: entry) else {
                        throw standardError
                    }

                    self.imageView?.image = NSImage(data: thumbnailData)

                    handler(nil)
                } catch {
                    NSLog("Could not load file \(intent.url.lastPathComponent) to preview it")
                    handler(err)
                }
            } else {
                NSLog("Could not find file \(intent.url.lastPathComponent) to preview it")
                handler(err)
            }
        }
    }
}
