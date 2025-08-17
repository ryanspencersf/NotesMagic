import SwiftUI
import UIKit

struct TextView: UIViewRepresentable {
    @Binding var text: String
    var onPasted: (() -> Void)?
    
    func makeCoordinator() -> Coordinator { 
        Coordinator(self) 
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: TextView
        
        init(_ parent: TextView) { 
            self.parent = parent 
        }
        
        func textViewDidChange(_ textView: UITextView) { 
            parent.text = textView.text 
        }
        
        override func paste(_ sender: Any?) {
            parent.onPasted?()
            super.paste(sender)
        }
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = UIColor.clear
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.text = text
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
}
