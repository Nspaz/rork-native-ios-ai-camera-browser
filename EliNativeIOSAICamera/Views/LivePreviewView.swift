import SwiftUI
import UIKit

struct LivePreviewView: View {
    let pipeline: CameraPipeline
    let isFullscreen: Bool
    var onToggleFullscreen: () -> Void = {}

    var body: some View {
        ZStack {
            Color.black

            if let uiImage = pipeline.latestPreviewImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: isFullscreen ? .fit : .fill)
                    .allowsHitTesting(false)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white.opacity(0.6))
                    Text("Waiting for feed...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            if !isFullscreen {
                VStack {
                    HStack {
                        Spacer()
                        liveBadge
                            .padding(6)
                    }
                    Spacer()
                }
            }
        }
        .clipShape(.rect(cornerRadius: isFullscreen ? 0 : 12))
        .overlay {
            if !isFullscreen {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onToggleFullscreen() }
    }

    private var liveBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.red)
                .frame(width: 5, height: 5)
            Text("LIVE")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.black.opacity(0.6))
        .clipShape(Capsule())
    }
}

struct FullscreenPreviewView: View {
    let pipeline: CameraPipeline
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage = pipeline.latestPreviewImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .allowsHitTesting(false)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No Feed")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(16)

                    Spacer()

                    statsOverlay
                        .padding(16)
                }
                Spacer()

                HStack(spacing: 20) {
                    liveBadge
                    Text("\(Int(pipeline.currentFPS)) fps")
                        .monospacedDigit()
                    if pipeline.currentLatency > 0 {
                        Text("\(Int(pipeline.currentLatency)) ms")
                            .monospacedDigit()
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.5))
                .clipShape(Capsule())
                .padding(.bottom, 40)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private var statsOverlay: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("1280 x 720")
            Text("30 fps target")
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(.white.opacity(0.4))
    }

    private var liveBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
            Text("LIVE")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white)
        }
    }
}
