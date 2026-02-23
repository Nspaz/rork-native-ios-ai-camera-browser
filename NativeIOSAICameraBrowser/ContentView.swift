import SwiftUI

struct ContentView: View {
    @State private var pipeline = CameraPipeline()
    @State private var browserVM = BrowserViewModel()
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if browserVM.isLoading {
                ProgressView(value: max(0.02, browserVM.estimatedProgress))
                    .tint(.blue)
                    .animation(.easeInOut(duration: 0.2), value: browserVM.estimatedProgress)
            }

            WebViewContainer(viewModel: browserVM)

            bottomToolbar
        }
        .overlay(alignment: .topTrailing) {
            if pipeline.isRunning {
                statusPill
                    .padding(.trailing, 12)
                    .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(pipeline: pipeline)
        }
        .onAppear {
            pipeline.onFrameForWebView = { [weak browserVM] data in
                browserVM?.pushFrame(data)
            }
            pipeline.start()
        }
        .preferredColorScheme(.dark)
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
                    browserVM.isLoading ? browserVM.stopLoading() : browserVM.reload()
                } label: {
                    Image(systemName: browserVM.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
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

    private var statusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.green)
                .frame(width: 5, height: 5)
            Text("\(Int(pipeline.currentFPS))fps")
                .monospacedDigit()
            if pipeline.currentLatency > 0 {
                Text("\u{00B7}")
                Text("\(Int(pipeline.currentLatency))ms")
                    .monospacedDigit()
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}
