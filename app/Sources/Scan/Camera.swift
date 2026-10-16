import AVFoundation
import SwiftUI
import UIKit

/// A live back-camera session with one photo output. The preview layer shows
/// the menu; the shutter hands a JPEG to the scan.
final class Camera: NSObject, @unchecked Sendable, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "mise.camera")
    private var continuation: CheckedContinuation<Data?, Never>?
    private var configured = false

    /// False in the simulator and on devices without a back camera.
    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func start() async -> Bool {
        guard Self.isAvailable else { return false }
        var status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            status = await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        }
        guard status == .authorized else { return false }
        return await withCheckedContinuation { done in
            queue.async {
                self.configureIfNeeded()
                if !self.session.isRunning { self.session.startRunning() }
                done.resume(returning: self.session.isRunning)
            }
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    func capture() async -> Data? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.session.isRunning else { continuation.resume(returning: nil); return }
                self.continuation = continuation
                self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        queue.async {
            self.continuation?.resume(returning: photo.fileDataRepresentation())
            self.continuation = nil
        }
    }

    private func configureIfNeeded() {
        guard !configured,
              let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        configured = true
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
