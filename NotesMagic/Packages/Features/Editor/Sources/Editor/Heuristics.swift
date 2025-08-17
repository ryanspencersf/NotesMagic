import Foundation
import NaturalLanguage

enum Heuristics {
    static func inferTags(from text: String) -> [String] {
        // 1) Keep explicit hashtags
        let explicit = explicitTags(in: text)
        
        // 2) Named entities (People/Orgs/Places)
        let entities = entityCandidates(in: text)
        
        // 3) Keyword nouns (chunked so huge notes are fully scanned)
        let keywords = topKeywords(in: text)
        
        // 4) Merge & score (explicit >> entities >> keywords)
        var score: [String: Double] = [:]
        for t in explicit { score[t, default: 0] += 8 }
        for t in entities { score[t, default: 0] += 4 }
        for (t, w) in keywords { score[t, default: 0] += 1.5 * w }
        
        // 5) Filter junk and normalize
        let stop: Set<String> = ["the","this","that","with","from","about","https","http","com","and","for","you","your","will","can","have","has","had","was","were","been","being","would","could","should","may","might","must","shall"]
        let top = score
            .filter { !$0.key.isEmpty && !stop.contains($0.key) }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
        
        return Array(Set(explicit + top)).prefix(10).map { String($0) }
    }
    
    // Tag acceptance rule: filter out noise and gibberish
    static func acceptTag(_ t: String, countAcrossNotes: Int, isEntity: Bool) -> Bool {
        let tag = t.lowercased()
        let stop: Set<String> = ["the","this","that","with","and","for","you","your","note","notes","today"]
        if stop.contains(tag) { return false }
        if isEntity { return true }
        if countAcrossNotes >= 2 { return true } // stable
        // basic gibberish filter: needs a vowel and >=3 chars
        let vowels = CharacterSet(charactersIn: "aeiou")
        let hasVowel = tag.rangeOfCharacter(from: vowels) != nil
        return hasVowel && tag.count >= 3
    }
    
    private static func explicitTags(in text: String) -> [String] {
        let rx = try! NSRegularExpression(pattern: "#([A-Za-z0-9_\\-]+)")
        let ns = text as NSString
        return rx.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range(at: 1)).lowercased() }
    }
    
    private static func entityCandidates(in text: String) -> [String] {
        var out: [String] = []
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .nameType,
                             options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
            guard let tag, ["PersonalName","OrganizationName","PlaceName"].contains(tag.rawValue) else { return true }
            out.append(String(text[range]).lowercased())
            return true
        }
        return out
    }
    
    private static func topKeywords(in text: String) -> [(String, Double)] {
        // Chunk the WHOLE note by sentence so we don't blow memory
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        var counts: [String: Int] = [:]
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = text[range].lowercased()
            s.split { !"abcdefghijklmnopqrstuvwxyz0123456789-#".contains($0) }
                .map(String.init)
                .filter { $0.count >= 3 && !$0.hasPrefix("#") }
                .forEach { counts[$0, default: 0] += 1 }
            return true
        }
        
        let total = max(1, counts.values.reduce(0, +))
        return counts
            .map { ($0.key, Double($0.value) / Double(total)) }
            .sorted { $0.1 > $1.1 }
            .prefix(20)
            .map { ($0.0, $0.1) }
    }
}
