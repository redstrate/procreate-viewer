import Cocoa
import ZIPFoundation

struct DocumentInfo {
    var tracked_time: Int = 0
}

class Document: NSDocument {
    var info = DocumentInfo()
    
    var thumbnail: NSImage? = nil

    override init() {
        super.init()
    }
    
    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        self.addWindowController(windowController)
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
        
        // this is temporary, as we're just hoping that the keyed archive fits our requirements...
        let dict = (propertyList as! NSDictionary);
        
        let objects = dict["$objects"] as! NSArray
        
        let tracked_time = (objects[1] as! NSDictionary)["SilicaDocumentTrackedTimeKey"]
        
        info.tracked_time = (tracked_time as! NSNumber).intValue
    }
}

