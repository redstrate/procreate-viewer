import Cocoa
import ZIPFoundation
import CoreFoundation

struct SilicaLayer {
    
}

struct SilicaDocument {
    var trackedTime: Int = 0
    
    var layers: [SilicaLayer] = []
}

// Since this is a C-function we have to unsafe cast...
func objectRefGetValue(_ objectRef : CFTypeRef) -> UInt32 {
    return _CFKeyedArchiverUIDGetValue(unsafeBitCast(objectRef, to: CFKeyedArchiverUIDRef.self))
}

class Document: NSDocument {
    var dict: NSDictionary?
    
    let DocumentClassName = "SilicaDocument"
    let TrackedTimeKey = "SilicaDocumentTrackedTimeKey"
    let LayersKey = "layers"
    
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
    
    func parseSilicaLayer(dict: NSDictionary) {
        if getDocumentClassName(dict: dict) == LayerClassName {
            let layer = SilicaLayer()
            // TODO: fill in layer information
            
            info.layers.append(layer)
        }
    }
    
    func parseSilicaDocument(dict: NSDictionary) {
        let objectsArray = self.dict?["$objects"] as! NSArray

        if getDocumentClassName(dict: dict) == DocumentClassName {
            info.trackedTime = (dict[TrackedTimeKey] as! NSNumber).intValue
                        
            let layersClassKey = dict[LayersKey]
            let layersClassID = objectRefGetValue(layersClassKey as CFTypeRef)
            let layersClass = objectsArray[Int(layersClassID)] as! NSDictionary
                        
            let array = layersClass["NS.objects"] as! NSArray
            
            for object in array {
                let layerClassID = objectRefGetValue(object as CFTypeRef)
                let layerClass = objectsArray[Int(layerClassID)] as! NSDictionary
                                
                parseSilicaLayer(dict: layerClass)
            }
        }
    }
    
    func parseDocument(dict: NSDictionary) {
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
                        
            parseSilicaDocument(dict: topObjectClass)
        }
    }

    override func read(from data: Data, ofType typeName: String) throws {
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
        
        parseDocument(dict: dict)
    }
}

