import SwiftUI

struct ContentView: View {
    @State private var pipeline = CameraPipeline()
    @State private var browserVM = BrowserViewModel()
    @State private var showSettings = false
    @State private var showFullscreenPreview = false
    @State private var showPiP = true
    @State private var pipOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if browserVM.isLoading {
                    ProgressView(value: max(0.02, browserVM.estimatedProgress))
                        .tint(.blue)
                        .animation(.easeInOut(duration: 0.2), value: browserVM.estimatedProgress)
                }

                WebViewContainer(viewModel: browserVM)

                bottomToolbar
            }

            if showPiP && pipeline.isRunning {
                pipPreview
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(pipeline: pipeline)
        }
        .fullScreenCover(isPresented: $showFullscreenPreview) {
            FullscreenPreviewView(pipeline: pipeline)
        }
        .onAppear {
            pipeline.onFrameForWebView = { [weak browserVM] data in
                browserVM?.pushFrame(data)
            }
            pipeline.start()
        }
        .preferredColorScheme(.dark)
    }

    private var pipPreview: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                LivePreviewView(pipeline: pipeline, isFullscreen: false) {
                    showFullscreenPreview = true
                }
                .frame(width: 140, height: 200)
                .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 4)
                .offset(x: pipOffset.width + dragOffset.width, y: pipOffset.height + dragOffset.height)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            pipOffset = CGSize(
                                width: pipOffset.width + value.translation.width,
                                height: pipOffset.height + value.translation.height
                            )
                            dragOffset = .zero
                        }
                )
                .padding(.trailing, 12)
                .padding(.bottom, 70)
            }
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(duration: 0.3), value: showPiP)
    }

    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 14) {
                Button { browserVM.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .disabled(!browserVM.canGoBack)

                Button { browserVM.goForward() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .disabled(!browserVM.canGoForward)

                HStack(spacing: 6) {
                    Image(systemName: browserVM.isLoading ? "circle.dotted" : "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    TextField("Search or enter address", text: $browserVM.urlText)
                        .font(.system(size: 14))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.webSearch)
                        .submitLabel(.go)
                        .onSubmit { browserVM.loadURL() }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(.systemGray5))
                .clipShape(.rect(cornerRadius: 10))

                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        showPiP.toggle()
                    }
                } label: {
                    Image(systemName: showPiP ? "pip.fill" : "pip")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(showPiP ? .blue : .primary)
                        .frame(width: 28, height: 28)
                }

                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}
