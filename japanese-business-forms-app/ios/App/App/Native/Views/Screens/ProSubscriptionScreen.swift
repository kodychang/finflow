import SwiftUI

struct ProSubscriptionScreen: View {
    @ObservedObject var purchaseService: PurchaseService
    let language: AppLanguage
    var onBack: (() -> Void)? = nil
    @State private var presentedSheet: ProSubscriptionSheet?

    private var content: ProSubscriptionContent {
        ProSubscriptionContent(
            language: language,
            monthlyPrice: purchaseService.displayMonthlyPrice,
            yearlyPrice: purchaseService.displayYearlyPrice
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ProPaymentNavigationBar(content: content, onBack: onBack) {
                Task {
                    await purchaseService.restorePurchases()
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ProNordicHeroSection(content: content)

                    if purchaseService.hasProAccess {
                        ProActiveCard(title: content.activeStatus, message: content.activeMessage)
                    } else {
                        ProPriceOverviewCard(
                            content: content,
                            isLoading: purchaseService.isLoading,
                            isMonthlyPurchaseAvailable: purchaseService.isProMonthlyProductAvailable,
                            isYearlyPurchaseAvailable: purchaseService.isProYearlyProductAvailable,
                            onMonthlyPurchase: {
                                Task {
                                    await purchaseService.purchasePro(.monthly)
                                }
                            },
                            onYearlyPurchase: {
                                Task {
                                    await purchaseService.purchasePro(.yearly)
                                }
                            }
                        )
                        ProLegalLinksCard(content: content)
                    }

                    ProTrustCard(content: content)
                    ProBenefitStrip(title: content.includedTitle, items: content.featureHighlights)
                    ProWorkflowCard(content: content)

                    ProOfferCodeCard(content: content, isLoading: purchaseService.isLoading) {
                        Task {
                            await purchaseService.presentOfferCodeRedemption()
                        }
                    }

                    if !purchaseService.statusMessage.isEmpty {
                        ProStatusCard(message: content.statusText(for: purchaseService.statusMessage))
                    }

                    ProComparisonCard(content: content)
                    ProFAQCard(title: content.faqTitle) {
                        presentedSheet = .purchaseFAQ
                    }
                    ProOriginalDetailsSection(content: content)

                    Text(content.proAccessNote)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 22)
            }
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
        .task {
            await purchaseService.refresh()
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .purchaseFAQ:
                ProPurchaseFAQScreen(content: content)
            }
        }
    }
}

private enum ProSubscriptionSheet: Identifiable {
    case purchaseFAQ

    var id: String {
        switch self {
        case .purchaseFAQ:
            return "purchaseFAQ"
        }
    }
}

private struct ProPaymentNavigationBar: View {
    let content: ProSubscriptionContent
    let onBack: (() -> Void)?
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.appInk)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(content.backTitle)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            Text(content.title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Button(action: onRestore) {
                Text(content.restoreTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .frame(width: 74, height: 44, alignment: .trailing)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color.appBackground.opacity(0.96))
        .overlay(Rectangle().fill(Color.appDivider.opacity(0.35)).frame(height: 1), alignment: .bottom)
    }
}

private struct ProNordicHeroSection: View {
    let content: ProSubscriptionContent

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text(content.heroKicker)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(content.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            ProNordicStamp()
                .frame(width: 128, height: 116)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 18)
        .padding(.top, 26)
        .padding(.bottom, 30)
        .background(
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(
                    colors: [
                        Color.proNordicAir,
                        Color.proNordicPaper,
                        Color.appPanel
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RoundedRectangle(cornerRadius: 80, style: .continuous)
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 250, height: 86)
                    .offset(x: 62, y: 32)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider.opacity(0.55)))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProNordicStamp: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.proNordicBlue.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)

            VStack(spacing: 7) {
                HStack(spacing: 5) {
                    ForEach(0..<4) { index in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(index == 3 ? Color.proNordicBlue : Color.proNordicMist)
                            .frame(width: 16, height: CGFloat(18 + index * 8))
                    }
                }

                Text("PRO")
                    .font(.caption.weight(.black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background(Color.proNordicBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                Capsule()
                    .fill(Color.proNordicGold)
                    .frame(width: 46, height: 5)
            }
            .padding(14)

            Image(systemName: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundColor(Color.proNordicGold)
                .offset(x: 34, y: -34)
        }
    }
}

private struct ProPriceOverviewCard: View {
    let content: ProSubscriptionContent
    let isLoading: Bool
    let isMonthlyPurchaseAvailable: Bool
    let isYearlyPurchaseAvailable: Bool
    let onMonthlyPurchase: () -> Void
    let onYearlyPurchase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(content.priceSectionTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appInk)
                Text(content.priceSectionSubtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 10) {
                ProPlanTile(
                    title: content.monthlyTitle,
                    term: content.monthlyTerm,
                    price: content.monthlyDisplayPrice,
                    badge: content.monthlyBadge,
                    note: content.monthlyDescription,
                    featureTitles: content.planFeatureBullets,
                    buttonTitle: content.monthlyPurchaseTitle,
                    loadingTitle: content.purchaseProcessingTitle,
                    unavailableTitle: content.purchaseUnavailableTitle,
                    systemImage: "calendar.badge.plus",
                    isProminent: true,
                    isLoading: isLoading,
                    isPurchaseAvailable: isMonthlyPurchaseAvailable,
                    action: onMonthlyPurchase
                )

                ProPlanTile(
                    title: content.yearlyTitle,
                    term: content.yearlyTerm,
                    price: content.yearlyDisplayPrice,
                    badge: content.yearlyBadge,
                    note: content.yearlyDescription,
                    featureTitles: content.planFeatureBullets,
                    buttonTitle: content.yearlyPurchaseTitle,
                    loadingTitle: content.purchaseProcessingTitle,
                    unavailableTitle: content.purchaseUnavailableTitle,
                    systemImage: "calendar",
                    isProminent: false,
                    isLoading: isLoading,
                    isPurchaseAvailable: isYearlyPurchaseAvailable,
                    action: onYearlyPurchase
                )
            }

            HStack(spacing: 6) {
                Capsule()
                    .fill(Color.proNordicBlue)
                    .frame(width: 16, height: 6)
                Circle()
                    .fill(Color.proNordicMist)
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(Color.proNordicMist)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ProPlanTile: View {
    let title: String
    let term: String
    let price: String
    let badge: String
    let note: String
    let featureTitles: [String]
    let buttonTitle: String
    let loadingTitle: String
    let unavailableTitle: String
    let systemImage: String
    let isProminent: Bool
    let isLoading: Bool
    let isPurchaseAvailable: Bool
    let action: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent

    private var isActionDisabled: Bool {
        isLoading || !isPurchaseAvailable
    }

    private var actionTitle: String {
        if isLoading {
            return loadingTitle
        }
        if !isPurchaseAvailable {
            return unavailableTitle
        }
        return buttonTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundColor(isProminent ? Color.proNordicGold : Color.proNordicBlue)
                    .frame(width: 26, height: 26)
                    .background((isProminent ? Color.proNordicGold : Color.proNordicBlue).opacity(0.12))
                    .clipShape(Circle())

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)

                Spacer(minLength: 0)

                }

                if isProminent {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.proNordicBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .offset(x: 6, y: -18)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(price)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.proPriceText)
                    .lineLimit(1)
                Text(term)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
            }

            Text(note)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(featureTitles, id: \.self) { feature in
                    Label(feature, systemImage: "checkmark.circle")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(1)
                }
            }
            .padding(.top, 8)
            .overlay(Rectangle().fill(Color.appDivider).frame(height: 1), alignment: .top)

            Spacer(minLength: 0)

            Button(action: action) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(isProminent ? .white : buttonAccent)
                    }
                    Text(actionTitle)
                        .lineLimit(1)
                }
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundColor(isProminent ? .white : buttonAccent)
                .background(isProminent ? Color.proNordicBlue : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(isProminent ? Color.clear : Color.proNordicGreen, lineWidth: 1.4))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isActionDisabled)
            .opacity(isActionDisabled ? 0.55 : 1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 268, alignment: .leading)
        .background(isProminent ? Color.proNordicPaper : Color.appInputBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isProminent ? Color.proNordicBlue.opacity(0.85) : Color.appDivider, lineWidth: isProminent ? 1.4 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(isProminent ? 0.08 : 0.045), radius: 14, x: 0, y: 8)
    }

}

private struct ProTrustCard: View {
    let content: ProSubscriptionContent

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title3.weight(.bold))
                .foregroundColor(Color.proNordicBlue)
                .frame(width: 48, height: 48)
                .background(Color.proNordicBlue.opacity(0.10))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(content.securePaymentTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                Text(content.securePaymentNote)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .proCard()
    }
}

private struct ProLegalLinksCard: View {
    let content: ProSubscriptionContent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(content.legalTitle, systemImage: "doc.text.magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)

            Text(content.legalSubtitle)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Link(destination: content.privacyPolicyURL) {
                    Label(content.privacyPolicyTitle, systemImage: "hand.raised.fill")
                }

                Link(destination: content.termsOfUseURL) {
                    Label(content.termsOfUseTitle, systemImage: "doc.plaintext.fill")
                }
            }
            .font(.caption.weight(.bold))
            .foregroundColor(Color.proNordicBlue)
        }
        .padding(14)
        .proCard()
    }
}

private struct ProBenefitStrip: View {
    let title: String
    let items: [ProFeatureHighlight]

    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: item.systemImage)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(item.tint)
                            .frame(width: 32, height: 32)
                            .background(item.tint.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appInk)
                            .lineLimit(2)

                        Text(item.subtitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.appMuted)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
                    .background(Color.appInputBackground)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(16)
        .proCard()
    }
}

private struct ProWorkflowCard: View {
    let content: ProSubscriptionContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(content.workflowTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appInk)
                Text(content.workflowSubtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                ForEach(Array(content.workflowItems.enumerated()), id: \.element.id) { index, item in
                    ProWorkflowRow(index: index + 1, item: item)
                }
            }
        }
        .padding(16)
        .proCard()
    }
}

private struct ProWorkflowRow: View {
    let index: Int
    let item: ProWorkflowItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(.caption.weight(.black))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(item.tint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                Text(item.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: item.systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundColor(item.tint)
                .frame(width: 32, height: 32)
                .background(item.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(10)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProHeroSection: View {
    let content: ProSubscriptionContent

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text(content.title)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(Color(red: 0.060, green: 0.110, blue: 0.250))
                    .lineLimit(2)

                Text(content.subtitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color(red: 0.330, green: 0.390, blue: 0.520))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            ProHeroIllustration()
                .frame(width: 112, height: 96)
                .accessibilityHidden(true)
        }
    }
}

private struct ProHeroIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.appBlue.opacity(0.12))
                .frame(width: 92, height: 92)
                .offset(x: 14, y: -8)

            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 42, height: 54)
                    .overlay(
                        VStack(alignment: .leading, spacing: 6) {
                            Capsule().fill(Color.appBlue.opacity(0.18)).frame(width: 26, height: 4)
                            Capsule().fill(Color.appBlue.opacity(0.12)).frame(width: 18, height: 4)
                            Spacer()
                        }
                        .padding(7)
                    )
                    .shadow(color: Color.appBlue.opacity(0.15), radius: 10, x: 0, y: 7)
                    .rotationEffect(.degrees(Double(index - 1) * 10))
                    .offset(x: CGFloat(index - 1) * 16, y: CGFloat(index) * -6)
            }

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.appBlue)
                .frame(width: 84, height: 48)
                .overlay(
                    Text("Pro")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                )
                .offset(y: 22)
                .shadow(color: Color.appBlue.opacity(0.30), radius: 12, x: 0, y: 9)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(Color(red: 0.300, green: 0.560, blue: 1.000))
                .background(Circle().fill(Color.white).frame(width: 28, height: 28))
                .scaleEffect(0.72)
                .offset(x: 42, y: 32)

            Image(systemName: "sparkle")
                .font(.headline.weight(.bold))
                .foregroundColor(Color(red: 0.320, green: 0.560, blue: 1.000))
                .offset(x: -44, y: -22)
        }
    }
}

private struct ProFeatureSummaryGrid: View {
    let items: [ProFeatureHighlight]

    private let columns = [
        GridItem(.adaptive(minimum: 118), spacing: 0)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(items) { item in
                VStack(spacing: 6) {
                    Image(systemName: item.systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(item.tint)
                        .frame(width: 34, height: 34)
                        .background(item.tint.opacity(0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appInk)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(item.subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: 104)
                .padding(.horizontal, 8)
                .padding(.vertical, 9)
            }
        }
        .proCard()
    }
}

private struct ProOfferCodeCard: View {
    let content: ProSubscriptionContent
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "app.gift.fill")
                .font(.title.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Color.appBlue)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(content.offerCodeTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                Text(content.offerCodeDescription)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: action) {
                Text(content.offerCodeSubmitTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .foregroundColor(Color.appBlue)
                    .overlay(Capsule().stroke(Color.appBlue, lineWidth: 1.5))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLoading)
            .opacity(isLoading ? 0.55 : 1)
        }
        .padding(14)
        .background(Color(red: 0.930, green: 0.970, blue: 1.000))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appBlue.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProComparisonCard: View {
    let content: ProSubscriptionContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(content.comparisonTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appInk)

                Text(content.comparisonSubtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                comparisonHeaderCell(content.freePlanHeader, tint: .appMuted)
                comparisonHeaderCell(content.proPlanHeader, tint: Color.appBlue)
            }

            VStack(spacing: 10) {
                ForEach(content.comparisonItems) { item in
                    ProComparisonRow(item: item)
                }
            }
        }
        .padding(16)
        .proCard()
    }

    private func comparisonHeaderCell(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(tint.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct ProComparisonRow: View {
    let item: ProComparisonItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(item.title, systemImage: item.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appInk)
                .lineLimit(2)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(item.tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            HStack(alignment: .top, spacing: 8) {
                comparisonValue(text: item.freeValue, systemImage: "lock.fill", tint: .appMuted)
                comparisonValue(text: item.proValue, systemImage: "checkmark.circle.fill", tint: Color.appBlue)
            }
        }
        .padding(10)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func comparisonValue(text: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundColor(tint)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundColor(tint)
        }
        .labelStyle(.titleAndIcon)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct ProFAQCard: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "questionmark.circle")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.appInk)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appInk)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.appInk)
            }
            .padding(18)
            .proCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ProPurchaseFAQScreen: View {
    let content: ProSubscriptionContent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(content.purchaseFAQSubtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(content.purchaseFAQCategories) { category in
                        ProFAQCategoryCard(category: category)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(content.faqTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(content.closeTitle) {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct ProFAQCategoryCard: View {
    let category: ProFAQCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(category.title, systemImage: category.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)

            ForEach(category.items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.question)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.answer)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.appMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)

                if item.id != category.items.last?.id {
                    Divider()
                }
            }
        }
        .padding(16)
        .proCard()
    }
}

private struct ProOriginalDetailsSection: View {
    let content: ProSubscriptionContent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionCard(title: content.freeTitle, titleWeight: .regular) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(content.freeNotes, id: \.self) { note in
                        Label(note, systemImage: "info.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            SectionCard(title: content.appStoreTitle, titleWeight: .regular) {
                Text(content.appStoreText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .proCard()
    }
}

private struct ProActiveCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "checkmark.seal.fill")
                .font(.headline.weight(.semibold))
                .foregroundColor(Color.appBlue)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appMuted)
        }
        .padding(18)
        .proCard(border: Color.appBlue.opacity(0.50), lineWidth: 2)
    }
}

private struct ProStatusCard: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "info.circle.fill")
            .font(.caption.weight(.bold))
            .foregroundColor(.appMuted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .proCard()
    }
}

private struct ProFeatureHighlight: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
}

private struct ProWorkflowItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
}

private struct ProComparisonItem: Identifiable {
    let id = UUID()
    let title: String
    let freeValue: String
    let proValue: String
    let systemImage: String
    let tint: Color
}

private struct ProFAQCategory: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let items: [ProFAQItem]
}

private struct ProFAQItem: Identifiable {
    let id: String
    let question: String
    let answer: String
}

private extension View {
    func proCard(border: Color? = nil, lineWidth: CGFloat = 1) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appPanel)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(border ?? Color.appDivider, lineWidth: lineWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: Color.black.opacity(0.055), radius: 15, x: 0, y: 8)
    }
}

private extension Color {
    static let proNordicBlue = Color(red: 0.180, green: 0.360, blue: 0.620)
    static let proNordicGreen = Color(red: 0.270, green: 0.560, blue: 0.470)
    static let proNordicMist = Color(red: 0.780, green: 0.870, blue: 0.900)
    static let proNordicAir = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.090, green: 0.120, blue: 0.160, alpha: 1)
            : UIColor(red: 0.920, green: 0.965, blue: 1.000, alpha: 1)
    })
    static let proNordicPaper = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.130, green: 0.160, blue: 0.185, alpha: 1)
            : UIColor(red: 0.965, green: 0.980, blue: 0.975, alpha: 1)
    })
    static let proNordicGold = Color(red: 0.820, green: 0.600, blue: 0.180)

    static let proPriceText = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.820, green: 0.890, blue: 1.000, alpha: 1)
            : UIColor(red: 0.060, green: 0.110, blue: 0.250, alpha: 1)
    })
}

private struct ProSubscriptionContent {
    let language: AppLanguage
    let monthlyPrice: String?
    let yearlyPrice: String?

    var title: String {
        localized(japanese: "Proプラン", chinese: "Pro 版本", english: "Pro Plan")
    }

    var backTitle: String {
        localized(japanese: "戻る", chinese: "返回", english: "Back")
    }

    var heroKicker: String {
        localized(japanese: "日本の帳票業務を、すっきり整える", chinese: "让日本表单业务更清爽有序", english: "Clean workflow for Japanese business forms")
    }

    var subtitle: String {
        localized(
            japanese: "Proにすると、PDFプレビューの共有とGoogle Driveバックアップを含むすべての機能を利用できます。",
            chinese: "升级 Pro 后，可使用包含 PDF 预览分享与 Google Drive 备份在内的全部功能。",
            english: "Pro unlocks every feature, including PDF preview sharing and Google Drive backup."
        )
    }

    var priceSectionTitle: String {
        localized(japanese: "料金プラン", chinese: "费用方案", english: "Pricing Plans")
    }

    var priceSectionSubtitle: String {
        localized(
            japanese: "Proは月額または年額の自動更新サブスクリプションです。最終価格はApp Storeの購入画面で確認してください。",
            chinese: "Pro 可选择月度或年度自动续订订阅。最终价格请以 App Store 购买页面显示为准。",
            english: "Pro is available as a monthly or yearly auto-renewable subscription. Confirm the final price in the App Store sheet."
        )
    }

    var includedTitle: String {
        localized(japanese: "Proで解放される機能", chinese: "Pro 解锁功能", english: "What Pro Unlocks")
    }

    var workflowTitle: String {
        localized(japanese: "現場から保存まで、迷わない流れ", chinese: "从现场到保存，流程更清楚", english: "A simple flow from worksite to archive")
    }

    var workflowSubtitle: String {
        localized(
            japanese: "北欧の道具のように静かに、必要な仕事だけを短く進められる設計です。",
            chinese: "像北欧工具一样安静克制，只把必要工作变得更短更顺。",
            english: "A quiet, Nordic-style workflow that keeps only the useful steps in front of you."
        )
    }

    var workflowItems: [ProWorkflowItem] {
        [
            ProWorkflowItem(
                title: localized(japanese: "無料で作成を始める", chinese: "免费开始创建", english: "Start creating for free"),
                subtitle: localized(japanese: "帳票作成、保存、マスタ管理などの基本機能を利用できます。", chinese: "可使用表单创建、保存、资料管理等基础功能。", english: "Use core form creation, saving, and profile management features."),
                systemImage: "folder.badge.plus",
                tint: Color.proNordicBlue
            ),
            ProWorkflowItem(
                title: localized(japanese: "帳票をつなげる", chinese: "连接相关表单", english: "Connect related forms"),
                subtitle: localized(japanese: "見積から請求、領収まで同じ流れで管理できます。", chinese: "从报价、请款到收据可放在同一流程中管理。", english: "Manage quote, invoice, and receipt work in one place."),
                systemImage: "doc.on.doc.fill",
                tint: Color.appMint
            ),
            ProWorkflowItem(
                title: localized(japanese: "共有とクラウド保管をProで使う", chinese: "用 Pro 使用分享与云端备份", english: "Use sharing and cloud backup with Pro"),
                subtitle: localized(japanese: "PDFプレビュー共有とGoogle DriveバックアップはProで利用できます。", chinese: "PDF 预览分享与 Google Drive 备份需使用 Pro。", english: "PDF preview sharing and Google Drive backup are available with Pro."),
                systemImage: "externaldrive.fill.badge.checkmark",
                tint: Color.proNordicGold
            )
        ]
    }

    var featureHighlights: [ProFeatureHighlight] {
        [
            ProFeatureHighlight(
                title: localized(japanese: "プレビュー共有\n解放", chinese: "预览分享\n解锁", english: "Preview\nSharing"),
                subtitle: localized(japanese: "PDFをそのまま共有", chinese: "直接分享 PDF", english: "Share PDFs"),
                systemImage: "square.and.arrow.up.fill",
                tint: Color.appBlue
            ),
            ProFeatureHighlight(
                title: localized(japanese: "Google Drive\nバックアップ", chinese: "Google Drive\n备份", english: "Google Drive\nBackup"),
                subtitle: localized(japanese: "機種変更・復元に備える", chinese: "便于换机与恢复", english: "For recovery"),
                systemImage: "externaldrive.fill.badge.checkmark",
                tint: Color(red: 0.430, green: 0.300, blue: 0.890)
            ),
            ProFeatureHighlight(
                title: localized(japanese: "会社・取引先・商品\nテンプレート管理", chinese: "公司客户商品\n模板管理", english: "Profiles and\nTemplates"),
                subtitle: localized(japanese: "継続利用で効率UP", chinese: "持续复用更高效", english: "Reuse and save time"),
                systemImage: "person.2.fill",
                tint: Color.appMint
            ),
            ProFeatureHighlight(
                title: localized(japanese: "すべてのPro機能\n利用可能", chinese: "所有 Pro 功能\n全部可用", english: "All Pro\nFeatures"),
                subtitle: localized(japanese: "制限なく利用", chinese: "不受限制", english: "No Pro limits"),
                systemImage: "checkmark.seal.fill",
                tint: Color(red: 0.940, green: 0.620, blue: 0.080)
            )
        ]
    }

    var activeStatus: String {
        localized(japanese: "Proが有効です", chinese: "Pro 已启用", english: "Pro is active")
    }

    var activeMessage: String {
        localized(
            japanese: "PDFプレビュー共有、Google Driveバックアップを含むすべての機能を利用できます。",
            chinese: "你可以使用包含 PDF 预览分享、Google Drive 备份在内的全部功能。",
            english: "You can use every feature, including PDF preview sharing and Google Drive backup."
        )
    }

    var monthlyTitle: String {
        localized(japanese: "月額プラン", chinese: "月度订阅", english: "Monthly Plan")
    }

    var monthlyTerm: String {
        localized(japanese: "/ 月", chinese: "/ 月", english: "/ month")
    }

    var monthlyDisplayPrice: String {
        monthlyPrice ?? "¥600 JPY"
    }

    var monthlyBadge: String {
        localized(japanese: "月額プラン", chinese: "月度方案", english: "Monthly plan")
    }

    var monthlyDescription: String {
        localized(japanese: "Proの全機能を利用できます。", chinese: "可使用 Pro 全部功能。", english: "Use every Pro feature.")
    }

    var monthlyPurchaseTitle: String {
        localized(japanese: "月額プランを開始する", chinese: "开始月度订阅", english: "Start Monthly Plan")
    }

    var yearlyTitle: String {
        localized(japanese: "年額プラン", chinese: "年度订阅", english: "Yearly Plan")
    }

    var yearlyTerm: String {
        localized(japanese: "/ 年", chinese: "/ 年", english: "/ year")
    }

    var yearlyDisplayPrice: String {
        yearlyPrice ?? "¥6,000 JPY"
    }

    var yearlyBadge: String {
        localized(japanese: "年額プラン", chinese: "年度方案", english: "Yearly plan")
    }

    var yearlyDescription: String {
        localized(japanese: "1年分のPro機能をまとめて利用できます。", chinese: "一次使用 1 年 Pro 全部功能。", english: "Use every Pro feature for one year.")
    }

    var yearlyPurchaseTitle: String {
        localized(japanese: "年額プランを開始する", chinese: "开始年度订阅", english: "Start Yearly Plan")
    }

    var purchaseProcessingTitle: String {
        localized(japanese: "購入画面を開いています", chinese: "正在打开购买页面", english: "Opening Purchase")
    }

    var purchaseUnavailableTitle: String {
        localized(japanese: "商品情報を取得できません", chinese: "无法取得商品信息", english: "Product Unavailable")
    }

    var securePaymentNote: String {
        localized(japanese: "お支払い情報はAppleにより安全に処理され、いつでも解約できます。", chinese: "支付信息由 Apple 安全处理，可随时取消订阅。", english: "Payment is processed securely by Apple, and you can cancel anytime.")
    }

    var securePaymentTitle: String {
        localized(japanese: "安心・安全な決済", chinese: "安心安全支付", english: "Secure Payment")
    }

    var planFeatureBullets: [String] {
        [
            localized(japanese: "PDFプレビューの共有", chinese: "PDF 预览分享", english: "PDF preview sharing"),
            localized(japanese: "Google Driveバックアップ", chinese: "Google Drive 备份", english: "Google Drive backup"),
            localized(japanese: "すべてのPro機能", chinese: "全部 Pro 功能", english: "All Pro features")
        ]
    }

    var offerCodeTitle: String {
        localized(japanese: "App Store コードをお持ちの方", chinese: "持有 App Store 兑换码", english: "Have an App Store Code?")
    }

    var offerCodeDescription: String {
        localized(
            japanese: "App Store Connectで発行されたプロモーションコードまたはオファーコードをお持ちの場合は、こちらから引き換えられます。",
            chinese: "如果你持有 App Store Connect 生成的 promo code 或 offer code，可在这里兑换。",
            english: "Redeem a promo code or offer code generated in App Store Connect."
        )
    }

    var offerCodeSubmitTitle: String {
        localized(japanese: "コードを引き換える", chinese: "兑换代码", english: "Redeem Code")
    }

    var comparisonTitle: String {
        localized(japanese: "無料版との違い", chinese: "与免费版的区别", english: "Free vs Pro")
    }

    var comparisonSubtitle: String {
        localized(
            japanese: "無料版で使える内容と、Proで解放される共有・バックアップ機能を確認できます。",
            chinese: "确认免费版可用内容，以及 Pro 解锁的分享与备份功能。",
            english: "Review what stays free and which sharing and backup features Pro unlocks."
        )
    }

    var freePlanHeader: String {
        localized(japanese: "無料版", chinese: "免费版", english: "Free")
    }

    var proPlanHeader: String {
        localized(japanese: "Pro", chinese: "Pro 付费版", english: "Pro")
    }

    var comparisonItems: [ProComparisonItem] {
        [
            ProComparisonItem(
                title: localized(japanese: "プロジェクト管理", chinese: "项目管理", english: "Project Management"),
                freeValue: localized(japanese: "無料版でもプロジェクトを作成・管理できます。", chinese: "免费版也可以创建并管理项目。", english: "Create and manage projects in the free plan."),
                proValue: localized(japanese: "同じプロジェクト機能に加え、共有とクラウドバックアップまで利用できます。", chinese: "在相同项目功能基础上，可继续使用分享与云端备份。", english: "Use the same project tools plus sharing and cloud backup."),
                systemImage: "infinity",
                tint: Color.appBlue
            ),
            ProComparisonItem(
                title: localized(japanese: "帳票作成・保存", chinese: "表单创建保存", english: "Forms"),
                freeValue: localized(japanese: "作成・保存などの基本機能を利用できます。", chinese: "可使用创建、保存等基础功能。", english: "Use core creation and saving features."),
                proValue: localized(japanese: "基本機能に加え、プレビュー共有とGoogle Driveバックアップを利用できます。", chinese: "除基础功能外，可使用预览分享与 Google Drive 备份。", english: "Use core features plus preview sharing and Google Drive backup."),
                systemImage: "doc.text.fill",
                tint: Color(red: 0.430, green: 0.300, blue: 0.890)
            ),
            ProComparisonItem(
                title: localized(japanese: "帳票種類", chinese: "表单类型", english: "Form Types"),
                freeValue: localized(japanese: "主要な帳票種類を作成できます。", chinese: "可创建主要表单类型。", english: "Create the main form types."),
                proValue: localized(japanese: "帳票作成に加え、共有・バックアップまで含めて運用できます。", chinese: "除表单创建外，也可完整使用分享与备份。", english: "Create forms and use the full sharing and backup workflow."),
                systemImage: "doc.on.doc.fill",
                tint: Color(red: 0.430, green: 0.300, blue: 0.890)
            ),
            ProComparisonItem(
                title: localized(japanese: "PDF出力・保存", chinese: "PDF 导出保存", english: "PDF Export"),
                freeValue: localized(japanese: "PDFプレビューを確認できます。プレビュー画面からの共有はPro機能です。", chinese: "可查看 PDF 预览；从预览画面分享属于 Pro 功能。", english: "View PDF previews. Sharing from the preview screen requires Pro."),
                proValue: localized(japanese: "プレビュー画面からPDFを書き出して共有できます。", chinese: "可从预览画面导出并分享 PDF。", english: "Export and share PDFs from the preview screen."),
                systemImage: "doc.richtext.fill",
                tint: Color(red: 0.900, green: 0.360, blue: 0.300)
            ),
            ProComparisonItem(
                title: localized(japanese: "会社情報管理", chinese: "公司信息管理", english: "Company Profiles"),
                freeValue: localized(japanese: "自社情報を保存し、帳票入力候補として利用できます。", chinese: "可保存公司信息，并在表单输入时调用。", english: "Save company details and reuse them as form input candidates."),
                proValue: localized(japanese: "同じ機能を利用できます。Proでは共有・バックアップもまとめて使えます。", chinese: "可使用相同功能；Pro 还可完整使用分享与备份。", english: "Use the same feature; Pro also includes sharing and backup."),
                systemImage: "building.columns.fill",
                tint: Color.appMint
            ),
            ProComparisonItem(
                title: localized(japanese: "取引先管理", chinese: "客户/供应商管理", english: "Customer and Vendor Profiles"),
                freeValue: localized(japanese: "顧客・仕入先の名称、担当者、連絡先、住所を保存して再利用できます。", chinese: "可保存客户/供应商名称、负责人、联系方式与地址并重复使用。", english: "Save and reuse customer/vendor names, contacts, emails, phone numbers, and addresses."),
                proValue: localized(japanese: "同じ管理機能に加え、必要な時に共有とクラウドバックアップを利用できます。", chinese: "除相同管理功能外，可在需要时使用分享与云端备份。", english: "Use the same management tools plus sharing and cloud backup when needed."),
                systemImage: "building.2.fill",
                tint: Color.appMint
            ),
            ProComparisonItem(
                title: localized(japanese: "商品・項目管理", chinese: "商品/品项管理", english: "Product and Item Management"),
                freeValue: localized(japanese: "商品名、仕様、型番、単価を保存し、明細入力を短縮できます。", chinese: "可保存商品名、规格、型号、单价，加快明细输入。", english: "Save item names, specs, models, and unit prices to speed up line entry."),
                proValue: localized(japanese: "同じ管理機能に加え、共有・バックアップまで利用できます。", chinese: "除相同管理功能外，可继续使用分享与备份。", english: "Use the same catalog tools plus sharing and backup."),
                systemImage: "person.2.fill",
                tint: Color.appMint
            ),
            ProComparisonItem(
                title: localized(japanese: "テンプレート管理", chinese: "模板管理", english: "Templates"),
                freeValue: localized(japanese: "振込先、備考、よく使う文言をテンプレート化できます。", chinese: "可将汇款信息、备注、常用文字做成模板。", english: "Create reusable templates for bank details, notes, and common wording."),
                proValue: localized(japanese: "テンプレートを使いながら、共有・バックアップも利用できます。", chinese: "使用模板的同时，也可使用分享与备份。", english: "Use templates together with sharing and backup."),
                systemImage: "text.badge.plus",
                tint: Color(red: 0.120, green: 0.620, blue: 0.760)
            ),
            ProComparisonItem(
                title: localized(japanese: "プロジェクト内の帳票管理", chinese: "项目内表单管理", english: "Project Document Management"),
                freeValue: localized(japanese: "プロジェクトごとに帳票を作成・関連付け・追加できます。", chinese: "可在每个项目内创建、关联、追加表单。", english: "Create, link, and add documents per project."),
                proValue: localized(japanese: "同じ帳票管理に加え、プレビュー共有とGoogle Driveバックアップを利用できます。", chinese: "除相同表单管理外，可使用预览分享与 Google Drive 备份。", english: "Use the same document management plus preview sharing and Google Drive backup."),
                systemImage: "folder.fill.badge.plus",
                tint: Color.appBlue
            ),
            ProComparisonItem(
                title: localized(japanese: "帳票コピー・移動", chinese: "表单复制/转入项目", english: "Copy Forms to Projects"),
                freeValue: localized(japanese: "既存帳票を別プロジェクトへコピーし、上書きまたは追加として整理できます。", chinese: "可将既有表单复制到其他项目，并选择覆盖或追加。", english: "Copy existing forms to another project and choose overwrite or append."),
                proValue: localized(japanese: "コピー後の帳票も、Proならプレビュー共有とクラウドバックアップに対応します。", chinese: "复制后的表单在 Pro 中也可使用预览分享与云端备份。", english: "Copied forms can also use preview sharing and cloud backup with Pro."),
                systemImage: "doc.on.clipboard.fill",
                tint: Color.appBlue
            ),
            ProComparisonItem(
                title: localized(japanese: "データ共有", chinese: "数据分享", english: "Sharing"),
                freeValue: localized(japanese: "PDFプレビュー画面からの共有は利用できません。", chinese: "不能使用 PDF 预览画面的分享功能。", english: "Sharing from the PDF preview screen is unavailable."),
                proValue: localized(japanese: "プレビュー画面からPDFを共有できます。", chinese: "可从预览画面分享 PDF。", english: "Share PDFs from the preview screen."),
                systemImage: "square.and.arrow.up.fill",
                tint: Color(red: 0.940, green: 0.620, blue: 0.080)
            ),
            ProComparisonItem(
                title: localized(japanese: "Google Driveバックアップ", chinese: "Google Drive 备份", english: "Google Drive Backup"),
                freeValue: localized(japanese: "Google Driveバックアップは利用できません。", chinese: "不能使用 Google Drive 备份。", english: "Google Drive backup is unavailable."),
                proValue: localized(japanese: "Google Driveへバックアップし、端末変更や復元に備えられます。", chinese: "可备份到 Google Drive，方便换机与恢复。", english: "Back up to Google Drive for device changes and recovery."),
                systemImage: "externaldrive.fill.badge.checkmark",
                tint: Color(red: 0.160, green: 0.650, blue: 0.380)
            ),
            ProComparisonItem(
                title: localized(japanese: "ローカルバックアップ", chinese: "本机备份", english: "Local Backup"),
                freeValue: localized(japanese: "端末内のバックアップファイルを作成・復元できます。", chinese: "可创建并恢复本机备份文件。", english: "Create and restore local backup files."),
                proValue: localized(japanese: "ローカルバックアップに加えてGoogle Driveバックアップも利用できます。", chinese: "除本机备份外，也可使用 Google Drive 备份。", english: "Use local backup plus Google Drive backup."),
                systemImage: "archivebox.fill",
                tint: Color(red: 0.160, green: 0.650, blue: 0.380)
            ),
            ProComparisonItem(
                title: localized(japanese: "オフライン利用", chinese: "离线使用", english: "Offline Use"),
                freeValue: localized(japanese: "ネットワークなしでも作成・保存できます。", chinese: "无网络也能创建与保存。", english: "Create and save without a network."),
                proValue: localized(japanese: "オフライン作業後に、PDF共有やGoogle Driveバックアップへ進めます。", chinese: "离线作业后，可继续 PDF 分享或 Google Drive 备份。", english: "After offline work, share PDFs or back up to Google Drive."),
                systemImage: "wifi.slash",
                tint: Color(red: 0.520, green: 0.460, blue: 0.900)
            ),
            ProComparisonItem(
                title: localized(japanese: "業務データの継続利用", chinese: "业务数据持续复用", english: "Reusable Business Data"),
                freeValue: localized(japanese: "自社、取引先、商品、テンプレート、プロジェクトを蓄積できます。", chinese: "可持续累积公司、客户、商品、模板与项目资料。", english: "Build reusable company, customer, item, template, and project data."),
                proValue: localized(japanese: "蓄積したデータをGoogle Driveバックアップで守れます。", chinese: "可用 Google Drive 备份保护已累积资料。", english: "Protect accumulated data with Google Drive backup."),
                systemImage: "database.fill",
                tint: Color(red: 0.300, green: 0.530, blue: 0.920)
            ),
            ProComparisonItem(
                title: localized(japanese: "サポート・購入復元", chinese: "支持与恢复购买", english: "Support and Restore"),
                freeValue: localized(japanese: "購入復元は対象外です。", chinese: "无付费权益可恢复。", english: "No paid entitlement to restore."),
                proValue: localized(japanese: "同じApple IDで購入復元でき、技術的な反映問題はサポートへ相談できます。", chinese: "可用同一 Apple ID 恢复购买，权益同步问题可联系支持。", english: "Restore with the same Apple ID and contact support for entitlement sync issues."),
                systemImage: "checkmark.seal.fill",
                tint: Color.appBlue
            )
        ]
    }

    var faqTitle: String {
        localized(japanese: "よくある質問", chinese: "常见问题", english: "Frequently Asked Questions")
    }

    var freeTitle: String {
        localized(japanese: "無料版について", chinese: "关于免费版", english: "Free Plan")
    }

    var freeNotes: [String] {
        [
            localized(japanese: "無料版でも帳票作成とプロジェクト管理を始められます。", chinese: "免费版也可以开始创建表单并管理项目。", english: "The free plan can create forms and manage projects."),
            localized(japanese: "帳票作成、保存、プロジェクト管理、マスタ管理などの基本機能は無料で利用できます。", chinese: "表单创建、保存、项目管理、资料管理等基础功能可免费使用。", english: "Core features such as form creation, saving, projects, and profiles are free."),
            localized(japanese: "無料版ではPDFプレビュー画面の共有とGoogle Driveバックアップを利用できません。", chinese: "免费版不能使用 PDF 预览画面分享与 Google Drive 备份。", english: "The free plan cannot use PDF preview sharing or Google Drive backup.")
        ]
    }

    var appStoreTitle: String {
        localized(japanese: "App Storeでの購入", chinese: "App Store 购买说明", english: "App Store Purchase")
    }

    var appStoreText: String {
        localized(
            japanese: "Proは月額または年額の自動更新サブスクリプションです。価格と更新条件はApp Storeの購入画面に表示される内容が優先されます。管理と解約はApple IDのサブスクリプション設定から行えます。",
            chinese: "Pro 是月度或年度自动续订订阅。价格与续订条件以 App Store 购买页面显示为准。订阅管理与取消可在 Apple ID 的订阅设置中进行。",
            english: "Pro is a monthly or yearly auto-renewable subscription. The price and renewal terms shown on the App Store purchase sheet apply. Manage or cancel it in Apple ID subscription settings."
        )
    }

    var legalTitle: String {
        localized(japanese: "購入前に確認", chinese: "购买前确认", english: "Before You Subscribe")
    }

    var legalSubtitle: String {
        localized(
            japanese: "購入前にプライバシーポリシーと利用規約（EULA）を確認できます。",
            chinese: "购买前可查看隐私政策与使用条款（EULA）。",
            english: "Review the Privacy Policy and Terms of Use (EULA) before subscribing."
        )
    }

    var privacyPolicyTitle: String {
        localized(japanese: "プライバシーポリシー", chinese: "隐私政策", english: "Privacy Policy")
    }

    var termsOfUseTitle: String {
        localized(japanese: "利用規約（EULA）", chinese: "使用条款（EULA）", english: "Terms of Use (EULA)")
    }

    var privacyPolicyURL: URL {
        URL(string: "https://niix.jp/shokopolicy/")!
    }

    var termsOfUseURL: URL {
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    }

    var proAccessNote: String {
        localized(
            japanese: "ProではPDFプレビュー共有とGoogle Driveバックアップを含むすべての機能を利用できます。",
            chinese: "Pro 可使用包含 PDF 预览分享与 Google Drive 备份在内的全部功能。",
            english: "Pro includes every feature, including PDF preview sharing and Google Drive backup."
        )
    }

    var restoreTitle: String {
        localized(japanese: "購入を復元", chinese: "恢复购买", english: "Restore Purchases")
    }

    var closeTitle: String {
        localized(japanese: "閉じる", chinese: "关闭", english: "Close")
    }

    var purchaseFAQSubtitle: String {
        localized(
            japanese: "購入前の確認、決済中のトラブル、購入後の管理、請求・返金、技術的な反映問題をまとめています。",
            chinese: "这里整理售前确认、购买中问题、售后管理、账单退款与权益同步等技术问题。",
            english: "Review pre-sales checks, purchase issues, post-purchase management, billing, refunds, and technical entitlement problems."
        )
    }

    var purchaseFAQCategories: [ProFAQCategory] {
        [
            ProFAQCategory(
                id: "preSales",
                title: localized(japanese: "購入前", chinese: "售前问题", english: "Before Purchase"),
                systemImage: "cart.badge.questionmark",
                items: [
                    ProFAQItem(
                        id: "preSalesDifference",
                        question: localized(japanese: "Proの料金はいくらですか？", chinese: "Pro 的价格是多少？", english: "How much does Pro cost?"),
                        answer: localized(japanese: "Proは月額サブスクリプションです。PDFプレビュー共有、Google Driveバックアップを含むすべてのPro機能を利用できます。最終価格はApp Storeの購入画面で確認してください。", chinese: "Pro 是月度订阅方案，可使用包含 PDF 预览分享、Google Drive 备份在内的全部 Pro 功能。最终价格请以 App Store 购买页面显示为准。", english: "Pro is a monthly subscription and includes every Pro feature, including PDF preview sharing and Google Drive backup. Confirm the final price in the App Store sheet.")
                    ),
                    ProFAQItem(
                        id: "preSalesFeatures",
                        question: localized(japanese: "Proで何が使えるようになりますか？", chinese: "Pro 会解锁哪些功能？", english: "What does Pro unlock?"),
                        answer: localized(japanese: "ProではPDFプレビュー画面からの共有、Google Driveバックアップを含むすべての機能を利用できます。", chinese: "Pro 可使用 PDF 预览画面分享、Google Drive 备份在内的全部功能。", english: "Pro enables every feature, including sharing from the PDF preview screen and Google Drive backup.")
                    ),
                    ProFAQItem(
                        id: "preSalesDevice",
                        question: localized(japanese: "別の端末でも使えますか？", chinese: "换设备后还能使用吗？", english: "Can I use Pro on another device?"),
                        answer: localized(japanese: "同じApple IDでApp Storeにサインインし、購入を復元してください。App Storeの購入情報からPro権限を確認します。", chinese: "可以。请在新设备使用同一个 Apple ID 登录 App Store，然后点“恢复购买”。App 会通过 App Store 购买记录确认 Pro 权益。", english: "Yes. Sign in to the App Store with the same Apple ID on the new device and use Restore Purchases. The app checks Pro access through App Store purchase records.")
                    )
                ]
            ),
            ProFAQCategory(
                id: "duringPurchase",
                title: localized(japanese: "購入中", chinese: "购买中问题", english: "During Purchase"),
                systemImage: "creditcard.fill",
                items: [
                    ProFAQItem(
                        id: "duringAppleSheet",
                        question: localized(japanese: "購入画面で表示される価格がアプリ内表示と違う場合は？", chinese: "Apple 购买弹窗价格和 App 页面不一致怎么办？", english: "What if the App Store sheet shows a different price?"),
                        answer: localized(japanese: "最終的な価格、税、更新条件はAppleの購入画面に表示される内容が優先されます。購入前に必ずAppleの画面で確認してください。", chinese: "最终价格、税费和续订条件以 Apple 购买弹窗显示为准。确认后再完成购买。", english: "The final price, taxes, and renewal terms shown on Apple's purchase sheet take precedence. Confirm them before completing the purchase.")
                    ),
                    ProFAQItem(
                        id: "duringPending",
                        question: localized(japanese: "購入が承認待ちのままです。", chinese: "购买一直显示等待批准怎么办？", english: "The purchase is still pending. What should I do?"),
                        answer: localized(japanese: "ファミリー共有の承認、支払い確認、通信状況により保留されることがあります。承認完了後にアプリへ戻り、必要に応じて購入を復元してください。", chinese: "可能是家庭共享批准、支付验证或网络状态导致等待。批准完成后回到 App，必要时点击恢复购买。", english: "Purchases can remain pending because of Family Sharing approval, payment verification, or network conditions. After approval, return to the app and restore purchases if needed.")
                    ),
                    ProFAQItem(
                        id: "duringCode",
                        question: localized(japanese: "プロモーションコードやオファーコードはどこで入力しますか？", chinese: "Promo code / offer code 在哪里兑换？", english: "Where do I redeem a promo code or offer code?"),
                        answer: localized(japanese: "Pro画面のApp Storeコード欄からAppleのコード引き換え画面を開き、コードを入力してください。反映されない場合は購入を復元してください。", chinese: "在 Pro 页面里的 App Store 兑换码区域打开 Apple 兑换页并输入代码。兑换后未同步时，请点击恢复购买。", english: "Use the App Store Code section on the Pro page to open Apple's redemption sheet. If access does not sync after redeeming, use Restore Purchases.")
                    )
                ]
            ),
            ProFAQCategory(
                id: "afterPurchase",
                title: localized(japanese: "購入後", chinese: "售后问题", english: "After Purchase"),
                systemImage: "checkmark.seal.fill",
                items: [
                    ProFAQItem(
                        id: "afterNotActive",
                        question: localized(japanese: "購入したのにProが有効になりません。", chinese: "已经购买但 Pro 没有生效怎么办？", english: "I purchased Pro but it is not active."),
                        answer: localized(japanese: "同じApple IDでサインインしているか確認し、通信状態が良い場所で購入を復元してください。それでも反映されない場合は、購入日時、Apple IDの国/地域、表示されるメッセージを控えてサポートへ連絡してください。", chinese: "请确认当前 App Store 使用的是购买时的 Apple ID，并在网络稳定时点击恢复购买。如果仍未生效，请记录购买时间、Apple ID 国家/地区和页面提示后联系支持。", english: "Confirm you are using the same Apple ID, then restore purchases with a stable connection. If it still does not activate, contact support with the purchase time, Apple ID country/region, and any message shown.")
                    ),
                    ProFAQItem(
                        id: "afterCancel",
                        question: localized(japanese: "サブスクリプションはどこで解約できますか？", chinese: "订阅在哪里取消？", english: "Where can I cancel the subscription?"),
                        answer: localized(japanese: "iOSの設定アプリからApple ID、サブスクリプションを開き、このアプリの月額プランを管理・解約できます。アプリ内ではAppleのサブスクリプション設定を直接変更できません。", chinese: "请到 iOS 设置 App，进入 Apple ID 的订阅页面，管理或取消本 App 的月度订阅。App 内不能直接修改 Apple 订阅设置。", english: "Open the iOS Settings app, go to Apple ID Subscriptions, then manage or cancel this app's monthly plan. The app cannot directly change Apple subscription settings.")
                    ),
                    ProFAQItem(
                        id: "afterData",
                        question: localized(japanese: "解約すると作成済みデータは消えますか？", chinese: "取消订阅后已创建的数据会消失吗？", english: "Will my existing data be deleted if I cancel?"),
                        answer: localized(japanese: "作成済みのローカルデータは自動削除されません。ただしPro権限が終了すると、PDFプレビュー共有とGoogle Driveバックアップは利用できなくなります。", chinese: "已创建的本地数据不会自动删除。但 Pro 权益结束后，将不能使用 PDF 预览分享与 Google Drive 备份。", english: "Existing local data is not automatically deleted. When Pro access ends, PDF preview sharing and Google Drive backup become unavailable.")
                    )
                ]
            ),
            ProFAQCategory(
                id: "finance",
                title: localized(japanese: "請求・返金", chinese: "财务与退款", english: "Billing and Refunds"),
                systemImage: "yensign.circle.fill",
                items: [
                    ProFAQItem(
                        id: "financeReceipt",
                        question: localized(japanese: "領収書や請求明細はどこで確認できますか？", chinese: "发票或收据在哪里查看？", english: "Where can I find receipts or billing details?"),
                        answer: localized(japanese: "App Store購入の領収書や請求明細はApple IDの購入履歴、またはAppleから届くメールで確認できます。アプリ側では領収書を発行できません。", chinese: "App Store 购买的收据和账单请在 Apple ID 购买记录或 Apple 发送的邮件中查看。App 本身不能开具 Apple 订单收据。", english: "Receipts and billing details for App Store purchases are available in your Apple ID purchase history or Apple's receipt emails. The app cannot issue Apple order receipts.")
                    ),
                    ProFAQItem(
                        id: "financeRefund",
                        question: localized(japanese: "返金はできますか？", chinese: "可以退款吗？", english: "Can I request a refund?"),
                        answer: localized(japanese: "App Storeの返金可否はAppleが審査します。Appleの返金申請ページから該当購入を選び、理由を入力して申請してください。", chinese: "App Store 退款由 Apple 审核决定。请通过 Apple 退款申请页面选择对应订单并提交原因。", english: "Refund eligibility is reviewed by Apple. Use Apple's refund request page, select the purchase, provide a reason, and submit the request.")
                    ),
                    ProFAQItem(
                        id: "financeDoubleCharge",
                        question: localized(japanese: "二重請求に見える場合は？", chinese: "看起来被重复扣费怎么办？", english: "What if I think I was charged twice?"),
                        answer: localized(japanese: "一時的な承認枠や税表示により重複に見える場合があります。Apple IDの購入履歴で確定請求を確認し、不明な場合はAppleサポートへ連絡してください。", chinese: "有时预授权、税费显示或银行记录会看起来像重复扣费。请以 Apple ID 购买记录中的最终订单为准，不明确时联系 Apple 支持。", english: "Temporary authorizations, taxes, or bank entries can look like duplicate charges. Check the final charge in Apple ID purchase history and contact Apple Support if unclear.")
                    )
                ]
            ),
            ProFAQCategory(
                id: "technical",
                title: localized(japanese: "技術・同期", chinese: "技术与同步", english: "Technical and Sync"),
                systemImage: "wrench.and.screwdriver.fill",
                items: [
                    ProFAQItem(
                        id: "technicalNetwork",
                        question: localized(japanese: "購入復元が失敗します。", chinese: "恢复购买失败怎么办？", english: "Restore Purchases fails. What should I check?"),
                        answer: localized(japanese: "ネットワーク接続、App Storeへのサインイン、スクリーンタイムや購入制限を確認してください。時間を置いて再試行すると解決する場合があります。", chinese: "请检查网络连接、App Store 登录状态、屏幕使用时间或购买限制。稍后重试通常可以解决临时失败。", english: "Check network connectivity, App Store sign-in, Screen Time, and purchase restrictions. Retrying later can resolve temporary App Store issues.")
                    ),
                    ProFAQItem(
                        id: "technicalRegion",
                        question: localized(japanese: "国や地域を変更した後にProが反映されません。", chinese: "更改 Apple ID 国家/地区后 Pro 没有同步怎么办？", english: "Pro does not sync after changing Apple ID country or region."),
                        answer: localized(japanese: "App Storeの国/地域変更後は購入情報の反映に時間がかかることがあります。同じApple IDでサインインし、購入履歴を確認してから復元してください。", chinese: "更改 App Store 国家/地区后，购买记录同步可能需要时间。请确认使用同一个 Apple ID，并在购买记录可见后再恢复购买。", english: "After changing App Store country or region, purchase information can take time to sync. Use the same Apple ID and restore purchases after the purchase appears in history.")
                    ),
                    ProFAQItem(
                        id: "technicalSupportInfo",
                        question: localized(japanese: "サポートへ連絡する時に必要な情報は？", chinese: "联系支持时需要提供哪些信息？", english: "What information should I provide to support?"),
                        answer: localized(japanese: "端末名、iOSバージョン、アプリバージョン、購入方法（月額/コード）、発生時刻、表示メッセージ、購入復元を試したかをお知らせください。", chinese: "请提供设备型号、iOS 版本、App 版本、购买方式（月度订阅/兑换码）、发生时间、页面提示，以及是否尝试过恢复购买。", english: "Provide device model, iOS version, app version, purchase method (monthly/code), time of issue, message shown, and whether Restore Purchases was tried.")
                    ),
                    ProFAQItem(
                        id: "technicalSupportContact",
                        question: localized(japanese: "技術サポートの連絡先は？", chinese: "技术支持的联络邮箱是什么？", english: "How can I contact technical support?"),
                        answer: localized(japanese: "技術的な問題やPro権限の反映問題は service@niix.jp までご連絡ください。", chinese: "技术问题或 Pro 权益同步问题，请联系 service@niix.jp。", english: "For technical issues or Pro entitlement sync problems, contact service@niix.jp.")
                    )
                ]
            )
        ]
    }

    func statusText(for key: String) -> String {
        switch key {
        case "productUnavailable":
            return localized(japanese: "商品情報を取得できませんでした。", chinese: "无法取得商品信息。", english: "Product information could not be loaded.")
        case "purchaseComplete":
            return localized(japanese: "購入が完了しました。", chinese: "购买完成。", english: "Purchase completed.")
        case "purchaseCancelled":
            return localized(japanese: "購入をキャンセルしました。", chinese: "已取消购买。", english: "Purchase cancelled.")
        case "purchasePending":
            return localized(japanese: "購入承認待ちです。", chinese: "购买正在等待批准。", english: "Purchase is pending approval.")
        case "restoreComplete":
            return localized(japanese: "購入を復元しました。", chinese: "已恢复购买。", english: "Purchases restored.")
        case "restoreEmpty":
            return localized(japanese: "復元できる購入は見つかりませんでした。", chinese: "未找到可恢复的购买。", english: "No purchases were found to restore.")
        case "restoreFailed":
            return localized(japanese: "購入を復元できませんでした。", chinese: "无法恢复购买。", english: "Purchases could not be restored.")
        case "offerCodeSheetPresented":
            return localized(japanese: "Appleのコード引き換え画面を開きました。引き換え後、アプリに戻ってください。", chinese: "已打开 Apple 兑换页面。兑换完成后请返回 App。", english: "Apple's redemption sheet is open. Return to the app after redeeming.")
        case "offerCodeRedeemed":
            return localized(japanese: "コードの引き換えが反映されました。Proが有効です。", chinese: "兑换结果已同步。Pro 已启用。", english: "The redeemed code has been applied. Pro is active.")
        default:
            return localized(japanese: "購入処理を完了できませんでした。", chinese: "购买处理未能完成。", english: "The purchase could not be completed.")
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}
