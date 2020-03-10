import Cocoa
import ZIPFoundation

class Document: NSDocument {
    var image: NSImage?

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
        
        image = NSImage(data: top_data)
    }
}

