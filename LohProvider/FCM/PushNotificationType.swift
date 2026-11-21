//
//  PushNotificationType.swift
//  CTF
//
//  Created by Mohamed Hadwa on 30/12/2025.
//


import Foundation

enum PushNotificationType: String {
    case newOffer = "new_offer_notification"
    case acceptTrip = "accept_trip_notification"
    case userCurrentTripTimeApproaching = "user_current_trip_time_approaching_notification"
    
    case captainInTheWayToStartingLocation = "captain_in_the_way_to_starting_location_notification"
    case captainArrivedStartingLocation = "captain_arrived_starting_location_notification"
    case captainStartTrip = "captain_start_trip_notification"
    
    case captainReceivedItem = "captain_received_item_notification"
    case captainItemReceived = "captain_item_received_notification"
    
    case captainArrivedAtDestination = "captain_arrived_at_destination_notification"
    case captainDeliveredItem = "captain_delivered_item_notification"
    case captainFinishTrip = "captain_finish_trip_notification"
    
    case captainRefuseWaitingRequest = "captain_refuse_waiting_request_notification"
    case captainAcceptWaitingRequest = "captain_accept_waiting_request_notification"
    case captainApproveFinishWaitingRequest = "captain_approve_finish_waiting_request_notification"
    case cancelTrip = "cancel_trip"
    
    case payAdditionalPricesForFinishedTrip = "pay_additional_prices_for_finished_trip_notification"
    case captainRateUser = "captain_rate_user_notification"
    
    case captainCancelTrip = "captain_cancel_trip_notification"
    case captainCancelTripForLateness = "captain_cancel_trip_for_lateness_notification"
    case tripCanceledTimeExceeded = "trip_canceled_time_exceeded_notification"
    
    case userPayTrip = "user_pay_trip_notification"
    
    case adminReplyComplaint = "admin_reply_complaint_notification"
    case adminAcceptSettlement = "admin_accept_settlement_notification"
    case adminRejectSettlement = "admin_reject_settlement_notification"
    
    case block = "block_notification"
    case deleteAccount = "delete_account_notification"
    case admin = "admin_notification"
    case pointsTransaction = "points_transaction_notification"
    
}

enum TripType: Int {
    case people = 1
    case surfaces = 2
    case goods = 3
}

struct PushPayload: Hashable {
    let type: PushNotificationType
    let tripId: Int?
    let tripType: TripType?
    let offerId: Int?
    let title: String?
    let body: String?
    
    init?(userInfo: [AnyHashable: Any]) {
        guard let typeString = userInfo["type"] as? String,
              let type = PushNotificationType(rawValue: typeString)
        else { return nil }
        
        self.type = type
        self.tripId = PushPayload.int(from: userInfo["trip_id"])
        self.tripType = PushPayload.int(from: userInfo["trip_type"]).flatMap(TripType.init(rawValue:))
        self.offerId = PushPayload.int(from: userInfo["offer_id"])
        self.title = userInfo["title"] as? String
        self.body = userInfo["body"] as? String
    }
    
    init(
        type: PushNotificationType,
        tripId: Int?,
        tripType: TripType?,
        offerId: Int?,
        title: String?,
        body: String?
    ) {
        self.type = type
        self.tripId = tripId
        self.tripType = tripType
        self.offerId = offerId
        self.title = title
        self.body = body
    }
    
    private static func int(from value: Any?) -> Int? {
        if let v = value as? Int { return v }
        if let v = value as? String { return Int(v) }
        if let v = value as? Double { return Int(v) }
        return nil
    }
}

extension Notification.Name {
    static let pushDidReceiveForeground = Notification.Name("ctf.push.didReceiveForeground")
    static let pushDidTap = Notification.Name("ctf.push.didTap")
    static let notificationsShouldRefresh = Notification.Name("ctf.notifications.shouldRefresh")
    static let tripShouldRefresh = Notification.Name("ctf.trip.shouldRefresh")
}
