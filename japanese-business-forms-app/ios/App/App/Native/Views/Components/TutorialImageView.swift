import SwiftUI

enum TutorialImageAsset {
    case onboardingStart
    case onboardingCompany
    case onboardingProducts
    case onboardingCustomers
    case onboardingForm
    case onboardingPreview
    case supportOverview

    var imageName: String {
        switch self {
        case .onboardingStart: return "OnboardingStartIllustration"
        case .onboardingCompany: return "OnboardingCompanyIllustration"
        case .onboardingProducts: return "OnboardingProductsIllustration"
        case .onboardingCustomers: return "OnboardingCustomersIllustration"
        case .onboardingForm: return "OnboardingFormIllustration"
        case .onboardingPreview, .supportOverview: return "OnboardingPreviewIllustration"
        }
    }
}

struct TutorialImageView: View {
    let asset: TutorialImageAsset
    let title: String
    let caption: String
    let badge: String

    var body: some View {
        Image(asset.imageName)
            .resizable()
            .scaledToFit()
            .aspectRatio(695.0 / 541.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(badge) \(title) \(caption)")
    }
}
