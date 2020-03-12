import Foundation
import ZIPFoundation

let NSKeyedArchiveVersion = 100000

let ThumbnailPath = "QuickLook/Thumbnail.png"
let DocumentArchivePath = "Document.archive"

let DocumentClassName = "SilicaDocument"
let TrackedTimeKey = "SilicaDocumentTrackedTimeKey"
let LayersKey = "layers"
let TileSizeKey = "tileSize"
let SizeKey = "size"

let LayerClassName = "SilicaLayer"

func readData(archive: Archive, entry: Entry) -> Data? {
    var data = Data()
    
    do {
        let _ = try archive.extract(entry, consumer: { (d) in
            data.append(d)
        })
    } catch {
        Swift.print("Extracting entry from archive failed with error:\(error)")
        
        return nil
    }
    
    return data
}
