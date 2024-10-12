import Cocoa
import InputMethodKit

@objc(InputController)
class InputController: IMKInputController {
    func candidates(for target: IMKTextInput) -> [Any]! {
        return ["Hello", "Bye"]
    }

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        NSLog(string)
        // get client to insert
        guard let client = sender as? IMKTextInput else {
            return false
        }
        if let candidates = IMKCandidates(server: self.server(), panelType: kIMKMain) {
            candidates.update()
        } else {
            
        }
        client.insertText("Hello" + string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        return true
    }
}
