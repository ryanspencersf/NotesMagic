import SwiftUI
import Domain

struct LibraryRow: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Note body
            Text(note.body)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(3)
            
            // Meta info
            HStack {
                Text("Just now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Limited hashtags with overflow indicator
                let hashtags = extractHashtags(from: note.body)
                if !hashtags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(hashtags.prefix(2)), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        
                        if hashtags.count > 2 {
                            Text("+\(hashtags.count - 2)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Tertiary chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func extractHashtags(from text: String) -> [String] {
        let pattern = "#([A-Za-z0-9_\\-]+)"
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        return results.map { result in
            nsString.substring(with: result.range(at: 1)).lowercased()
        }
    }
}
