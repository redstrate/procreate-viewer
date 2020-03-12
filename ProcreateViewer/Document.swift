import Cocoa
import ZIPFoundation
import CoreFoundation

struct SilicaLayer {
    var chunks: [NSImage] = []
}

struct SilicaDocument {
    var trackedTime: Int = 0
    var tileSize: Int = 0
    
    var layers: [SilicaLayer] = []
}

// Since this is a C-function we have to unsafe cast...
func objectRefGetValue(_ objectRef : CFTypeRef) -> UInt32 {
    return _CFKeyedArchiverUIDGetValue(unsafeBitCast(objectRef, to: CFKeyedArchiverUIDRef.self))
}

class Document: NSDocument {
    var data: Data? // oh no...
    
    var dict: NSDictionary?
    
    let DocumentClassName = "SilicaDocument"
    let TrackedTimeKey = "SilicaDocumentTrackedTimeKey"
    let LayersKey = "layers"
    let TileSizeKey = "tileSize"
    
    let LayerClassName = "SilicaLayer"
    
    var info = SilicaDocument()
    
    var thumbnail: NSImage? = nil

    override init() {
        super.init()
    }
    
    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        self.addWindowController(windowController)
    }
    
    /*
     Pass in an object from the $object array, which always contains a $class key.
     */
    func getDocumentClassName(dict: NSDictionary) -> String? {
        let objectsArray = self.dict?["$objects"] as! NSArray

        if let value = dict["$class"] {
            let classObjectId = objectRefGetValue(value as CFTypeRef)
            let classObject = objectsArray[Int(classObjectId)] as! NSDictionary
            
            return classObject["$classname"] as? String
        }
        
        return nil
    }
    
    func parseSilicaLayer(archive: Archive, dict: NSDictionary) {
        let objectsArray = self.dict?["$objects"] as! NSArray

        if getDocumentClassName(dict: dict) == LayerClassName {
            var layer = SilicaLayer()
                        
            let UUIDKey = dict["UUID"]
            let UUIDClassID = objectRefGetValue(UUIDKey as CFTypeRef)
            let UUIDClass = objectsArray[Int(UUIDClassID)] as! NSString
            
            var chunkPaths: [Entry] = []
            
            archive.forEach { (entry: Entry) in
                if entry.path.contains(String(UUIDClass)) {
                    chunkPaths.append(entry)
                }
            }
            
            layer.chunks = Array(repeating: NSImage(), count: chunkPaths.count)
            
            DispatchQueue.concurrentPerform(iterations: chunkPaths.count) { (i: Int) in
                let entry = chunkPaths[i]
                
                guard let archive = Archive(data: self.data!, accessMode: Archive.AccessMode.read) else  {
                    return
                }
                
                var lzo_data = Data()
                
                do {
                    try archive.extract(entry, consumer: { (d) in
                        lzo_data.append(d)
                    })
                } catch {
                    Swift.print("Extracting entry from archive failed with error:\(error)")
                }
                
                let uint8Pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: info.tileSize * info.tileSize * 4)
                
                lzo_data.withUnsafeBytes({ (bytes: UnsafeRawBufferPointer) -> Void in
                    var len = lzo_uint(info.tileSize * info.tileSize * 4)
                    
                    lzo1x_decompress_safe(bytes.baseAddress!.assumingMemoryBound(to: uint8.self), lzo_uint(lzo_data.count), uint8Pointer, &len, nil)
                })
                
                let image_data = Data(bytes: uint8Pointer, count: info.tileSize * info.tileSize * 4)
                
                let render: CGColorRenderingIntent = CGColorRenderingIntent.defaultIntent
                let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                    .union(.byteOrder32Little)
                let providerRef: CGDataProvider? = CGDataProvider(data: image_data as CFData)
                
                let cgimage: CGImage? = CGImage(width: info.tileSize, height: info.tileSize, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: info.tileSize * 4, space: rgbColorSpace, bitmapInfo: bitmapInfo, provider: providerRef!, decode: nil, shouldInterpolate: true, intent: render)
                if cgimage != nil {
                    let image = NSImage(cgImage: cgimage!, size: NSZeroSize)
                  
                    layer.chunks[i] = image
                }
            }
            
            info.layers.append(layer)
        }
    }
    
    func parseSilicaDocument(archive: Archive, dict: NSDictionary) {
        let objectsArray = self.dict?["$objects"] as! NSArray

        if getDocumentClassName(dict: dict) == DocumentClassName {
            info.trackedTime = (dict[TrackedTimeKey] as! NSNumber).intValue
            info.tileSize = (dict[TileSizeKey] as! NSNumber).intValue
            
            let layersClassKey = dict[LayersKey]
            let layersClassID = objectRefGetValue(layersClassKey as CFTypeRef)
            let layersClass = objectsArray[Int(layersClassID)] as! NSDictionary
                        
            let array = layersClass["NS.objects"] as! NSArray
            
            for object in array {
                let layerClassID = objectRefGetValue(object as CFTypeRef)
                let layerClass = objectsArray[Int(layerClassID)] as! NSDictionary
                                
                parseSilicaLayer(archive: archive, dict: layerClass)
            }
        }
    }
    
    func parseDocument(archive: Archive, dict: NSDictionary) {
        // double check if this archive is really correct
        if let value = dict["$version"] {
            if (value as! Int) != 100000 {
                Swift.print("This is not a valid document!")
            }
            
            self.dict = dict
            
            let objectsArray = dict["$objects"] as! NSArray
            
            // let's read the $top class, which is always going to be SilicaDocument type.
            let topObject = dict["$top"] as! NSDictionary
            let topClassID = objectRefGetValue(topObject["root"] as CFTypeRef)
            let topObjectClass = objectsArray[Int(topClassID)] as! NSDictionary
                        
            parseSilicaDocument(archive: archive, dict: topObjectClass)
        }
    }

    override func read(from data: Data, ofType typeName: String) throws {
        self.data = data
        
        guard let archive = Archive(data: data, accessMode: Archive.AccessMode.read) else  {
            return
        }
        
        // load thumbnail
        guard let entry = archive["QuickLook/Thumbnail.png"] else {
            return
        }
        
        var top_data = Data()
        
        do {
            try archive.extract(entry, consumer: { (d) in
                top_data.append(d)
            })
        } catch {
            Swift.print("Extracting entry from archive failed with error:\(error)")
        }
        
        thumbnail = NSImage(data: top_data)
    
        // load doc info
        guard let document_entry = archive["Document.archive"] else {
            return
        }
        
        var doc_data = Data()
        
        do {
            try archive.extract(document_entry, consumer: { (d) in
                doc_data.append(d)
            })
        } catch {
            Swift.print("Extracting entry from archive failed with error:\(error)")
        }
        
        // Document.archive is a binary plist (specifically a NSKeyedArchive), luckily swift has a built-in solution to decode it
        var plistFormat = PropertyListSerialization.PropertyListFormat.binary
        let plistBinary = doc_data
        
        guard let propertyList = try? PropertyListSerialization.propertyList(from: plistBinary, options: [], format: &plistFormat) else {
            fatalError("failed to deserialize")
        }
        
        let dict = (propertyList as! NSDictionary);
        
        parseDocument(archive: archive, dict: dict)
    }
}

