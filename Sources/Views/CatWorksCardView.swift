import AppKit
import SwiftUI

/// Rehosting the transient popover must not start a second installer or lose its progress.
@MainActor
private enum CatWorksInstallSession {
    static let installer = CatWorksInstaller()
}

/// Catpacity retains provider allowances; CatWorks owns the live office and work details.
@MainActor
struct CatWorksCardView: View {
    @ObservedObject var store: CatWorksStore
    @StateObject private var installer = CatWorksInstallSession.installer
    private var installationAllowed: Bool {
        #if CATPACITY_VERIFICATION
        return false
        #else
        return true
        #endif
    }

    private var status: String {
        if installer.isInstalling { return "설치 중" }
        if store.isLoading && !store.isConnected { return "연결 확인 중" }
        if store.isConnected { return "사무실 연결됨" }
        return store.isInstalled ? "사무실 대기 중" : "AI 팀의 사무실"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "pawprint.fill").foregroundColor(.green)
                Text("CatWorks").font(.system(size: 13, weight: .bold))
                Spacer()
                Text(status).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).disabled(store.isLoading || installer.isInstalling)
                    .help("사무실 연결 새로고침").accessibilityLabel("사무실 연결 새로고침")
            }

            if let url = store.previewURL {
                preview(url)
            } else if store.isConnected {
                Text("팀이 일하는 사무실을 열어보세요.").font(.system(size: 12, weight: .semibold))
                Text("현재 CatWorks 버전은 작은 미리보기를 지원하지 않아요. 사무실과 통계는 바로 열 수 있어요.")
                    .font(.system(size: 10)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if store.isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("이 Mac의 사무실을 확인하고 있어요.").font(.system(size: 11)).foregroundColor(.secondary)
                }.padding(.vertical, 6)
            } else if store.isInstalled {
                Text("사무실을 열고 팀의 진행 상황을 확인하세요.")
                    .font(.system(size: 12, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                Text("CatWorks를 실행하면 이곳에 사무실이 보여요.").font(.system(size: 10)).foregroundColor(.secondary)
            } else {
                Text("AI 팀이 일하는 모습을 만나보세요.").font(.system(size: 12, weight: .semibold))
                Text("CatWorks에서 업무를 맡기고, 고양이가 함께하는 사무실에서 진행 상황을 확인할 수 있어요.")
                    .font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if store.isInstalled || store.isConnected {
                    Button(store.isOpening ? "사무실 여는 중…" : "사무실 열기") { Task { await store.openOffice() } }
                        .buttonStyle(.borderedProminent).tint(.green).disabled(store.isOpening)
                    if store.isConnected {
                        Button("통계 보기") { Task { await store.openOffice(statistics: true) } }
                            .buttonStyle(.bordered).disabled(store.isOpening)
                    }
                } else if !store.isLoading {
                    Button(installer.isInstalling ? "설치 중…" : "다운로드 및 설치") {
                        Task { await installer.install(); await store.refresh() }
                    }.buttonStyle(.borderedProminent).tint(.green).disabled(installer.isInstalling || !installationAllowed)
                }
                if installer.errorMessage != nil {
                    Button("다운로드 페이지") { NSWorkspace.shared.open(CatWorksInstaller.releasesURL) }.buttonStyle(.bordered)
                }
            }.controlSize(.small)

            if let message = installer.statusMessage {
                Text(message).font(.system(size: 10)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let message = installer.errorMessage ?? store.openError {
                Text(message).font(.system(size: 10)).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true)
            } else if store.isInstalled, !store.isConnected, !store.isLoading, let message = store.errorMessage {
                Text(message).font(.system(size: 10)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.2)))
    }

    private func preview(_ url: URL) -> some View {
        let session = store.previewSessionID
        return VStack(alignment: .leading, spacing: 6) {
            if let error = store.previewError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).font(.system(size: 11)).foregroundColor(.secondary)
                    Button("미리보기 다시 보기") { store.retryPreview() }.controlSize(.small)
                }.frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            } else {
                ZStack {
                    CatWorksOfficePreview(url: url, store: store, session: session) {
                        failed in store.previewFinished(session: session, failed: failed)
                    }.id(session)
                    if store.previewIsLoading {
                        Color(nsColor: .controlBackgroundColor)
                        ProgressView("사무실 불러오는 중…").font(.system(size: 10)).controlSize(.small)
                    }
                    Button { Task { await store.openOffice() } } label: { Color.clear.contentShape(Rectangle()) }
                        .buttonStyle(.plain).disabled(store.isOpening)
                        .accessibilityLabel("현재 사무실 미리보기, 사무실 열기")
                }
                .aspectRatio(CGFloat(CatWorksContract.previewWidth) / CGFloat(CatWorksContract.previewHeight), contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.08)))
                Text("실시간 사무실 · 눌러서 크게 보기").font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
    }
}
