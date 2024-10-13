import Cocoa
import Accelerate
import InputMethodKit

func removeDupes(arr: [String]) -> [String] {
    return NSOrderedSet(array: arr).map({ $0 as! String })
}

func removeDupes(arr: Dictionary<String, String>.Values) -> [String] {
    return removeDupes(arr: Array(arr))
}

struct CFAIResponse: Decodable {
    let data: Array<Array<Float16>>
    let shape: Array<Int32>
}

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
        kVK_ForwardDelete,
        kVK_Delete,
    ]
    private var isSuggesting = false;
    private var isLatexOnly = false; // if the user invoked the popup with a backslash
    private var isIPAOnly = false;
    private var suggestionInput = "";
    private var lastCharacter: Character? = nil;
    private var cloudSuggestions: [String] = []
    
    private var suggestionsLatexCanonical: Dictionary<String, String> = [:]
    private var suggestionsLatexSemantic: Dictionary<String, String> = [:]
    private var suggestionsEmojiCanonical: Dictionary<String, String> = [:]
    private var suggestionsIPA: Array<[String]> = []
    
    private var corpusEmbedding: [[Float]] = []
    private var emojiIndex: [String] = []

    private var debounceTimer: Timer?
    
    private func requestSemanticEmojis() {
        NSLog("Requesting semantic emojis")
        let url = URL(string: "https://my-emoji.sidachen2003.workers.dev")!
        guard let data = try? JSONSerialization.data(withJSONObject: [suggestionInput]) else {
            print("Error: unable to serialize")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        let task = URLSession.shared.dataTask(with: request) { [self] data, response, error in
            Task {
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("Error: No response data")
                    return
                }
                
                do {
                    let jsonResponse = try JSONDecoder().decode(CFAIResponse.self, from: data)
                    NSLog(String(jsonResponse.shape[0]) + ", " + String(jsonResponse.shape[1]))
                    if jsonResponse.data.count == 0 {
                        print("Error: vector has dimension 0")
                        return
                    }
                    var cos = self.cosineSimilarity(vector: InputController.convertFloat16ToFloat(input: jsonResponse.data[0]))
                   
                    var indicesOfTopTen = InputController.topTenIndices(array: cos)
                    var topTenEmojis: [String] = []
                    for idx in indicesOfTopTen {
                        topTenEmojis.append(emojiIndex[idx])
                        NSLog(emojiIndex[idx])
                    }
                    cloudSuggestions = topTenEmojis
                    
                    let filteredEmojiCanonical = filterWithLimit(dict: suggestionsEmojiCanonical, suggestionInput: suggestionInput)
                    if filteredEmojiCanonical.count < 9 {
                        await MainActor.run {
                            candidates.update()
                        }
                    }
                } catch {
                    print("Error parsing JSON")
                }
            }
        }
        task.resume()
    }
    
    override init!(server: IMKServer, delegate: Any, client inputClient: Any) {
        NSLog("Initializing keyboard")
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
        
        
        loadSuggestionArrays()
        loadCorpusEmbedding()
    }
    
    func loadSuggestionArrays() {
        let macroSymbols = CSVLoader.loadLatexMacroSymbols(fileName: Bundle.main.url(forResource: "latex_unicode", withExtension: "csv")!.path)
        let macroNicknames = CSVLoader.loadLatexMacroNicknames(fileName: Bundle.main.url(forResource: "latex_data", withExtension: "csv")!.path)
    
        guard let macroSymbols = macroSymbols else {
            return
        }
        for key in macroSymbols.keys {
            guard let symb = macroSymbols[key] else {
                continue
            }
            let replaced = symb.replacingOccurrences(of: "\\", with: "", options: .literal, range: nil)
            suggestionsLatexCanonical[key] = replaced
        }
        guard let macroNicknames = macroNicknames else {
            return
        }
        for key in macroNicknames.keys {
            let symbol = macroSymbols[String(key.dropFirst())]
            guard let nicknamesList = macroNicknames[key] else {
                continue
            }
            for nick_name in nicknamesList {
                suggestionsLatexSemantic[nick_name.lowercased()] = symbol
            }
                    
        }
        
        let emojiShortcodes = CSVLoader.loadEmojiFromShortcodes(fileName: Bundle.main.url(forResource: "emoji_transformed_stage_2", withExtension: "csv")!.path)
        guard let emojiShortcdes = emojiShortcodes else {
            return
        }
        for key in emojiShortcdes.keys {
            guard let shortcodesList = emojiShortcdes[key] else {
                continue
            }
            for shortcode in shortcodesList {
                suggestionsEmojiCanonical[shortcode] = key
            }
        }
        
        let macroIPA = CSVLoader.loadIPASymbols(fileName: Bundle.main.url(forResource: "phonetics", withExtension: "csv")!.path)
        guard let macroIPA = macroIPA else {
            return
        }
        suggestionsIPA = macroIPA
        
        let url = URL(string: "https://my-emoji.sidachen2003.workers.dev")!

        if let data = CSVLoader.loadEmojiDesc(fileName: Bundle.main.url(forResource: "emoji_desc", withExtension: "csv")!.path) {
            guard let data = try? JSONSerialization.data(withJSONObject: Array(data.values)) else {
                print("Error: unable to serialize")
                return
            }
        }
    }
    
    private func loadCorpusEmbedding() {
        NSLog("Loading corpus embedding")
        guard let url = Bundle.main.url(forResource: "emoji_index", withExtension: "json") else {
            NSLog("Bad URL")
            return
        }
        guard let res = CSVLoader.loadEmojiIndex(filename: url) else {
            NSLog("No emoji index")
            return
        }
        emojiIndex = res
        
        
        guard let url = Bundle.main.url(forResource: "emoji_desc_embeddings", withExtension: "json") else {
            NSLog("Bad URL")
            return
        }
        guard let res = CSVLoader.loadEmojiEmbeddings(filename: url) else {
            NSLog("No emoji embeddings")
            return
        }
        corpusEmbedding = res
    }

    override func candidates(_ sender: Any) -> [Any] {
        if suggestionInput.isEmpty {
            // Present EVERY suggestion to the user
            if isLatexOnly {
                return ["\\"] + removeDupes(arr: Array(suggestionsLatexCanonical.values.prefix(10)))
            }
            if isIPAOnly {
                return ["|"] + removeDupes(arr: Array(suggestionsLatexCanonical.values.prefix(10)))
            }
            return [":"] + removeDupes(arr: Array(suggestionsEmojiCanonical.values.prefix(10)))
        }
        
        var suggestions: [String] = []
        if isIPAOnly {
            suggestions.append("|" + suggestionInput)
        } else if isLatexOnly {
            suggestions.append("\\" + suggestionInput)
        } else {
            suggestions.append(":" + suggestionInput)
        }
        
        if !isLatexOnly && !isIPAOnly {
            // If the user wants emojis, show them emojis
            let filteredEmojiCanonical = filterWithLimit(dict: suggestionsEmojiCanonical, suggestionInput: suggestionInput)
        
            suggestions = suggestions + filteredEmojiCanonical
            
            if suggestions.count < 9 {
                if cloudSuggestions.count == 0 {
                    suggestions = suggestions + ["(thinking.)", "(thinking..)", "(thinking...)"]
                } else {
                    suggestions = suggestions + cloudSuggestions.prefix(3)
                }
            }
        }
        
        if isLatexOnly {
            let filteredLatexCanonical = filterWithLimit(dict: suggestionsLatexCanonical, suggestionInput: suggestionInput)
            let filteredLatexSemantic = filterWithLimit(dict: suggestionsLatexSemantic, suggestionInput: suggestionInput.lowercased())
            suggestions = suggestions + filteredLatexCanonical + filteredLatexSemantic
        }
        
        if isIPAOnly {
            var specified_prefixes: [String] = suggestionInput.lowercased().components(separatedBy: .whitespaces)
            
            suggestions += get_matched_ipa(specified_prefixes: specified_prefixes)
        }

        if suggestionInput.hasPrefix("sponge ") {
            let input = String(suggestionInput.dropFirst("sponge ".count))
            suggestions = [spongecase(input)]
        }
        if suggestionInput.hasPrefix("fancy ") {
            let input = String(suggestionInput.dropFirst("fancy ".count))
            suggestions = [cursiveMathematical(input)]
        }
        if suggestionInput.hasPrefix("rgb ") {
            let split = suggestionInput.split(separator: " ")
            if split.count == 4 {
                guard let r = Int(split[1]) else {
                    return removeDupes(arr: suggestions)
                }
                guard let g = Int(split[2]) else {
                    return removeDupes(arr: suggestions)
                }
                guard let b = Int(split[3]) else {
                    return removeDupes(arr: suggestions)
                }
                let hsv = rgbToHSV(r: r, g: g, b: b)
                let ret = "hsv " + String(hsv.h) + "° " + String(hsv.s) + "% " + String(hsv.v) + "%"
                suggestions.append(ret)
            }
        }
        if suggestionInput.hasPrefix("0x") {
            let input = String(suggestionInput.dropFirst("0x".count))
            guard let val = Int(input, radix: 16) else {
                return removeDupes(arr: suggestions)
            }
            suggestions.append(String(val))
        }
        if suggestionInput.hasPrefix("0b") {
            let input = String(suggestionInput.dropFirst("0b".count))
            guard let val = Int(input, radix: 2) else {
                return removeDupes(arr: suggestions)
            }
            suggestions.append(String(val))
        }
        
        return removeDupes(arr: suggestions)
    }
    
    private func get_matched_ipa(specified_prefixes: [String]) -> [String] {
        var result: [String] = []
        for ipa in suggestionsIPA {
            if ipa_matches(ipa: ipa, specified_prefixes: specified_prefixes) {
                result.append(ipa[0])
            }
        }
        return result
    }
    
    private func ipa_matches(ipa: [String], specified_prefixes: [String]) -> Bool {
        if specified_prefixes.isEmpty {
            return false
        }
        
        if let ipa_type = specified_prefixes[0].first {
            
            if ipa[1].lowercased() != String(ipa_type).lowercased() {
                return false
            }
            
            var first: Bool = true
            for pre in specified_prefixes {
                var match: Bool = false
                for i in 2..<ipa.count {
                    if first && pre.isEmpty {
                        return false
                    }
                    
                    if first {
                        let offsetIndex = pre.index(pre.startIndex, offsetBy: 1)
                        if ipa[i].hasPrefix(String(pre[offsetIndex..<pre.endIndex]).lowercased()) {
                            match = true
                            break
                        }
                    } else {
                        if ipa[i].hasPrefix(pre.lowercased()) {
                            match = true
                            break
                        }
                    }
                }
                
                first = false
                if !match {
                    return false
                }
            }
        } else {
            return false
        }
        return true
    }
    
    private func filterWithLimit(dict: Dictionary<String, String>, suggestionInput: String) -> [String] {
        var ret: [String] = []
        var count = 0
        for key in dict.keys {
            if key.hasPrefix(suggestionInput) {
                count += 1
                if let val = dict[key] {
                    ret.append(val)
                }
            }
//            if count > 10 {
//                break
//            }
        }
        return ret
    }

    override func candidateSelected(_ candidateString: NSAttributedString) {
        if candidateString.string == "(thinking.)" || candidateString.string == "(thinking..)" || candidateString.string == "(thinking...)" {
            return
        }
        insertText(text: candidateString.string)
        candidates.hide()
        stopSuggesting()
        lastCharacter = Character(" ")
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString) {
        NSLog("%@", "\(#function)")
    }

    private func startSuggestionInput(isLatexOnly: Bool, isIPAOnly: Bool) {
        isSuggesting = true;
        self.isLatexOnly = isLatexOnly;
        self.isIPAOnly = isIPAOnly;
        suggestionInput = "";
        cloudSuggestions = []
    }

    private func stopSuggesting() {
        isSuggesting = false;
        isLatexOnly = false;
        isIPAOnly = false;
        suggestionInput = "";
        debounceTimer?.invalidate()
        cloudSuggestions = []
    }

    override func handle(_ event: NSEvent, client sender: Any) -> Bool {
        if event.characters == ":" && !isLatexOnly && !isIPAOnly {
            if isSuggesting && candidates.isVisible() {
                let canonicalResult = suggestionsEmojiCanonical[suggestionInput]

                if let canonicalResult = canonicalResult {
                    insertText(text: canonicalResult)
                    stopSuggesting()
                    candidates.hide()
                    lastCharacter = Character(" ")
                    return true
                }
                insertText(text: ":" + suggestionInput + ":")
                stopSuggesting()
                candidates.hide()
                return true
            }
            if let lastCharacter = lastCharacter {
                if lastCharacter.isWhitespace {
                    startSuggestionInput(isLatexOnly: false, isIPAOnly: false)
                    candidates.update()
                    candidates.show()
                    return true
                }
            } else {
                startSuggestionInput(isLatexOnly: false, isIPAOnly: false)
                candidates.update()
                candidates.show()
                return true
            }
            return false
        }
        if event.characters == "\\" {
            startSuggestionInput(isLatexOnly: true, isIPAOnly: false)
            candidates.update()
            candidates.show()
            return true
        }
        if event.characters == "|" {
            startSuggestionInput(isLatexOnly: false, isIPAOnly: true)
            candidates.update()
            candidates.show()
            return true
        }
        if event.keyCode == kVK_Delete && candidates.isVisible() && isSuggesting {
            if suggestionInput.count == 0 {
                suggestionInput = "";
                isSuggesting = false;
                isLatexOnly = false;
                candidates.hide()
                return true
            }
            suggestionInput = String(suggestionInput.prefix(suggestionInput.count - 1))
            cloudSuggestions = []
            candidates.update()
            return true
        }
        if event.keyCode == kVK_Escape {
            onSuggestionDismiss()
            return false
        }
        if event.keyCode == kVK_Return {
            if candidates.isVisible() {
                candidates.interpretKeyEvents([ event ])
                return true
            }
            lastCharacter = Character(" ")
            return false
        }

        // The return value is whether the system interprets the keystroke with default behavior
        // If the event had no associated character, i.e. arrow keys, let the system do its thing
        // If the event was a character that should be typed, consume it
        if controlKeys.contains(Int(event.keyCode)) {
            if candidates.isVisible() {
                candidates.interpretKeyEvents([ event ])
                return true
            }
            return false
        }

        if let chars = event.characters {
            if chars.count != 0 {
                lastCharacter = chars.last!
            }
            if isSuggesting {
                suggestionInput += chars
                cloudSuggestions = []
                if !isLatexOnly {
                    debounceTimer?.invalidate()
                    debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
                        self?.requestSemanticEmojis()
                    }
                    NSLog("Triggering semantic emojis")
                }
            } else {
                insertText(text: chars)
            }
        }

        candidates.update()
        return true
    }

    func onSuggestionDismiss() {
        if isLatexOnly {
            insertText(text: "\\" + suggestionInput)
        } else if isIPAOnly {
            insertText(text: "|" + suggestionInput)
        } else {
            insertText(text: ":" + suggestionInput)
        }
        stopSuggesting()
        candidates.hide()
    }
        
    func spongecase(_ text: String) -> String {
        var result = ""
        for character in text {
            if Bool.random() {
                result += character.uppercased()
            } else {
                result += character.lowercased()
            }
        }
        return result
    }
    
    func cursiveMathematical(_ text: String) -> String {
        let mappings: [Character: String] = [
            "a": "𝒶", "b": "𝒷", "c": "𝒸", "d": "𝒹", "e": "ℯ", "f": "𝒻", "g": "ℊ",
            "h": "𝒽", "i": "𝒾", "j": "𝒿", "k": "𝓀", "l": "𝓁", "m": "𝓂", "n": "𝓃",
            "o": "ℴ", "p": "𝓅", "q": "𝓆", "r": "𝓇", "s": "𝓈", "t": "𝓉", "u": "𝓊",
            "v": "𝓋", "w": "𝓌", "x": "𝓍", "y": "𝓎", "z": "𝓏"
        ]
        var result = ""
        for char in text.lowercased() {
            if let cursiveChar = mappings[char] {
                result += cursiveChar
            } else {
                result += String(char)
            }
        }
        return result
    }
    
    func rgbToHSV(r: Int, g: Int, b: Int) -> (h: Int, s: Int, v: Int) {
        let rFloat = CGFloat(r) / 255.0
        let gFloat = CGFloat(g) / 255.0
        let bFloat = CGFloat(b) / 255.0

        let minVal = min(rFloat, gFloat, bFloat)
        let maxVal = max(rFloat, gFloat, bFloat)
        let delta = maxVal - minVal

        var h: CGFloat = 0
        var s: CGFloat = 0
        let v: CGFloat = maxVal

        if delta != 0 {
            s = delta / maxVal

            if rFloat == maxVal {
                h = (gFloat - bFloat) / delta
            } else if gFloat == maxVal {
                h = 2 + (bFloat - rFloat) / delta
            } else {
                h = 4 + (rFloat - gFloat) / delta
            }

            h *= 60
            if h < 0 {
                h += 360
            }
        }

        return (Int(h), Int(s * 100), Int(v * 100))
    }
    
    func cosineSimilarity(vector: [Float]) -> [Float] {
        let vectorMagnitude = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        
        return corpusEmbedding.map { corpusVector in
            let dotProduct = zip(vector, corpusVector).map { $0 * $1 }.reduce(0, +)
            let corpusVectorMagnitude = sqrt(corpusVector.map { $0 * $0 }.reduce(0, +))
            
            return dotProduct / (vectorMagnitude * corpusVectorMagnitude)
        }
    }
    
    static func convertFloat16ToFloat(input: [Float16]) -> [Float] {
        var output = [Float]()
        
        for value in input {
            output.append(Float(value))
        }
        
        return output
    }
    
    static func topTenIndices(array: [Float]) -> [Int] {
        let indexedArray = array.enumerated().map { ($0.element, $0.offset) }
        let sortedArray = indexedArray.sorted { $0.0 > $1.0 }
        let topTenIndices = sortedArray.prefix(10).map { $0.1 }
        
        return topTenIndices
    }

    func insertText(text: String) {
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }
}
