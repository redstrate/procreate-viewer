import Cocoa
import ZIPFoundation
import CoreFoundation

struct SilicaChunk {
    var x: Int = 0
    var y: Int = 0
    var image: NSImage = NSImage()
}

struct SilicaLayer {
    var chunks: [SilicaChunk] = []
}

struct SilicaDocument {
    var trackedTime: Int = 0
    var tileSize: Int = 0
    
    var width: Int = 0
    var height: Int = 0
    
    var layers: [SilicaLayer] = []
}

// Since this is a C-function we have to unsafe cast...
func objectRefGetValue(_ objectRef : CFTypeRef) -> UInt32 {
    return _CFKeyedArchiverUIDGetValue(unsafeBitCast(objectRef, to: CFKeyedArchiverUIDRef.self))
}

class Document: NSDocument {
    var data: Data? // oh no...
    
    var dict: NSDictionary?

    var info = SilicaDocument()
        
    var rows: Int = 0
    var columns: Int = 0
    
    var remainderWidth: Int = 0
    var remainderHeight: Int = 0
    
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
    
    /*
     Returns the correct tile size, taking into account the remainder between tile size and image size.
     */
    func getTileSize(x: Int, y: Int) -> (Int, Int) {
        var width: Int = info.tileSize
        var height: Int = info.tileSize
        
        if((x + 1) == columns) {
            width = info.tileSize - remainderWidth
        }
        
        if(y == rows) {
            height = info.tileSize - remainderHeight
        }
        
        return (width, height)
    }
    
    /*
     Converts a CFKeyedArchiveUID from a NSKeyedArchive to a Int for indexing an array or dictionary.
     */
    func getClassID(id: Any?) -> Int {
        return Int(objectRefGetValue(id! as CFTypeRef))
    }
    
    /*
     Parses the chunk filename, ex. 1~1 to integer coordinates.
     */
    func parseChunkFilename(filename: String) -> (Int, Int)? {
        let pathURL = URL(fileURLWithPath: filename)
        let pathComponents = pathURL.lastPathComponent.replacingOccurrences(of: ".chunk", with: "").components(separatedBy: "~")
        
        let x = Int(pathComponents[0])
        let y = Int(pathComponents[1])
        
        if x != nil && y != nil {
            return (x!, y!)
        } else {
            return nil
        }
    }
    
    func parseSilicaLayer(archive: Archive, dict: NSDictionary) {
        let objectsArray = self.dict?["$objects"] as! NSArray

        if getDocumentClassName(dict: dict) == LayerClassName {
            var layer = SilicaLayer()
                        
            let UUIDKey = dict["UUID"]
            let UUIDClassID = getClassID(id: UUIDKey)
            let UUIDClass = objectsArray[UUIDClassID] as! NSString
            
            var chunkPaths: [String] = []
            
            archive.forEach { (entry: Entry) in
                if entry.path.contains(String(UUIDClass)) {
                    chunkPaths.append(entry.path)
                }
            }
            
            layer.chunks = Array(repeating: SilicaChunk(), count: chunkPaths.count)
            
            let dispatchGroup = DispatchGroup()
            let queue = DispatchQueue(label: "imageWork")
            
            DispatchQueue.concurrentPerform(iterations: chunkPaths.count) { (i: Int) in
                dispatchGroup.enter()

                var threadArchive: Archive?
                var threadEntry: Entry?
                
                queue.sync {
                    threadArchive = Archive(data: self.data!, accessMode: Archive.AccessMode.read)
                    threadEntry = threadArchive?[chunkPaths[i]]
                }
        
                guard let (x, y) = parseChunkFilename(filename: threadEntry!.path) else {
                    return
                }
                
                let (width, height) = getTileSize(x: x, y: y)
                let byteSize = width * height * 4
                
                let uncompressedMemory = UnsafeMutablePointer<UInt8>.allocate(capacity: byteSize)

                guard let lzoData = readData(archive: threadArchive!, entry: threadEntry!) else {
                    return
                }
                
                lzoData.withUnsafeBytes({ (bytes: UnsafeRawBufferPointer) -> Void in
                    var len = lzo_uint(byteSize)
                    
                    lzo1x_decompress_safe(bytes.baseAddress!.assumingMemoryBound(to: uint8.self), lzo_uint(lzoData.count), uncompressedMemory, &len, nil)
                })
                
                let imageData = Data(bytes: uncompressedMemory, count: byteSize)
                
                let render: CGColorRenderingIntent = CGColorRenderingIntent.defaultIntent
                let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue).union(.byteOrder32Big)
                let providerRef: CGDataProvider? = CGDataProvider(data: imageData as CFData)
                
                guard let cgimage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: rgbColorSpace, bitmapInfo: bitmapInfo, provider: providerRef!, decode: nil, shouldInterpolate: false, intent: render) else {
                    return
                }
                
                let image = NSImage(cgImage: cgimage, size: NSZeroSize)
                
                queue.async(flags: .barrier) {
                    layer.chunks[i].image = image
                    layer.chunks[i].x = x
                    layer.chunks[i].y = y
                    
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.wait()
            
            info.layers.append(layer)
        }
    }
    
    func parseSilicaDocument(archive: Archive, dict: NSDictionary) {
        let objectsArray = self.dict?["$objects"] as! NSArray

        if getDocumentClassName(dict: dict) == DocumentClassName {
            info.trackedTime = (dict[TrackedTimeKey] as! NSNumber).intValue
            info.tileSize = (dict[TileSizeKey] as! NSNumber).intValue
            
            let sizeClassKey = dict[SizeKey]
            let sizeClassID = getClassID(id: sizeClassKey)
            let sizeString = objectsArray[sizeClassID] as! String
    
            let sizeComponents = sizeString.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "").components(separatedBy: ", ")
            let width = Int(sizeComponents[0])
            let height = Int(sizeComponents[1])
            
            info.width = width!
            info.height = height!
            
            columns = Int(ceil(Float(info.width) / Float(info.tileSize)))
            rows = Int(ceil(Float(info.height) / Float(info.tileSize)))

            if info.width % info.tileSize != 0 {
                remainderWidth = (columns * info.tileSize) - info.width
            }
            
            if info.height % info.tileSize != 0 {
                remainderHeight = (rows * info.tileSize) - info.height
            }
            
            let layersClassKey = dict[LayersKey]
            let layersClassID = getClassID(id: layersClassKey)
            let layersClass = objectsArray[layersClassID] as! NSDictionary
                        
            let array = layersClass["NS.objects"] as! NSArray
            
            for object in array {
                let layerClassID = getClassID(id: object)
                let layerClass = objectsArray[layerClassID] as! NSDictionary
                                
                parseSilicaLayer(archive: archive, dict: layerClass)
            }
        }
    }
    
    func parseDocument(archive: Archive, dict: NSDictionary) {
        // double check if this archive is really correct
        if let value = dict["$version"] {
            if (value as! Int) != NSKeyedArchiveVersion {
                Swift.print("This is not a valid document!")
                return
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
    
        guard let documentEntry = archive[DocumentArchivePath] else {
            return
        }
        
        guard let documentData = readData(archive: archive, entry: documentEntry) else {
            return
        }
        
        var plistFormat = PropertyListSerialization.PropertyListFormat.binary
        guard let propertyList = try? PropertyListSerialization.propertyList(from: documentData, options: [], format: &plistFormat) else {
            return
        }
                
        parseDocument(archive: archive, dict: propertyList as! NSDictionary)
    }
    
    func makeComposite() -> NSImage {
        let image = NSImage(size: NSSize(width: info.width, height: info.height))
        image.lockFocus()
        
        let color = NSColor.white
        color.drawSwatch(in: NSRect(origin: .zero, size: image.size))
        
        for layer in info.layers.reversed() {
            for chunk in layer.chunks {
                let x = chunk.x
                var y = chunk.y
                
                let (width, height) = getTileSize(x: x, y: y)
                
                if y == rows {
                    y = 0
                }
            
                let rect = NSRect(x: info.tileSize * x, y: info.height - (info.tileSize * y), width: width, height: height)
                
                chunk.image.draw(in: rect)
            }
        }
        
        image.unlockFocus()
        return image
    }
}

