import Foundation

public class CSVLoader {
    public static func loadMacroSymbols(fileName: String) -> Dictionary<String, String>? {
        // Get the path of the CSV file in the main bundle
        var ret: Dictionary<String, String> = Dictionary<String, String>()

        do {
            let contents = try String(contentsOfFile: fileName)
            NSLog(contents)
            let lines = contents.components(separatedBy: "\n")
            // Iterate over the remaining lines
            for line in lines {
                NSLog(line)
                // Split the line into values
                let values = line.components(separatedBy: ",")
                if values.count < 2 {
                    continue
                }
                NSLog(values[0] + values[1])
                ret[values[0]] = ret[values[1]]
            }
        } catch {
            NSLog("Returning nil because error, symbols not loaded")
            return nil
        }
        NSLog("Loaded " + String(ret.keys.count) + " entries of symbols")
        return ret
    }
    
    public static func loadMacroNicknames(fileName: String) -> Dictionary<String, [String]>? {
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

}
