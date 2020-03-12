import Foundation
import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var imageView: NSImageView!
    
    @IBOutlet weak var layerPopup: NSPopUpButton!
    @IBOutlet weak var chunkPopup: NSPopUpButton!
    
    var selectedLayer: Int = 0
    var selectedChunk: Int = 0
    
    func parseName(str: String) -> Int? {
        if let int = Int(str.components(separatedBy: " ")[1]) {
            return int
        }
        
        return nil
    }
    
    func loadCanvas() {
        let document = self.view.window?.windowController?.document as? Document

        imageView.image = document?.info.layers[selectedLayer].chunks[selectedChunk]
    }
    
    @IBAction func selectLayerAction(_ sender: Any) {
        selectedLayer = parseName(str: (layerPopup.titleOfSelectedItem)!)!
        
        selectedChunk = 0
        
        loadLayerChunks()
        loadCanvas()
    }
    
    @IBAction func selectChunkAction(_ sender: Any) {
        selectedChunk = parseName(str: (chunkPopup.titleOfSelectedItem)!)!
        
        loadCanvas()
    }
    
    func loadLayerChunks() {
        let document = self.view.window?.windowController?.document as? Document
        
        chunkPopup.removeAllItems()
        
        for (i, chunk) in (document?.info.layers[selectedLayer].chunks.enumerated())! {
            chunkPopup.addItem(withTitle: "Chunk " + String(i))
        }
    }
    
    override func viewWillAppear() {
        let document = self.view.window?.windowController?.document as? Document
        
        imageView.image = document?.thumbnail
        
        for (i, layer) in (document?.info.layers.enumerated())! {
            layerPopup.addItem(withTitle: "Layer " + String(i))
        }
        
        loadLayerChunks()
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if(segue.identifier == "showInfo") {
            // TODO: there HAS to be a better way to pass the Document class along...
            (segue.destinationController as! InfoViewController).document = self.view.window?.windowController?.document as? Document
        }
    }
}
