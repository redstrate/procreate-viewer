import QuickLookThumbnailing
import ZIPFoundation
import Cocoa

class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        do {
            guard let archive = Archive(data: try Data(contentsOf: request.fileURL), accessMode: Archive.AccessMode.read) else {
                return
            }
            
            guard let entry = archive[ThumbnailPath] else {
                return
            }
            
            guard let thumbnailData = readData(archive: archive, entry: entry) else {
                return
            }
            
            let image = NSImage(data: thumbnailData)
            
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
            NSLog("Could not access file \(request.fileURL.lastPathComponent) to preview it")
            handler(nil, nil)
        }
    }
}

