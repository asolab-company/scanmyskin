import SwiftUI
import UIKit
import Combine

struct LoadingScreenView: View {
    let onFinished: () -> Void
    @StateObject private var driver = LoadingProgressDriver(duration: 2.0)

    private var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
        ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
        ?? "App"
    }

    var body: some View {
        SplashBrandingView(appName: appName, showProgress: true, progress: driver.progress)
            .onAppear {
                driver.start {
                    onFinished()
                }
            }
            .onDisappear {
                driver.stop()
            }
    }
}

struct SplashBrandingView: View {
    let appName: String
    let showProgress: Bool
    let progress: Double

    private var progressPercent: Int {
        min(100, max(0, Int(floor(progress * 100))))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "C4A2D7"), Color(hex: "806297")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 168, height: 168)
                        .blur(radius: 6)

                    if UIImage(named: "app_ic_coach") != nil {
                        Image("app_ic_coach")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 129, height: 129)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 84, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }

                Text(appName)
                    .font(.system(size: 40 * 0.57, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 18)

                Spacer()

                if showProgress {
                    VStack(spacing: 10) {
                        Text("\(progressPercent)%")
                            .font(.system(size: 24 * 0.57, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .monospacedDigit()

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.28))
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: proxy.size.width * progress)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 48)
                    .padding(.bottom, 54)
                }
            }
        }
    }
}

final class LoadingProgressDriver: ObservableObject {
    @Published private(set) var progress: Double = 0

    private let duration: Double
    private var displayLink: CADisplayLink?
    private var startTimestamp: CFTimeInterval?
    private var completion: (() -> Void)?

    init(duration: Double) {
        self.duration = duration
    }

    func start(onFinish: @escaping () -> Void) {
        stop()
        progress = 0
        completion = onFinish

        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        } else {
            link.preferredFramesPerSecond = 60
        }
        startTimestamp = nil
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        startTimestamp = nil
        completion = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        if startTimestamp == nil {
            startTimestamp = link.timestamp
        }
        guard let startTimestamp else { return }

        let elapsed = link.timestamp - startTimestamp
        let value = min(1.0, elapsed / duration)

        if progress != value {
            progress = value
        }

        if value >= 1.0 {
            link.invalidate()
            displayLink = nil
            let onDone = completion
            completion = nil
            onDone?()
        }
    }

    deinit {
        stop()
    }
}

#Preview("Loading") {
    LoadingScreenView(onFinished: {})
}

#Preview("Launch Style") {
    SplashBrandingView(appName: "Scan My Skin", showProgress: false, progress: 0)
}
