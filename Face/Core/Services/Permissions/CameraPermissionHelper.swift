import AVFoundation
import UIKit

enum CameraPermissionResult {
    case granted
    case denied(message: String)
}

enum CameraPermissionHelper {
    static let deniedMessage = "Camera access is required. Please allow Camera access in Settings."

    static func requestAccess(completion: @escaping (CameraPermissionResult) -> Void) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            completion(.denied(message: "Camera is unavailable on this device."))
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(.granted)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        completion(.granted)
                    } else {
                        completion(.denied(message: deniedMessage))
                    }
                }
            }
        case .denied, .restricted:
            completion(.denied(message: deniedMessage))
        @unknown default:
            completion(.denied(message: deniedMessage))
        }
    }

    static func openAppSettings() {
        guard
            let settingsURL = URL(string: UIApplication.openSettingsURLString),
            UIApplication.shared.canOpenURL(settingsURL)
        else {
            return
        }
        UIApplication.shared.open(settingsURL)
    }
}
