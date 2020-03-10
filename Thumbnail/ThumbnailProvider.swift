import QuickLookThumbnailing
import ZIPFoundation
import Cocoa

class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let fc: NSFileCoordinator = NSFileCoordinator()
        let intent: NSFileAccessIntent = NSFileAccessIntent.readingIntent(with: request.fileURL)
        fc.coordinate(with: [intent], queue: .main) { (err) in
            if err == nil {
                do {
                    let archive = Archive(data: try Data(contentsOf: intent.url), accessMode: Archive.AccessMode.read)
                    
                    let entry = archive?["QuickLook/Thumbnail.png"]
                    var top_data = Data()
                    
                    try archive?.extract(entry!, consumer: { (d) in
                        top_data.append(d)
                    })
                    
                    let image = NSImage(data: top_data)
                    
                    let maximumSize = request.maximumSize
                    let imageSize = image?.size
                    
                    var newImageSize = maximumSize
                    var contextSize = maximumSize
                    let aspectRatio = imageSize!.height / imageSize!.width
                    let proposedHeight = aspectRatio * maximumSize.width
                    
                    if proposedHeight <= maximumSize.height {
                        newImageSize.height = proposedHeight
                        contextSize.height = max(proposedHeight.rounded(.down), request.minimumSize.height)
                    } else {
                        newImageSize.width = maximumSize.height / aspectRatio
                        contextSize.width = max(newImageSize.width.rounded(.down), request.minimumSize.width)
                    }

                    let reply: QLThumbnailReply = QLThumbnailReply.init(contextSize: contextSize) { () -> Bool in
                        if image != nil {
                            image!.draw(in: CGRect(x: contextSize.width/2 - newImageSize.width/2,
                                                  y: contextSize.height/2 - newImageSize.height/2,
                                                  width: newImageSize.width,
                                                  height: newImageSize.height));

                            return true
                        } else {
                            return false
                        }
                    }
                    handler(reply, nil)
                } catch {
                    NSLog("Could not load file \(intent.url.lastPathComponent) to preview it")
                    handler(nil, nil)
                }
            } else {
                NSLog("Could not find file \(intent.url.lastPathComponent) to preview it")
                handler(nil, nil)
            }
        }
    }
}
