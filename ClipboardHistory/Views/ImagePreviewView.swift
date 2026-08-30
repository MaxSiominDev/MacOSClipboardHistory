import SwiftUI
import AppKit

struct ImagePreviewView: View {
    let image: NSImage
    let size: CGSize

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
            Image(nsImage: image)
                .resizable()
                .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
    }
}
