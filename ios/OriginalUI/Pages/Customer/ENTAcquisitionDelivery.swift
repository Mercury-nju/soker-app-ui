#if DEBUG
import Combine
import SwiftUI

struct ENTAcquisitionDelivery: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let need: String
    let contact: String
    let source: String
    let nextAction: String
    let avatar: String?

    var avatarAsset: String {
        let assets = ["ENTCustomerAvatar1", "ENTCustomerAvatar2", "ENTCustomerAvatar3", "ENTCustomerAvatar4"]
        if let avatar, assets.contains(avatar) { return avatar }
        if let suffix = id.split(separator: "_").last,
           let index = Int(suffix), index > 0 {
            return assets[(index - 1) % assets.count]
        }
        let index = id.utf8.reduce(0) { ($0 + Int($1)) % assets.count }
        return assets[index]
    }

    func matches(_ keyword: String) -> Bool {
        let query = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || [name, need, contact, source, nextAction]
            .contains { $0.localizedStandardContains(query) }
    }
}

@MainActor
final class ENTAcquisitionDeliveryStore: ObservableObject {
    static let shared = ENTAcquisitionDeliveryStore()
    private static let storageKey = "soker.acquisition.deliveries.v1"

    @Published private(set) var deliveries: [ENTAcquisitionDelivery]
    @Published private(set) var requestedCustomerID: String?

    private init() {
        let data = UserDefaults.standard.data(forKey: Self.storageKey)
        deliveries = data.flatMap { try? JSONDecoder().decode([ENTAcquisitionDelivery].self, from: $0) } ?? []
    }

    func receive(_ body: Any) {
        guard let fields = body as? [String: String],
              let data = try? JSONEncoder().encode(fields),
              let delivery = try? JSONDecoder().decode(ENTAcquisitionDelivery.self, from: data),
              !delivery.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !delivery.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var updated = deliveries
        if let index = updated.firstIndex(where: { $0.id == delivery.id }) {
            guard updated[index] != delivery else { return }
            updated[index] = delivery
        } else {
            updated.insert(delivery, at: 0)
        }
        guard let saved = try? JSONEncoder().encode(updated) else { return }
        UserDefaults.standard.set(saved, forKey: Self.storageKey)
        deliveries = updated
    }

    func requestCustomer(_ id: String) -> Bool {
        guard deliveries.contains(where: { $0.id == id }) else { return false }
        requestedCustomerID = id
        return true
    }

    func clearRequestedCustomer() {
        requestedCustomerID = nil
    }
}

struct ENTAcquisitionDeliveryCard: View {
    let delivery: ENTAcquisitionDelivery

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(delivery.avatarAsset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                Text(delivery.name)
                    .font(.headline)
            }
            Text(delivery.need)
                .font(.subheadline)
            Divider()
            detail("联系方式", delivery.contact.replacingOccurrences(
                of: "（(?:模拟，)?已同意联系）$",
                with: "",
                options: .regularExpression
            ))
            detail("来源", delivery.source)
            detail("跟进建议", delivery.nextAction)
        }
        .foregroundStyle(Color(uiColor: ENTAppColors.primaryText))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("ent_acquisition_delivered_customer")
    }

    @ViewBuilder
    private func detail(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .foregroundStyle(Color(uiColor: ENTAppColors.secondaryText))
                    .frame(minWidth: 64, alignment: .leading)
                Text(value)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.footnote)
        }
    }
}
#endif
