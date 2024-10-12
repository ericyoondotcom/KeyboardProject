import Cocoa
import InputMethodKit

@objc(InputController)
class InputController: IMKInputController {
    private let candidates: IMKCandidates
    private let client: IMKTextInput
    
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
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString) {
        NSLog("%@", "\(#function)")
    }

//    override func handle(_ event: NSEvent, client sender: Any) -> Bool {
//        NSLog("%@", "\(#function)((\(event), client: \(sender))")
//    }
    
    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput else {
            return false
        }
        if string == ":" {
            candidates.update()
            candidates.show()
        }
        client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        return true
    }
}
