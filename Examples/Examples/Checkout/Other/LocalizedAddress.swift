//
//  LocalizedAddress.swift
//  Examples
//
//  Created by jefferson.setiawan on 21/03/24.
//

import CoreLocation
import Foundation

public typealias WarehouseID = String
public typealias ShopID = String
public enum LocalizedAddress: Equatable {
    case district(DistrictAddress)
    case full(FullAddress)

    /**
     Default `LocalizedAddress` that will be used for fallback logic
     */
    public static var `default`: Self {
        .district(.init(
            districtId: 2274,
            districtName: "",
            cityId: 176,
            cityName: "Jakarta Pusat",
            postalCode: nil,
            coordinate: nil,
            tokoNow: LocalizedAddress.TokoNow.empty
        ))
    }

    /**
     Filter out deleted address
     */
    public var valid: LocalizedAddress? {
        switch self {
        case .district:
            return self
        case let .full(address):
            if address.status == .deleted {
                return nil
            } else {
                return self
            }
        }
    }
}

// MARK: - Helper
public typealias DistrictID = Int
public typealias CityID = Int

extension LocalizedAddress {
    /**
     DistrictID
     */
    @inlinable
    public var districtId: DistrictID {
        switch self {
        case let .district(address):
            return address.districtId
        case let .full(address):
            return address.districtId
        }
    }

    /**
     CityID
     */
    @inlinable
    public var cityId: CityID {
        switch self {
        case let .district(address):
            return address.cityId
        case let .full(address):
            return address.cityId
        }
    }

    /**
     addressId
     */
    @inlinable
    public var addressId: FullAddress.ID? {
        switch self {
        case .district:
            return nil
        case let .full(address):
            return address.id
        }
    }

    /**
     Coordinate
     */
    @inlinable
    public var coordinate: CLLocationCoordinate2D? {
        switch self {
        case let .district(address):
            return address.coordinate
        case let .full(address):
            return address.coordinate
        }
    }

    /**
     Postal code
     */
    @inlinable
    public var postalCode: String? {
        switch self {
        case let .district(address):
            return address.postalCode
        case let .full(address):
            return address.postalCode
        }
    }

    /**
     Toko Now value like warehouseId, and shopId.
     */
    @inlinable
    public var tokoNow: TokoNow {
        get {
            switch self {
            case let .full(address):
                return address.tokoNow
            case let .district(address):
                return address.tokoNow
            }
        }
        set {
            switch self {
            case let .full(address):
                var newAddress = address
                newAddress.tokoNow = newValue

                self = .full(newAddress)
            case let .district(address):
                var newAddress = address
                newAddress.tokoNow = newValue

                self = .district(newAddress)
            }
        }
    }
}

// MARK: - Codable

extension LocalizedAddress: Codable {
    public enum CodingKeys: String, CodingKey {
        case id = "addr_id"
        case name = "addr_name"
        case receiverName = "receiver_name"
        case phoneNumber = "phone"
        case address = "address_1"
        case postalCode = "postal_code"
        case cityId = "city"
        case cityName = "city_name"
        case districtId = "district"
        case districtName = "district_name"
        case latitude
        case longitude
        case status
        case tokoNow
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let _status = try container.decode(Int.self, forKey: .status)
        let districtId = try container.decode(DistrictID.self, forKey: .districtId)
        let districtName = try container.decode(String.self, forKey: .districtName)
        let cityId = try container.decode(CityID.self, forKey: .cityId)
        let cityName = try container.decode(String.self, forKey: .cityName)
        let latitude = (try? container.decode(String.self, forKey: .latitude))
        let longitude = (try? container.decode(String.self, forKey: .longitude))

        /// we set decode if present because the value on network request
        /// is not inside the same coding keys, but when saved on persistance storage, it does.
        /// you can see on `AddressLocalizationService.AddressResponse`, tokoNow value will be injected from different decoder container
        let tokoNow = try container.decodeIfPresent(TokoNow.self, forKey: .tokoNow) ?? TokoNow.empty

        // 4 is district address
        if _status == 4 {
            self = .district(.init(
                districtId: districtId,
                districtName: districtName,
                cityId: cityId,
                cityName: cityName,
                postalCode: (try? container.decode(String.self, forKey: .postalCode)),
                coordinate: {
                    guard
                        let latitude = latitude,
                        let longitude = longitude,
                        let _latitude = Double(latitude),
                        let _longitude = Double(longitude)
                    else { return nil }

                    return CLLocationCoordinate2D(latitude: _latitude, longitude: _longitude)
                }(),
                tokoNow: tokoNow
            ))
            // else is full address
        } else {
            self = .full(LocalizedAddress.FullAddress(
                id: try container.decode(FullAddress.ID.self, forKey: .id),
                name: try container.decode(String.self, forKey: .name),
                receiverName: try container.decode(String.self, forKey: .receiverName),
                phoneNumber: try container.decodeIfPresent(String.self, forKey: .phoneNumber),
                address: try container.decodeIfPresent(String.self, forKey: .address),
                postalCode: try container.decode(String.self, forKey: .postalCode),
                districtId: districtId,
                districtName: districtName,
                cityId: cityId,
                cityName: cityName,
                status: FullAddress.Status(rawValue: _status) ?? .deleted,
                coordinate: {
                    guard
                        let latitude = latitude,
                        let longitude = longitude,
                        let _latitude = Double(latitude),
                        let _longitude = Double(longitude)
                    else { return nil }

                    return CLLocationCoordinate2D(latitude: _latitude, longitude: _longitude)
                }(),
                tokoNow: tokoNow
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .district(address):
            try container.encode(address.districtId, forKey: .districtId)
            try container.encode(address.districtName, forKey: .districtName)
            try container.encode(address.cityId, forKey: .cityId)
            try container.encode(address.cityName, forKey: .cityName)
            try container.encode(address.postalCode, forKey: .postalCode)
            try container.encode(address.tokoNow, forKey: .tokoNow)

            if let coordinate = address.coordinate {
                try container.encode(String(coordinate.latitude), forKey: .latitude)
                try container.encode(String(coordinate.longitude), forKey: .longitude)
            }

            try container.encode(4, forKey: .status)
        case let .full(address):
            try container.encode(address.id, forKey: .id)
            try container.encode(address.name, forKey: .name)
            try container.encode(address.receiverName, forKey: .receiverName)
            try container.encode(address.phoneNumber, forKey: .phoneNumber)
            try container.encode(address.address, forKey: .address)

            try container.encode(address.districtId, forKey: .districtId)
            try container.encode(address.districtName, forKey: .districtName)
            try container.encode(address.cityId, forKey: .cityId)
            try container.encode(address.cityName, forKey: .cityName)
            try container.encode(address.postalCode, forKey: .postalCode)
            try container.encode(address.tokoNow, forKey: .tokoNow)

            if let coordinate = address.coordinate {
                try container.encode(String(coordinate.latitude), forKey: .latitude)
                try container.encode(String(coordinate.longitude), forKey: .longitude)
            }

            try container.encode(address.status.rawValue, forKey: .status)
        }
    }
}

// MARK: - Other Types

extension LocalizedAddress {
    public struct FullAddress: Equatable {
        public enum Status: Int, Decodable {
            case deleted = 0
            case active = 1
            case `default` = 2
            case occ = 3
        }

        public typealias ID = Int

        public var id: ID
        public var name: String
        public var receiverName: String

        public var phoneNumber: String?

        public var address: String?
        public var postalCode: String
        public var districtId: DistrictID
        public var districtName: String
        public var cityId: CityID
        public var cityName: String
        public let status: Status
        public var coordinate: CLLocationCoordinate2D?

        /// both warehouse id and shop id are new attribute to support TokoNow.
        /// only be used on TokoNow
        public var tokoNow: TokoNow

        public var isPrimary: Bool {
            status == .default
        }

        public init(
            id: ID,
            name: String,
            receiverName: String,
            phoneNumber: String?,
            address: String?,
            postalCode: String,
            districtId: DistrictID,
            districtName: String,
            cityId: CityID,
            cityName: String,
            status: Status,
            coordinate: CLLocationCoordinate2D?,
            tokoNow: TokoNow = .empty
        ) {
            self.id = id
            self.name = name
            self.receiverName = receiverName
            self.phoneNumber = phoneNumber
            self.address = address
            self.postalCode = postalCode
            self.districtId = districtId
            self.districtName = districtName
            self.cityId = cityId
            self.cityName = cityName
            self.status = status
            self.coordinate = coordinate
            self.tokoNow = tokoNow
        }
    }

    public struct DistrictAddress: Equatable {
        public var districtId: DistrictID
        public var districtName: String
        public var cityId: CityID
        public var cityName: String
        public var postalCode: String?
        public var coordinate: CLLocationCoordinate2D?

        /// both warehouse id and shop id are new attribute to support TokoNow.
        /// only be used on TokoNow
        public var tokoNow: TokoNow

        public init(
            districtId: DistrictID,
            districtName: String,
            cityId: CityID,
            cityName: String,
            postalCode: String?,
            coordinate: CLLocationCoordinate2D?,
            tokoNow: TokoNow = .empty
        ) {
            self.districtId = districtId
            self.districtName = districtName
            self.cityId = cityId
            self.cityName = cityName
            self.postalCode = postalCode
            self.coordinate = coordinate
            self.tokoNow = tokoNow
        }
    }

    public struct TokoNow: Codable {
        public enum ServiceType: String, Codable {
            case now15m = "15m"
            case now2h = "2h"
            case fc // Fullfilment Center
        }

        public struct WarehouseData: Equatable, Codable {
            public let serviceType: ServiceType?
            public let warehouseId: WarehouseID

            private enum CodingKeys: String, CodingKey {
                // LCA TokoNow Keys
                case serviceType = "service_type"
                case warehouseId = "warehouse_id"

                // TokoNowRefresh Keys
                case serviceTypeTokoRefresh = "serviceType"
                case warehouseIDTokoRefresh = "warehouseID"
            }

            public init(serviceType: ServiceType, warehouseId: WarehouseID) {
                self.serviceType = serviceType
                self.warehouseId = warehouseId
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                serviceType = .none

                // because warehouseID from keroAddrSetStateChosenAddress (Int) and TokonowRefreshUserLCAData (String) has different type
                // we will handle it differently
                if let lcaWarehouseID = try? container.decodeIfPresent(WarehouseID.self, forKey: .warehouseId) {
                    warehouseId = lcaWarehouseID
                } else if let rawTokoNowWarehouseID = try? container.decodeIfPresent(String.self, forKey: .warehouseIDTokoRefresh) {
                    warehouseId = rawTokoNowWarehouseID
                } else {
                    warehouseId = "0"
                }
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)

                try container.encode(serviceType, forKey: .serviceType)
                try container.encode(warehouseId, forKey: .warehouseId)
            }
        }

        public let warehouseId: WarehouseID

        public var warehouseIDs: [String] {
            warehouses.map { String($0.warehouseId) }.filter { $0 != "0" }
        }

        /// `lastUpdate` property is introduced as an improvement to the previous tokonow feature.
        /// It is used as a request parameter inside `TokonowRefreshUserLCAData` GQL.
        /// Calling this GQL, app can then fetch latest tokoNow data everytime it being launched from cold start state,
        /// thus enabling users to get the latest and nearest available tokoNow locations around them.
        public var lastUpdate: String
        public let shopId: ShopID
        public let warehouses: [WarehouseData]
        public var serviceType: ServiceType?

        /// isModified property used by `Cart` and `OCC` feature.
        /// It is returned by both `cart_revamp_v3` and `get_occ_multi` GQL.
        /// Besides `Cart` and `OCC` feature, isModified property isn't being used, thus automatically set to false.
        // `cart_revamp_v3` -> data.localization_choose_address.tokonow.is_modfied
        // `get_occ_multi` -> data.profile.address.tokonow.is_modified
        public let isModified: Bool

        public enum CodingKeys: String, CodingKey {
            // LCA TokoNow Keys
            case lastUpdate = "tokonow_last_update"
            case shopId = "shop_id"
            case warehouseId = "warehouse_id"
            case warehouses
            case serviceType = "service_type"
            case isModified = "is_modified"

            // TokoNowRefresh Keys
            case lastUpdateTokoRefresh = "tokonowLastUpdate"
            case shopIDTokoRefresh = "shopID"
            case serviceTypeTokoRefresh = "serviceType"
            case warehouseIDTokoRefresh = "warehouseID"
        }

        /// helper to init TokoNow value empty
        public static var empty: Self {
            .init(lastUpdate: "", shopId: "0", warehouses: [], serviceType: nil)
        }

        public init(
            lastUpdate: String = "",
            shopId: ShopID,
            warehouseId: WarehouseID = "0",
            warehouses: [WarehouseData],
            serviceType: ServiceType?,
            isModified: Bool = false
        ) {
            self.lastUpdate = lastUpdate
            self.shopId = shopId
            self.warehouseId = warehouseId
            self.warehouses = warehouses
            self.serviceType = serviceType
            self.isModified = isModified
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // use `decodeIfPresent` to handle previous version
            lastUpdate = ""

            // use `decodeIfPresent` to handle multiple keys.
            // also, shopID from keroAddrSetStateChosenAddress (Int) and TokonowRefreshUserLCAData (String) has different type
            // we will handle it differently
            if let lcaShopID = try? container.decodeIfPresent(ShopID.self, forKey: .shopId) {
                shopId = lcaShopID
            } else if let rawTokoNowShopID = try? container.decodeIfPresent(String.self, forKey: .shopIDTokoRefresh) {
                let tokoNowShopID = rawTokoNowShopID
                shopId = tokoNowShopID
            } else {
                shopId = "0"
            }

            // use `decodeIfPresent` to handle previous version
            serviceType = .none

            // use `decodeIfPresent` to handle previous version
            warehouses = (try container.decodeIfPresent([WarehouseData].self, forKey: .warehouses)) ?? []

            // use `decodeIfPresent` to handle multiple keys.
            // also, warehouseID from keroAddrSetStateChosenAddress (Int) and TokonowRefreshUserLCAData (Stritong) has different type
            // we will handle it differently
            if let lcaWarehouseID = try? container.decodeIfPresent(WarehouseID.self, forKey: .warehouseId) {
                warehouseId = lcaWarehouseID
            } else if let rawTokoNowWarehouseID = try? container.decodeIfPresent(String.self, forKey: .warehouseIDTokoRefresh) {
                let tokoNowWarehouseID = rawTokoNowWarehouseID
                warehouseId = tokoNowWarehouseID
            } else if let activeService = serviceType, let activeWarehouse = warehouses.first(where: { $0.serviceType == activeService }) {
                warehouseId = activeWarehouse.warehouseId
            } else {
                warehouseId = "0"
            }

            // use `decodeIfPresent` to handle previous version
            isModified = (try container.decodeIfPresent(Bool.self, forKey: .isModified)) ?? false
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(lastUpdate, forKey: .lastUpdate)
            try container.encode(shopId, forKey: .shopId)
            try container.encode(warehouseId, forKey: .warehouseId)
            try container.encode(serviceType, forKey: .serviceType)
            try container.encode(warehouses, forKey: .warehouses)
        }

        public func toDictionary() -> [String: Any] {
            return [
                "tokonow_last_update": lastUpdate,
                "shop_id": shopId,
                "warehouses": warehouses.map { ["warehouse_id": $0.warehouseId, "service_type": $0.serviceType] },
                "service_type": serviceType ?? "",
                "warehouse_ids": warehouses.map { $0.warehouseId }
            ]
        }

        public func toJSONValue() -> [String: JSONValue] {
            let warehousesArray = warehouses.map { warehouse -> JSONValue in
                var dict = [String: JSONValue]()
                dict["warehouse_id"] = .string(warehouse.warehouseId)
                dict["service_type"] = .string("")

                return JSONValue.object(dict)
            }

            var dict = [String: JSONValue]()
            dict["tokonow_last_update"] = .string(lastUpdate)
//            dict["shop_id"] = .int(shopId)
            dict["warehouses"] = .array(warehousesArray)
            dict["service_type"] = .string("")
//            dict["warehouse_ids"] = .array(warehouses.map { .int($0.warehouseId) })

            return dict
        }
    }
}

extension LocalizedAddress.TokoNow: Equatable {
    /// Exclude `lastUpdate` property from being used in the Equatable conformance because BE may return different `lastUpdate` value on each API call.
    /// However, this is not a pretty good fix. To update TokoNow's Equatable conformity, this fix forces other devs to add their new properties to == func each time they add new properties to the `TokoNow` struct .
    /// Definitely will update this fix to a better one by separating `lastUpdate` and `TokoNow` struct into a separate keychain.
    public static func == (lhs: LocalizedAddress.TokoNow, rhs: LocalizedAddress.TokoNow) -> Bool {
        return
            lhs.shopId == rhs.shopId &&
            lhs.warehouses == rhs.warehouses &&
            lhs.serviceType == rhs.serviceType &&
            lhs.warehouseId == rhs.warehouseId
    }
}
extension CLLocationCoordinate2D: Equatable {}

public func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
}
