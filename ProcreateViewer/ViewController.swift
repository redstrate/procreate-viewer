import Foundation
import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var imageView: NSImageView!

    override func viewWillAppear() {
        let document = self.view.window?.windowController?.document as? Document
        
        imageView.image = document?.makeComposite()
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if(segue.identifier == "showInfo") {
            // TODO: there HAS to be a better way to pass the Document class along...
            (segue.destinationController as! InfoViewController).document = self.view.window?.windowController?.document as? Document
        } else if(segue.identifier == "showTimelapse") {
            ((segue.destinationController as! NSWindowController).contentViewController as! TimelapseViewController).document = self.view.window?.windowController?.document as? Document
        }
    }
}
