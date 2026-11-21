//
//  NotificationPayloadData.swift
//  CTF
//
//  Created by Mohamed Hadwa on 30/12/2025.
//


import Foundation

struct NotificationPayloadData: Codable, Hashable {
    var offerId: Int?
    var tripId: Int?
    var tripType: Int?
    var price: Double?

    var bodyAr: String?
    var bodyEn: String?

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case tripId = "trip_id"
        case tripType = "trip_type"
        case price
        case bodyAr = "body_ar"
        case bodyEn = "body_en"
    }

    func toPushPayload(typeString: String?, title: String?, body: String?) -> PushPayload? {
        guard let typeString,
              let type = PushNotificationType(rawValue: typeString)
        else { return nil }

        return PushPayload(
            type: type,
            tripId: tripId,
            tripType: tripType.flatMap(TripType.init(rawValue:)),
            offerId: offerId,
            title: title,
            body: body
        )
    }
}
