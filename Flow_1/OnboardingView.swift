//
//  OnboardingView.swift
//  Flow_1
//
//  First-run onboarding experience.
//

import SwiftUI

// MARK: - Onboarding Page Model

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "doc.text.viewfinder",
            title: "Smart PDF Conversion",
            subtitle: "Transform any PDF into a beautifully formatted EPUB using on-device AI — no cloud, no waiting."
        ),
        OnboardingPage(
            icon: "brain.head.profile",
            title: "Powered by AI",
            subtitle: "YOLO layout detection identifies text, tables, and images. Apple Intelligence refines the output for perfect readability."
        ),
        OnboardingPage(
            icon: "gift",
            title: "3 Free Conversions",
            subtitle: "Start with 3 free conversions. Upgrade anytime for unlimited access."
        )
    ]

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Action Bar (Skip)
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation {
                            hasSeenOnboarding = true
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                }

                // Page Content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        VStack(spacing: 24) {
                            Spacer()

                            Image(systemName: page.icon)
                                .font(.system(size: 80))
                                .foregroundStyle(.tint)
                                .accessibilityLabel(page.title)

                            Text(page.title)
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)

                            Text(page.subtitle)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always)) // Makes dots visible

                // Bottom Action Button
                VStack {
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            withAnimation {
                                hasSeenOnboarding = true
                            }
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                    .padding(.top, 16)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
