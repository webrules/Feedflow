import SwiftUI

struct FullScreenImageView: View {
    let imageURL: String
    @Binding var isPresented: Bool
    @State private var rotation: Double = 0

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(.white)
                case .success(let image):
                    image.resizable()
                         .aspectRatio(contentMode: .fit)
                         .rotationEffect(.degrees(rotation))
                         .scaleEffect(scale)
                         .offset(offset)
                         .contentShape(Rectangle())
                         .simultaneousGesture(panGesture)
                         .simultaneousGesture(zoomGesture)
                         .onTapGesture(count: 2) {
                             withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                 let targetScale = Self.scaleAfterDoubleTap(
                                     currentScale: scale,
                                     minScale: minScale,
                                     zoomScale: 2.5
                                 )
                                 if targetScale == minScale {
                                     resetZoom()
                                 } else {
                                     scale = targetScale
                                     lastScale = targetScale
                                 }
                             }
                         }
                case .failure:
                    Text("failed_load_image".localized())
                        .foregroundColor(.white)
                @unknown default:
                    EmptyView()
                }
            }

            // UI Controls overlay
            VStack {
                HStack {
                    Button(action: { isPresented = false }) {
                        FeedflowSymbol(name: FeedflowIcon.close, size: 30, color: .white)
                            .padding()
                    }
                    Spacer()
                }

                Spacer()

                HStack(spacing: 40) {
                    Button(action: {
                        withAnimation {
                            rotation -= 90
                        }
                    }) {
                        VStack {
                            FeedflowSymbol(name: "rotate.left.fill", size: 24, color: .white)
                            Text("rotate_left".localized())
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                    }

                    Button(action: {
                        withAnimation {
                            rotation += 90
                        }
                    }) {
                        VStack {
                            FeedflowSymbol(name: "rotate.right.fill", size: 24, color: .white)
                            Text("rotate_right".localized())
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = Self.clampScale(lastScale * value, min: minScale, max: maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        resetZoom()
                    }
                }
            }
    }

    /// Clamp a proposed zoom factor to the supported range so pinch gestures
    /// can never shrink below 1x or blow past the max.
    static func clampScale(_ value: CGFloat, min minScale: CGFloat, max maxScale: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minScale), maxScale)
    }

    static func scaleAfterDoubleTap(
        currentScale: CGFloat,
        minScale: CGFloat,
        zoomScale: CGFloat
    ) -> CGFloat {
        currentScale > minScale ? minScale : zoomScale
    }

    static func offsetAfterDrag(
        lastOffset: CGSize,
        translation: CGSize,
        scale: CGFloat,
        minScale: CGFloat
    ) -> CGSize {
        guard scale > minScale else { return lastOffset }
        return CGSize(
            width: lastOffset.width + translation.width,
            height: lastOffset.height + translation.height
        )
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = Self.offsetAfterDrag(
                    lastOffset: lastOffset,
                    translation: value.translation,
                    scale: scale,
                    minScale: minScale
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func resetZoom() {
        scale = minScale
        lastScale = minScale
        offset = .zero
        lastOffset = .zero
    }
}
