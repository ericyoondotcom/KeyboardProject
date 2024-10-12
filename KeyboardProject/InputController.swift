import Cocoa
import InputMethodKit

@objc(InputController)
class InputController: IMKInputController {
    private let candidates: IMKCandidates
    private let client: IMKTextInput
    private let controlKeys = [
        kVK_LeftArrow,
        kVK_RightArrow,
        kVK_UpArrow,
        kVK_DownArrow,
        kVK_Escape,
        kVK_Delete,
        kVK_ForwardDelete,
    ]
    
    
    override init!(server: IMKServer, delegate: Any, client inputClient: Any) {
        let candidatesWrapped = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        guard let clientUnwrapped = inputClient as? IMKTextInput else {
            return nil
        }
        guard let candidatesUnwrapped = candidatesWrapped else {
            return nil
        }
        self.candidates = candidatesUnwrapped
        self.client = clientUnwrapped
        
        super.init(server: server, delegate: delegate, client: inputClient)
    }
    
    override func candidates(_ sender: Any) -> [Any] {
        return ["foo", "bar"]
    }

    override func candidateSelected(_ candidateString: NSAttributedString) {
        client.insertText(candidateString.string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        candidates.hide()
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString) {
        NSLog("%@", "\(#function)")
    }

    override func handle(_ event: NSEvent, client sender: Any) -> Bool {
        guard let client = sender as? IMKTextInput else {
            return false
        }
        if candidates.isVisible() {
            candidates.interpretKeyEvents([ event ])
        }
        if event.characters == ":" {
            candidates.update()
            candidates.show()
        }
        if event.keyCode == 0x35 { // escape key
            candidates.hide()
        }
        
        // The return value is whether the system interprets the keystroke with default behavior
        // If the event had no associated character, i.e. arrow keys, let the system do its thing
        // If the event was a character that should be typed, consume it
        if controlKeys.contains(Int(event.keyCode)) {
            return false
        }
        if let chars = event.characters {
            NSLog(chars)
        }
        client.insertText(event.characters, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        return true
    }
}
