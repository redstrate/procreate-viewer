import Cocoa
import Quartz
import ZIPFoundation

class PreviewViewController: NSViewController, QLPreviewingController {
    
    @IBOutlet weak var imageView: NSImageView!
    
    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }
    
    var image: NSImage?

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let fc: NSFileCoordinator = NSFileCoordinator()
        let intent: NSFileAccessIntent = NSFileAccessIntent.readingIntent(with: url)
        fc.coordinate(with: [intent], queue: .main) { (err) in
            if err == nil {
                // No error loading the file? Then continue
                do {
                    let archive = Archive(data: try Data(contentsOf: intent.url), accessMode: Archive.AccessMode.read)
                    
                    let entry = archive?["QuickLook/Thumbnail.png"]
                    var top_data = Data()

                    try archive?.extract(entry!, consumer: { (d) in
                        top_data.append(d)
                    })

                    self.image = NSImage(data: top_data)
                    
                    Swift.print("successfully loaded item " + url.absoluteString)
                    
                    self.view.display()
                    self.imageView?.image = self.image

                    handler(nil)
                } catch {
                    NSLog("Could not load file \(intent.url.lastPathComponent) to preview it")
                }
            } else {
                NSLog("Could not find file \(intent.url.lastPathComponent) to preview it")
            }
        }
    }
}
