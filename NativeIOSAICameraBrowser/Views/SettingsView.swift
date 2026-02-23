import SwiftUI

struct SettingsView: View {
    let pipeline: CameraPipeline
    @AppStorage("transformServerURL") private var savedServerURL: String = ""
    @AppStorage("referenceImageURL") private var savedReferenceURL: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Status") {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(pipeline.isRunning ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(pipeline.isRunning ? "Active" : "Stopped")
                                .foregroundStyle(pipeline.isRunning ? .primary : .secondary)
                        }
                    }
                    if pipeline.isRunning {
                        LabeledContent("Frame Rate") {
                            Text("\(Int(pipeline.currentFPS)) fps")
                                .monospacedDigit()
                        }
                        LabeledContent("Latency") {
                            Text("\(Int(pipeline.currentLatency)) ms")
                                .monospacedDigit()
                        }
                    }
                    Button(pipeline.isRunning ? "Stop Pipeline" : "Start Pipeline") {
                        pipeline.isRunning ? pipeline.stop() : pipeline.start()
                    }
                } header: {
                    Text("Camera Pipeline")
                }

                Section {
                    TextField("https://your-server.com/transform", text: $savedServerURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("Transformation Server")
                } footer: {
                    Text("POST endpoint receiving multipart frames. Leave empty for passthrough (raw camera feed).")
                }

                Section {
                    TextField("https://example.com/reference.jpg", text: $savedReferenceURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("Reference Image")
                } footer: {
                    Text("Target appearance reference sent alongside each frame for AI transformation.")
                }

                Section {
                    LabeledContent("Endpoint") {
                        Text("http://127.0.0.1:8080/avatar.mjpeg")
                            .font(.caption)
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Local MJPEG Server")
                } footer: {
                    Text("External access to the transformed camera stream on the device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        pipeline.updateServerURL(savedServerURL)
                        pipeline.updateReferenceURL(savedReferenceURL)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
