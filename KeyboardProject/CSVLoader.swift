import Foundation

public class CSVLoader {
    public static func loadLatexMacroSymbols(fileName: String) -> Dictionary<String, String>? {
        // Get the path of the CSV file in the main bundle
        var ret: Dictionary<String, String> = Dictionary<String, String>()

        do {
            let contents = try String(contentsOfFile: fileName)
            let lines = contents.components(separatedBy: "\n")
            for line in lines {
                let values = line.components(separatedBy: ",")
                if values.count < 2 {
                    continue
                }
                ret[String(values[0].dropFirst())] = values[1]
            }
        } catch {
            NSLog("Returning nil because error, symbols not loaded")
            return nil
        }
        NSLog("Loaded " + String(ret.keys.count) + " entries of symbols")
        return ret
    }
    
    public static func loadLatexMacroNicknames(fileName: String) -> Dictionary<String, [String]>? {
        // Get the path of the CSV file in the main bundle
        var ret: Dictionary<String, [String]> = Dictionary<String, [String]>()
        
        do {
            let contents = try String(contentsOfFile: fileName)
            let lines = contents.components(separatedBy: "\n")
            // Iterate over the remaining lines
            for line in lines {
                // Split the line into values
                let values = line.components(separatedBy: ",")
                if values.count < 2 {
                    continue
                }
                ret[values[0]] = Array(values[1...])
            }
        } catch {
            NSLog("Returning nil because error, symbols not loaded")
            return nil
        }
        NSLog("Loaded " + String(ret.keys.count) + " entries of nicknames")
        return ret
    }

    public static func loadEmojiFromShortcodes(fileName: String) -> Dictionary<String, [String]>? {
        var ret: Dictionary<String, [String]> = Dictionary<String, [String]>()
        
        do {
            let contents = try String(contentsOfFile: fileName)
            let lines = contents.components(separatedBy: "\n")
            // Iterate over the remaining lines
            for line in lines {
                // Split the line into values
                let values = line.components(separatedBy: ",")
                if values.count < 2 {
                    continue
                }
                ret[values[0]] = Array(values[1...])
            }
        } catch {
            NSLog("Returning nil because error, symbols not loaded")
            return nil
        }
        NSLog("Loaded " + String(ret.keys.count) + " entries of emoji shortcodes")
        return ret
    }
    
    public static func loadIPASymbols(fileName: String) -> Array<[String]>? {
        // Get the path of the CSV file in the main bundle
        var ret: Array<[String]> = Array<[String]>()

        do {
            let contents = try String(contentsOfFile: fileName)
            let lines = contents.components(separatedBy: "\n")
            for line in lines {
                let values = line.components(separatedBy: ",")
                
                if values.count > 2 {
                    if let ipa_type = values[1].first {
                        let terms = values[2].lowercased().components(separatedBy: .whitespacesAndNewlines)
                        ret.append([values[0], String(ipa_type)] + terms)
                    }
                }
            }
        } catch {
            NSLog("Returning nil because error, symbols not loaded")
            return nil
        }
        NSLog("Loaded " + String(ret.count) + " entries of IPA")
        return ret
    }
}
