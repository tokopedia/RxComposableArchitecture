//
//  ShipmentResponse.swift
//  Examples
//
//  Created by jefferson.setiawan on 21/03/24.
//

import Foundation
import RxComposableArchitecture

public typealias AddOnID = String
internal struct ShipmentAddressFormResponse {
    internal var keroToken: String
    internal var keroUnixTime: String
    internal var showOnboarding: Bool
    internal var disabledFeatures: Set<DisabledFeature>
    internal var cod: ShipmentAddressFormCODResponse
    internal var tickers: [ShipmentAddressFormTickerResponse]
    internal var address: ShipmentAddressFormAddressResponse?
    /**
     When on trade in mode, user can select send / drop off address,
     this `addresses`, will contain it, normal flow will use address.
     */
    internal var addresses: [ShipmentAddressFormAddressesDataResponse]
    internal var disabledTabs: [ShipmentAddressFormAddressesDataKey]
    internal var active: ShipmentAddressFormAddressesDataKey?
    internal var order: [ShipmentAddressFormOrderResponse]
    internal var donation: ShipmentAddressFormDonationResponse?
    internal var egold: ShipmentAddressFormEGoldResponse?
    internal var promo: ShipmentAddressFormPromoData
    internal var campaignTimer: ShipmentAddressFormCampaignResponse
    internal var toaster: String
    internal var errorCode: ErrorCode
    internal var errorTicker: String
    internal var popUp: PopUp
    internal var addOnWording: AddOnWording
    internal var epharmacyImageUpload: EpharmacyImageUploadResponse?
    internal var gotoPlusWidgetDataV2: GotoPlusWidgetDataV2?
    internal var plusCoachmarkData: PlusCoachmarkData?
    /// cartData is JSON string used to hit rates
    internal var cartData: String
    internal var dynamicDataPassing: DynamicDataPassing
    /**
     Data for platform fee per basket size. Most of the data is used
     as parameter to hit `getPaymentFeeCheckout` API.
     */
    internal var platformFeeData: ShipmentAddressFormPlatformFeeData?
    /**
     Data for `add-ons as a service`
     */
    internal var addOnServiceSummary: [ShipmentAddressFormAddonServiceSummary]
}

internal enum DisabledFeature: String, Decodable, Equatable {
    case purchaseProtection = "ppp"
    case egold
    case donation
    case dropshipper
    case none

    internal init(from decoder: Decoder) throws {
        let featureString = try decoder.singleValueContainer().decode(String.self)
        self = DisabledFeature(rawValue: featureString) ?? .none
    }
}

/**
 Error code:
 0 → Should update local address
 3 → Should open Add New Address page
 4 → Should open Address List page
 */
internal enum ErrorCode: Int, Decodable {
    case updateLocalAddress = 0
    case openAddNewAddress = 3
    case openAddressList = 4
}

extension ShipmentAddressFormResponse: Decodable, Equatable {
    internal enum JSONKeys: String, CodingKey {
        case keroToken = "kero_token"
        case keroUnixTime = "kero_unix_time"
        case showOnboarding = "is_show_onboarding"
        case disabledFeatures = "disabled_features"
        case cod
        case tickers
        case groupAddress = "group_address"
        case donation
        case donationCheckboxStatus = "donation_checkbox_status"
        case egold = "egold_attributes"
        case promo
        case campaignTimer = "campaign_timer"
        case addresses
        case toaster = "pop_up_message"
        case errorCode = "error_code"
        case errorTicker = "error_ticker"
        case popUp = "pop_up"
        case addOnWording = "add_on_wording"
        case imageUpload = "image_upload"
        case gotoPlusWidgetDataV2 = "upsell_v2"
        case cartData = "cart_data"
        case coachmark
        case dynamicDataPassing = "dynamic_data_passing"
        case platformFeeData = "platform_fee"
        case addOnServiceSummary = "add_ons_summary"
    }

    internal enum PlusCoachmark: String, CodingKey {
        case plus = "Plus"
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONKeys.self)

        keroToken = try container.decode(String.self, forKey: .keroToken)
        keroUnixTime = String(try container.decode(Int.self, forKey: .keroUnixTime))
        showOnboarding = try container.decode(Bool.self, forKey: .showOnboarding)
        disabledFeatures = try container.decode(Set<DisabledFeature>.self, forKey: .disabledFeatures)

        cod = try container.decode(ShipmentAddressFormCODResponse.self, forKey: .cod)

        tickers = try container
            .decode([ShipmentAddressFormTickerResponse].self, forKey: .tickers)

        let groupAddress = try container.decode([ShipmentAddressFormGroupResponse].self, forKey: .groupAddress)

        // extract address value
        address = groupAddress.first?.address

        let addressesContainer = try container.decode(ShipmentAddressFormAddressesResponse.self, forKey: .addresses)
        addresses = addressesContainer.data.map { datum -> ShipmentAddressFormAddressesDataResponse in
            let disabled = addressesContainer.disableTabs.contains(datum.key)

            return ShipmentAddressFormAddressesDataResponse(key: datum.key, value: datum.value, disabled: disabled)
        }

        disabledTabs = addressesContainer.disableTabs

        if let activeAddress = addressesContainer.active {
            active = ShipmentAddressFormAddressesDataKey(rawValue: activeAddress)
        } else {
            active = nil
        }

        // extract order from group address
        order = groupAddress.first?.order ?? []

        // set value donation only if title and description have its value, if not, set it as nil
        let donation = try container.decode(ShipmentAddressFormDonationResponse.self, forKey: .donation)
        self.donation = nil

        let donationStatusCheckbox = try container.decode(Bool.self, forKey: .donationCheckboxStatus)
        self.donation?.isSelected = donationStatusCheckbox

        egold = try container.decode(ShipmentAddressFormEGoldResponse.self, forKey: .egold)

        // extract promo
        let promo = try container.decode(ShipmentAddressFormPromo.self, forKey: .promo)
        self.promo = promo.lastApply.data

        campaignTimer = try container.decode(ShipmentAddressFormCampaignResponse.self, forKey: .campaignTimer)
        toaster = try container.decode(String.self, forKey: .toaster)

        let decodedErrorCode = try? container.decode(ErrorCode.self, forKey: .errorCode)
        errorCode = decodedErrorCode ?? .updateLocalAddress

        errorTicker = try container.decode(String.self, forKey: .errorTicker)
        popUp = try container.decode(PopUp.self, forKey: .popUp)
        addOnWording = try container.decode(AddOnWording.self, forKey: .addOnWording)
        cartData = try container.decode(String.self, forKey: .cartData)

        let _imageUpload = try container.decode(EpharmacyImageUploadResponse.self, forKey: .imageUpload)
        if _imageUpload.isShowImage,
            _imageUpload.checkoutID != nil {
            epharmacyImageUpload = _imageUpload
        } else {
            epharmacyImageUpload = nil
        }

        let gotoPlusWidgetV2Value = try container.decode(GotoPlusWidgetDataV2.self, forKey: .gotoPlusWidgetDataV2)
        gotoPlusWidgetDataV2 = gotoPlusWidgetV2Value.isShow ? gotoPlusWidgetV2Value : nil

        let coachmarkContainer = try container.nestedContainer(keyedBy: PlusCoachmark.self, forKey: .coachmark)
        let _plusCoachmarkData = try coachmarkContainer.decode(PlusCoachmarkData.self, forKey: .plus)

        if _plusCoachmarkData.isShown, _plusCoachmarkData.content != nil {
            plusCoachmarkData = _plusCoachmarkData
        } else {
            plusCoachmarkData = nil
        }

        dynamicDataPassing = try container.decode(DynamicDataPassing.self, forKey: .dynamicDataPassing)
        let _platformFeeData = try container.decode(ShipmentAddressFormPlatformFeeData.self, forKey: .platformFeeData)
        platformFeeData = _platformFeeData.isEnabled ? _platformFeeData : nil

        addOnServiceSummary = try container.decode([ShipmentAddressFormAddonServiceSummary].self, forKey: .addOnServiceSummary)
    }

    private struct ShipmentAddressFormGroupResponse: Decodable, Equatable {
        internal let address: ShipmentAddressFormAddressResponse
        internal let order: [ShipmentAddressFormOrderResponse]

        internal enum CodingKeys: String, CodingKey {
            case address = "user_address"
            case order = "group_shop"
        }
    }
}

internal struct ShipmentAddressFormPlatformFeeData: Equatable {
    /**
     If true, means there is platform fee.
     If false, means there is not platform fee & we don't need to do the platform fee actions.
     */
    internal let isEnabled: Bool

    /**
     Request params when hit `getPaymentFeeCheckout` API.
     */
    internal let profileCode: String
    internal let additionalData: String

    /**
     `errorMessage` will be displayed inside a ticker if we failed to hit `getPaymentFeeCheckout` API.
     */
    internal var errorMessage: String?
}

extension ShipmentAddressFormPlatformFeeData: Decodable {
    internal enum CodingKeys: String, CodingKey {
        case isEnabled = "enable"
        case profileCode = "profile_code"
        case additionalData = "additional_data"
        case errorMessage = "error_wording"
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        profileCode = try container.decode(String.self, forKey: .profileCode)
        additionalData = try container.decode(String.self, forKey: .additionalData)
        errorMessage = try container.decode(String.self, forKey: .errorMessage)
    }
}

internal struct ShipmentAddressFormAddonServiceSummary: Equatable {
    internal let title: String
    internal let type: Int
}

extension ShipmentAddressFormAddonServiceSummary: Decodable {
    internal enum CodingKeys: String, CodingKey {
        case title = "wording"
        case type
    }
}

internal struct PlusCoachmarkData: Decodable, Equatable {
    internal let isShown: Bool
    internal let title: String
    internal var content: String?

    internal enum CodingKeys: String, CodingKey {
        case isShown = "is_shown"
        case title
        case content
    }
}

internal struct ShipmentAddressFormTickerResponse: Decodable, Equatable {
    internal let id: Int
    internal let message: String
}

internal struct ShipmentAddressFormCODResponse: Decodable, Equatable {
    internal let isCod: Bool
    internal let counter: Int

    internal enum CodingKeys: String, CodingKey {
        case isCod = "is_cod"
        case counter = "counter_cod"
    }
}

internal struct ShipmentAddressFormAddressesResponse: Decodable, Equatable {
    internal var active: String?
    internal let disableTabs: [ShipmentAddressFormAddressesDataKey]
    internal let data: [ShipmentAddressFormAddressesDataResponse]

    internal enum CodingKeys: String, CodingKey {
        case active
        case disableTabs = "disable_tabs"
        case data
    }
}

internal enum ShipmentAddressFormAddressesDataKey: String, Decodable, Equatable {
    case `default` = "default_address"
    case tradeIn = "trade_in_address"
}

internal struct ShipmentAddressFormAddressesDataResponse: Equatable {
    internal let key: ShipmentAddressFormAddressesDataKey
    internal let value: ShipmentAddressFormAddressResponse
    internal var disabled: Bool = false
}

extension ShipmentAddressFormAddressesDataResponse: Decodable {
    internal enum CodingKeys: String, CodingKey {
        case key, value
    }
}

public typealias AddressID = Int

internal struct ShipmentAddressFormAddressResponse: Equatable {
    internal let id: AddressID
    internal let title: String
    internal let receiverName: String
    internal let detail: String
    internal let phoneNumber: String
    internal let postalCode: String
    internal let districtId: Int
    internal let districtName: String
    internal let latitude: String
    internal let longitude: String
    internal let isPrimary: Bool // If true, "status" should equal 2
    internal let provinceId: Int
    internal let cityId: Int
    internal let provinceName: String
    internal let cityName: String
    internal let stateCode: Int
    internal let stateDetail: String
    internal let status: Int // 0: inactive, 1: active, 2: primary
    internal let tokonowAddressData: LocalizedAddress.TokoNow
}

extension ShipmentAddressFormAddressResponse: Decodable {
    internal enum CodingKeys: String, CodingKey {
        case id = "address_id"
        case title = "address_name"
        case detail = "address"
        case phoneNumber = "phone"
        case receiverName = "receiver_name"
        case postalCode = "postal_code"
        case districtId = "district_id"
        case districtName = "district_name"
        case latitude, longitude
        case isPrimary = "is_primary"
        case provinceId = "province_id"
        case cityId = "city_id"
        case provinceName = "province_name"
        case cityName = "city_name"
        case stateCode = "state"
        case stateDetail = "state_detail"
        case status
        case tokonowAddressData = "tokonow"
    }
}

internal struct ShipmentAddressFormDonationResponse: Decodable, Equatable {
    internal let title: String
    internal let description: String
    internal let amount: Price
    internal var isSelected: Bool = false

    internal enum CodingKeys: String, CodingKey {
        case title = "Title"
        case description = "Description"
        case amount = "Nominal"
    }
}

internal struct ShipmentAddressFormEGoldResponse: Decodable, Equatable {
    internal let isEligible: Bool
    internal let isTiering: Bool
    internal let isOptIn: Bool
    internal let tiers: [ShipmentAddressFormEGoldTierResponse]
    internal let range: ShipmentAddressFormEGoldRange
    internal let message: ShipmentAddressFormEGoldMessageResponse
    internal var hyperlinkText: ShipmentAddressFormHyperlinkText
    internal let iconUrl: String

    internal enum CodingKeys: String, CodingKey {
        case isEligible = "eligible"
        case isTiering = "is_tiering"
        case isOptIn = "is_opt_in"
        case tiers = "tier_data"
        case range
        case message
        case hyperlinkText = "hyperlink_text"
        case iconUrl = "icon_url"
    }
}

internal struct ShipmentAddressFormEGoldMessageResponse: Decodable, Equatable {
    internal let title: String
    internal let description: String
    internal var subtitle: String?
    internal let bottomSheetTitle: String

    internal enum CodingKeys: String, CodingKey {
        case title = "title_text"
        case description = "tooltip_text"
        case subtitle = "sub_text"
        case bottomSheetTitle = "tooltip_title_text"
    }
}

internal struct ShipmentAddressFormHyperlinkText: Decodable, Equatable {
    internal let text: String
    internal let url: String
    internal let isShow: Bool

    internal enum CodingKeys: String, CodingKey {
        case text
        case url
        case isShow = "is_show"
    }
}

internal struct ShipmentAddressFormEGoldRange: Decodable, Equatable {
    internal let minimum: Int
    internal let maximum: Int

    internal enum CodingKeys: String, CodingKey {
        case minimum = "min"
        case maximum = "max"
    }
}

internal struct ShipmentAddressFormEGoldTierResponse: Decodable, Equatable {
    internal let basis: Int
    internal let minimum: Int
    internal let maximum: Int
    internal let minimumTotal: Int

    internal enum CodingKeys: String, CodingKey {
        case basis = "basis_amount"
        case minimum = "minimum_amount"
        case maximum = "maximum_amount"
        case minimumTotal = "minimum_total_amount"
    }
}

internal struct ShipmentAddressFormPromo: Decodable, Equatable {
    internal let lastApply: ShipmentAddressFormPromoLastApply

    internal enum CodingKeys: String, CodingKey {
        case lastApply = "last_apply"
    }
}

internal struct ShipmentAddressFormPromoLastApply: Decodable, Equatable {
    internal let data: ShipmentAddressFormPromoData
}

internal struct ShipmentAddressFormPromoData {
    internal let codes: [String]
    internal let discountAmount: Price
    internal let cashbackAmount: Price
    internal let merchantCodes: [ShipmentAddressFormPromoMerchantCode]
    internal var additionalInfo: ShipmentAddressFormPromoAdditionalInfo
    internal var summaryInfo: ShipmentAddressFormBenefitInfoResponse
    internal var trackingDetails: [ShipmentAddressFormTrackingDetailResponse]
    internal let userGroup: PromoWidgetUserGroup
}

extension ShipmentAddressFormPromoData: Decodable, Equatable {
    internal enum CodingKeys: String, CodingKey {
        case codes
        case discountAmount = "discount_amount"
        case cashbackAmount = "cashback_wallet_amount"
        case merchantCodes = "voucher_orders"
        case additionalInfo = "additional_info"
        case summaryInfo = "benefit_summary_info"
        case trackingDetails = "tracking_details"
        case userGroup = "user_group_metadata"
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        codes = try container.decode([String].self, forKey: .codes)
        discountAmount = try container.decode(Price.self, forKey: .discountAmount)
        cashbackAmount = try container.decode(Price.self, forKey: .cashbackAmount)
        merchantCodes = try container.decode([ShipmentAddressFormPromoMerchantCode].self, forKey: .merchantCodes)
        additionalInfo = try container.decode(ShipmentAddressFormPromoAdditionalInfo.self, forKey: .additionalInfo)
        summaryInfo = try container.decode(ShipmentAddressFormBenefitInfoResponse.self, forKey: .summaryInfo)
        trackingDetails = try container.decode([ShipmentAddressFormTrackingDetailResponse].self, forKey: .trackingDetails)

        let decodedUserGroup = try container.decode([ShipmentAddressFormUserGroupMetadata].self, forKey: .userGroup)
        let userGroupString = decodedUserGroup.first(where: { $0.key == "promo_revamp_ab_test_user_group" })?.value ?? ""
        userGroup = PromoWidgetUserGroup(rawValue: userGroupString) ?? .groupC
    }
}

internal struct ShipmentAddressFormUserGroupMetadata: Decodable, Equatable {
    internal let key: String
    internal let value: String

    internal enum CodingKeys: String, CodingKey {
        case key
        case value
    }
}

internal struct ShipmentAddressFormPromoMerchantCode: Decodable, Equatable {
    internal let cartShopUniqueIndentifier: CartShopID
    internal let code: String
    internal let type: ShipmentAddressFormPromoMerchantCodeType
}

extension ShipmentAddressFormPromoMerchantCode {
    internal enum CodingKeys: String, CodingKey {
        case cartShopUniqueIndentifier = "unique_id"
        case code, type
    }
}

internal enum ShipmentAddressFormPromoMerchantCodeType: String, Decodable {
    case merchant
    case logistic
    case none

    internal init(from decoder: Decoder) throws {
        let typeString = try decoder.singleValueContainer().decode(String.self)
        self = ShipmentAddressFormPromoMerchantCodeType(rawValue: typeString) ?? .none
    }
}

internal struct ShipmentAddressFormBenefitInfoResponse: Decodable, Equatable {
    internal let benefitAmount: Int
    internal let summaries: [ShipmentAddressFormPromoSummaryResponse]

    internal enum CodingKeys: String, CodingKey {
        case benefitAmount = "final_benefit_amount"
        case summaries
    }
}

internal struct ShipmentAddressFormTrackingDetailResponse: Decodable, Equatable {
    internal let productId: ShipmentProductID
    internal let promoCode: String
    internal let detailTracking: String

    internal enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case promoCode = "promo_codes_tracking"
        case detailTracking = "promo_details_tracking"
    }
}

internal struct ShipmentAddressFormPromoSummaryResponse: Decodable, Equatable {
    internal var type: ShipmentAddressFormPromoSummaryTypeResponse?
    internal let amount: Price
    internal let details: [ShipmentAddressFormPromoSummaryDetailResponse]
}

internal enum ShipmentAddressFormPromoSummaryTypeResponse: String, Decodable {
    case discount
    case cashback
}

internal struct ShipmentAddressFormPromoSummaryDetailResponse: Decodable, Equatable {
    internal var type: ShipmentAddressFormPromoSummaryDetailTypeResponse?
    internal let amount: Price
}

internal enum ShipmentAddressFormPromoSummaryDetailTypeResponse: String, Decodable {
    case shippingDiscount = "shipping_discount"
    case productDiscount = "product_discount"
}

internal struct ShipmentAddressFormShopShipmentProductResponse: Decodable, Equatable {
    internal let id: ShipmentProductID
    internal let additionalFee: Price

    internal enum CodingKeys: String, CodingKey {
        case id = "ship_prod_id"
        case additionalFee = "additional_fee"
    }
}

internal struct ShipmentAddressFormShopTypeInfo: Decodable, Equatable {
    internal let shopTier: Int

    internal var badgeURL: URL?

    internal enum CodingKeys: String, CodingKey {
        case shopTier = "shop_tier"
        case badgeURL = "badge"
    }
}

internal struct ShipmentAddressFormProductShipmentMapping: Decodable, Equatable {
    internal let serviceIds: [ShipmentAddressFormProductShipmentMappingServiceIds]

    internal enum CodingKeys: String, CodingKey {
        case serviceIds = "service_ids"
    }
}

internal struct ShipmentAddressFormProductShipmentMappingServiceIds {
    internal let productIds: [ShipmentProductID]
}

extension ShipmentAddressFormProductShipmentMappingServiceIds: Decodable, Equatable {
    internal enum CodingKeys: String, CodingKey {
        case productIds = "sp_ids"
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawString = try container.decode(String.self, forKey: .productIds)
        let productIdsInString = rawString.split(separator: ",")
        productIds = try productIdsInString.map { idInString -> ShipmentProductID in
            guard let integer = Int(idInString) else {
                throw DecodingError.dataCorruptedError(forKey: .productIds, in: container, debugDescription: "string is not convertible to integer")
            }

            return integer
        }
    }
}

internal struct ShipmentAddressFormProductTradeInInfo: Decodable, Equatable {
    internal var oldDevicePrice: Price
    internal var newDevicePrice: Price
    internal var deviceModel: String
    internal var diagnosticId: Int

    internal enum CodingKeys: String, CodingKey {
        case oldDevicePrice = "old_device_price"
        case newDevicePrice = "new_device_price"
        case deviceModel = "device_model"
        case diagnosticId = "diagnostic_id"
    }
}

internal struct ShipmentAddressFormProductTrackerData: Decodable, Equatable {
    internal let attribution: String
    internal let listName: String

    internal enum CodingKeys: String, CodingKey {
        case attribution
        case listName = "tracker_list_name"
    }
}

internal struct ShipmentAddressFormProductPreorderResponse: Decodable, Equatable {
    internal let durationDay: String

    internal enum CodingKeys: String, CodingKey {
        case durationDay = "duration_day"
    }

    internal init(durationDay: String = "0") {
        self.durationDay = durationDay
    }
}

internal struct FreeShippingData: Decodable, Equatable {
    public let boName: String
    public let boType: BOType
    public let badgeUrl: String
    public var shouldViewGotoPlusLogo: Bool {
        return boType == .bebasOngkirPlus || boType == .bebasOngkirPlusFulfillment
    }

    public enum CodingKeys: String, CodingKey {
        case boName = "bo_name"
        case boType = "bo_type"
        case badgeUrl = "badge_url"
    }
}

internal struct ShipmentAddressFormProductPurchaseProtectionResponse: Decodable, Equatable {
    internal let isAvailable: Bool
    /// protection price total
    internal let protectionPrice: Price
    internal let title: String
    internal let subtitle: String
    internal let protectionPricePerProduct: Price

    internal var learnMoreURL: URL?
    internal var isSelected: Bool
    internal var isDisabled: Bool

    internal enum CodingKeys: String, CodingKey {
        case isAvailable = "protection_available"
        case protectionPrice = "protection_price"
        case title = "protection_title"
        case subtitle = "protection_subtitle"
        case protectionPricePerProduct = "protection_price_per_product"
        case learnMoreURL = "protection_link_url"
        case isSelected = "protection_opt_in"
        case isDisabled = "protection_checkbox_disabled"
    }

    internal init() {
        isAvailable = false
        protectionPrice = 0
        title = ""
        subtitle = ""
        protectionPricePerProduct = 0
        isSelected = false
        isDisabled = true
    }

    internal init(isAvailable: Bool, protectionPrice: Price, title: String, subtitle: String, protectionPricePerProduct: Price, learnMoreURL: URL?, isSelected: Bool, isDisabled: Bool) {
        self.isAvailable = isAvailable
        self.protectionPrice = protectionPrice
        self.title = title
        self.subtitle = subtitle
        self.protectionPricePerProduct = protectionPricePerProduct
        self.learnMoreURL = learnMoreURL
        self.isSelected = isSelected
        self.isDisabled = isDisabled
    }
}

/**
 Example Response
 ```json
 "campaign_timer": {
     "show_timer": true,
     "description": "Selesaikan pembayaran dalam",
     "expired_timer_message": {
     "title": "Waktu Pembayaran Habis",
     "description": "Transaksi dibatalkan karena kamu tidak melakukan pembayaran hingga batas waktu yang berakhir.",
     "Button": "Belanja Lagi"
    },
     "timer_detail": {
         "expired_time": "2020-08-13T13:05:00Z07:00",
         "deduct_time": "2020-08-13T10:00:00Z07:00",
         "server_time": "2020-08-13T10:50:00Z07:00"
    }
 }

 ```
 */
internal struct ShipmentAddressFormCampaignResponse: Decodable, Equatable {
    internal let showTimer: Bool
    internal let title: String
    internal let time: ShipmentAddressFormCampaignTimerResponse
    internal let expiredInfo: ShipmentAddressFormExpiredInfoResponse

    internal enum CodingKeys: String, CodingKey {
        case showTimer = "show_timer"
        case title = "description"
        case time = "timer_detail"
        case expiredInfo = "expired_timer_message"
    }
}

internal struct ShipmentAddressFormCampaignTimerResponse: Decodable, Equatable {
    internal var expiredTime: Date?

    internal var deductTime: Date?

    internal var serverTime: Date?

    internal enum CodingKeys: String, CodingKey {
        case expiredTime = "expired_time"
        case deductTime = "deduct_time"
        case serverTime = "server_time"
    }
}

internal struct Ticker: Equatable {

    internal var id: Int
    internal var content: TickerContent
}

public enum TickerNodeType: String, Equatable {
    case announcement
    case warning
    case error
    /// .tips won't show buttonCloseNode
    case tips
    @available(*, deprecated, message: "will be replace with .tips")
    case additional
}

public struct TickerContent: Equatable {
    public let type: TickerNodeType
    public let htmlContent: NSAttributedString?
    public let title: String?

    public init(type: TickerNodeType, htmlContent: NSAttributedString?, title: String?) {
        self.type = type
        self.htmlContent = htmlContent
        self.title = title
    }
}


internal struct GotoPlusWidgetDataV2: Equatable {
    internal let isShow: Bool
    internal let isSelected: Bool
    internal let price: Int
    internal let priceFmt: String
    internal let duration: String
    internal let description: String
    internal let summaryWording: String
    internal let imageUrl: String
    internal let applink: String
    internal let buttonText: String

    // Param for checkout
    internal let id: Int
    internal let additionalVerticalId: Int
    internal let transactionType: String
}

extension GotoPlusWidgetDataV2: Decodable {
    internal enum CodingKeys: String, CodingKey {
        case isShow = "is_show"
        case isSelected = "is_selected"
        case price
        case priceFmt = "price_fmt"
        case duration
        case description
        case summaryWording = "summary_info"
        case imageUrl = "image"
        case applink = "app_link"
        case button
        case id
        case additionalVerticalId = "additional_vertical_id"
        case transactionType = "transaction_type"
    }

    internal enum PlusWidgetButtonKeys: String, CodingKey {
        case text
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        isShow = try container.decode(Bool.self, forKey: .isShow)
        isSelected = try container.decode(Bool.self, forKey: .isSelected)
        price = try container.decode(Int.self, forKey: .price)
        priceFmt = try container.decode(String.self, forKey: .priceFmt)
        duration = try container.decode(String.self, forKey: .duration)
        description = try container.decode(String.self, forKey: .description)
        summaryWording = try container.decode(String.self, forKey: .summaryWording)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        applink = try container.decode(String.self, forKey: .applink)

        let buttonContainer = try container.nestedContainer(keyedBy: PlusWidgetButtonKeys.self, forKey: .button)
        buttonText = try buttonContainer.decode(String.self, forKey: .text)

        id = try container.decode(Int.self, forKey: .id)
        additionalVerticalId = try container.decode(Int.self, forKey: .additionalVerticalId)
        transactionType = try container.decode(String.self, forKey: .transactionType)
    }
}

internal struct DynamicDataPassing: Equatable {
    internal let isDdp: Bool
    internal let dynamicData: String
}

extension DynamicDataPassing: Decodable {
    internal enum CodingKeys: String, CodingKey {
        case isDdp = "is_ddp"
        case dynamicData = "dynamic_data"
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        isDdp = try container.decode(Bool.self, forKey: .isDdp)
        dynamicData = try container.decode(String.self, forKey: .dynamicData)
    }
}

internal struct ShipmentAddressFormOrderResponse {
    /// also known as spId
    internal var shipperProductId: ShipmentProductID
    /// also known as shipping_id
    internal var shipperId: ShipmentID

    /// if shop group contains boCode when opening SAF, we will hit rates and validate to try applying BO shipment
    internal var boCode: String
    internal let isInsurance: Bool
    internal let isOrderPriority: Bool
    internal var cartUniqueIdentifier: CartOrderID
    internal let shopShipmentInformation: ShipmentAddressFormOrderShipmentInformationResponse
    internal let shopShipments: [ShipmentAddressFormShopShipmentResponse]
    internal let isFullfillmentService: Bool
    internal let warehouse: ShipmentAddressFormWarehouseResponse

    internal var dropshipper: ShipmentAddressFormDropshipperResponse?
    internal var errors: [String]
    internal let tokoCabang: TokoCabang?
    internal let isDisableChangeCourier: Bool
    internal let autoCourierSelection: Bool
    internal let courierSelectionError: ShipmentAddressFormOrderCourierError
    internal let BOMetadata: ShipmentAddressFormOrderBOMetadata
    internal let errorsUnblocking: [String]
    internal var addOns: AddOn
    internal var scheduledDelivery: ShipmentAddressFormScheduledDelivery

    internal let groupType: GroupType
    internal let uiGroupType: UIGroupType
    internal let groupMetadata: String
    internal let groupInformation: ShipmentAddressFormOrderGroupInfo
    internal var shopGroup: [ShipmentAddressFormShopGroupResponse]

    /// Summary in subtotal for `add-ons as a service`. Use same struct with `ShipmentAddressFormResponse.addOnServiceSummary` because both have same structure
    internal var addOnServiceSubtotalSummary: [ShipmentAddressFormAddonServiceSummary]

    /// OFOC
    /// Current grouping state; merged or split
    internal var groupingState: GroupingState
    /**
     ShippingComponent will be used to determine which shipping component to show on each order.
     Currently there are 3 values from BE:
     - standardAndScheduled = 1 // schelly and conventional
     - scheduled = 2 // schelly only
     - standard = 3 // conventional only
     */
    internal var shippingComponent: ShippingComponent
    /**
     Shipment action will be used to determine which action to do after user change to specific shipping
     */
    internal var shipmentAction: [ShipmentAction]
}

extension ShipmentAddressFormOrderResponse: Decodable, Equatable {
    internal enum CodingKeys: String, CodingKey {
        case isInsurance = "is_insurance"
        case isOrderPriority = "is_order_priority"
        case shipperProductId = "sp_id"
        case shipperId = "shipping_id"
        case boCode = "bo_code"
        case cartUniqueIdentifier = "cart_string"
        case shopShipmentInformation = "shipment_information"
        case warehouse, dropshipper
        case shopShipments = "shop_shipments"
        case isFullfillmentService = "is_fulfillment_service"
        case errors
        case tokoCabang = "toko_cabang"
        case isDisableChangeCourier = "is_disable_change_courier"
        case autoCourierSelection = "auto_courier_selection"
        case courierSelectionError = "courier_selection_error"
        case BOMetadata = "bo_metadata"
        case errorsUnblocking = "errors_unblocking"
        case addOns = "add_ons"
        case scheduledDelivery = "scheduled_delivery"

        case groupType = "group_type"
        case uiGroupType = "ui_group_type"
        case groupMetadata = "group_metadata"
        case groupInformation = "group_information"
        case shopGroup = "group_shop_v2_saf"
        case addOnServiceSubtotalSummary = "subtotal_add_ons"
        case shipmentAction = "shipment_action"
        case groupingState = "grouping_state"
        case shippingComponent = "shipping_components"
    }
}

internal enum ShippingComponent: Int, Decodable {
    case standardAndScheduled = 1
    case scheduled = 2
    case standard = 3

    internal var hasScheduled: Bool {
        return self == .standardAndScheduled || self == .scheduled
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let typeInt = try container.decode(Int.self)

        switch typeInt {
        case 1: self = .standardAndScheduled
        case 2: self = .scheduled
        case 3: self = .standard
        default: self = .standard
        }
    }
}

internal struct ShipmentAddressFormShopGroupResponse {
    internal var cartStringShop: CartShopID
    internal var cartDetails: [SAFCartDetails]

    // Shop Data
    internal let id: ShipmentShopID
    internal let name: String
    internal let postalCode: String
    internal let districtId: Int
    internal let latitude: String
    internal let longitude: String
    internal let campaignLabel: String
    internal let isOfficialStore: Bool
    internal let isGoldBadge: Bool
    internal let shopTypeInfo: ShipmentAddressFormShopTypeInfo
    internal let isTokonow: Bool
    internal let shopTicker: ShopTicker?

    internal var epharmacyPartnerName: String?
}

extension ShipmentAddressFormShopGroupResponse: Decodable, Equatable {
    internal enum CodingKeys: String, CodingKey {
        case cartStringShop = "cart_string_order"
        case shop
        case cartDetails = "cart_details"
    }

    internal enum ShopCodingKeys: String, CodingKey {
        case id = "shop_id"
        case name = "shop_name"
        case postalCode = "postal_code"
        case districtId = "district_id"
        case latitude, longitude
        case campaignLabel = "shop_alert_message"
        case isOfficialStore = "is_official"
        case isGoldBadge = "is_gold"
        case shopTypeInfo = "shop_type_info"
        case isTokonow = "is_tokonow"
        case shopTickerDesc = "shop_ticker" // ==> desc
        case shopTickerTitle = "shop_ticker_title" // ==> title
        case epharmacyPartnerData = "enabler_data"
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        cartStringShop = try container.decode(CartShopID.self, forKey: .cartStringShop)
        cartDetails = try container.decode([SAFCartDetails].self, forKey: .cartDetails)

        let shopContainer = try container.nestedContainer(keyedBy: ShopCodingKeys.self, forKey: .shop)
        id = try shopContainer.decode(ShipmentShopID.self, forKey: .id)
        name = try shopContainer.decode(String.self, forKey: .name)
        postalCode = try shopContainer.decode(String.self, forKey: .postalCode)
        districtId = try shopContainer.decode(Int.self, forKey: .districtId)
        latitude = try shopContainer.decode(String.self, forKey: .latitude)
        longitude = try shopContainer.decode(String.self, forKey: .longitude)
        campaignLabel = try shopContainer.decode(String.self, forKey: .campaignLabel)

        let isOfficialStoreInt = try shopContainer.decode(Int.self, forKey: .isOfficialStore)
        isOfficialStore = isOfficialStoreInt == 1

        let isGoldBadgeInt = try shopContainer.decode(Int.self, forKey: .isGoldBadge)
        isGoldBadge = isGoldBadgeInt == 1

        shopTypeInfo = try shopContainer.decode(ShipmentAddressFormShopTypeInfo.self, forKey: .shopTypeInfo)
        isTokonow = try shopContainer.decode(Bool.self, forKey: .isTokonow)

        let title = try shopContainer.decode(String.self, forKey: .shopTickerTitle)
        let desc = try shopContainer.decode(String.self, forKey: .shopTickerDesc)

        shopTicker = nil

        let epharmacyPartnerData = try shopContainer.decode(ShipmentAddressFormEpharmacyPartnerData.self, forKey: .epharmacyPartnerData)
        epharmacyPartnerName = epharmacyPartnerData.showLabel ? epharmacyPartnerData.labelName : nil
    }
}

internal struct ShipmentAddressFormOrderShipmentInformationResponse: Equatable {
    internal struct PreOrder: Decodable, Equatable {
        internal let isPreOrder: Bool
        internal let durationLabel: String

        internal enum CodingKeys: String, CodingKey {
            case isPreOrder = "is_preorder"
            case durationLabel = "duration"
        }
    }

    internal let freeShippingData: FreeShippingData
    internal let preorder: PreOrder
}

extension ShipmentAddressFormOrderShipmentInformationResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case freeShippingData = "free_shipping_general"
        case preorder
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preorder = try container.decode(PreOrder.self, forKey: .preorder)
        freeShippingData = try container.decode(FreeShippingData.self, forKey: .freeShippingData)
    }
}

internal struct ShipmentAddressFormWarehouseResponse: Decodable, Equatable {
    internal let id: ShipmentWarehouseID

    internal enum CodingKeys: String, CodingKey {
        case id = "warehouse_id"
    }
}

internal struct ShipmentAddressFormDropshipperResponse: Decodable, Equatable {
    internal var name: String
    internal var phoneNumber: String

    internal enum CodingKeys: String, CodingKey {
        case name
        case phoneNumber = "telp_no"
    }
}

internal struct ShopTicker: Equatable {
    internal let title: String
    internal let desc: String
}

internal struct ShipmentAddressFormEpharmacyPartnerData: Decodable, Equatable {
    internal var labelName: String?
    internal let showLabel: Bool
}

extension ShipmentAddressFormEpharmacyPartnerData {
    internal enum CodingKeys: String, CodingKey {
        case labelName = "label_name"
        case showLabel = "show_label"
    }
}

internal struct ShipmentAddressFormShopShipmentResponse: Decodable, Equatable {
    internal let id: ShipmentID
    internal let shipperProducts: [ShipmentAddressFormShopShipmentProductResponse]

    internal var isDropshipEnabled: Bool

    internal enum CodingKeys: String, CodingKey {
        case id = "ship_id"
        case shipperProducts = "ship_prods"
        case isDropshipEnabled = "is_dropship_enabled"
    }
}

internal struct TokoCabang: Equatable {
    internal let message: String
    internal var badgeUrl: URL?
}

extension TokoCabang: Decodable {
    private enum CodingKeys: String, CodingKey {
        case message
        case badgeUrl = "badge_url"
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        /**
         Passing this as empty string in case API return broken or missing field
         empty string means no changes for icon and label and will use defaults
         */
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        let badge = try container.decodeIfPresent(String.self, forKey: .badgeUrl) ?? ""

        badgeUrl = URL(string: badge)
    }
}

internal struct ShipmentAddressFormScheduledDelivery: Decodable, Equatable {
    internal let timeslotId: Int
    internal let scheduleDate: String
    internal let validationMetadata: String
    internal let startDate: String
    internal let isRecommended: Bool
    internal var shipperId: ShipmentID = .invalid
    internal var shipperProductId: ShipmentProductID = .invalid

    internal enum CodingKeys: String, CodingKey {
        case timeslotId = "timeslot_id"
        case scheduleDate = "schedule_date"
        case validationMetadata = "validation_metadata"
        case startDate = "start_date"
        case isRecommended = "is_recommend"
    }
}

internal struct ShipmentAction: Equatable {
    internal let shipperProductID: ShipmentProductID
    internal let actionType: ShipmentActionType
    internal var popUp: ShipmentPopUpData
}

extension ShipmentAction: Decodable {
    internal enum CodingKeys: String, CodingKey {
        case shipperProductID = "sp_id"
        case action
        case popup
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shipperProductID = try container.decode(ShipmentProductID.self, forKey: .shipperProductID)
        let action = try container.decode(String.self, forKey: .action)
        actionType = ShipmentActionType(rawValue: action) ?? .merge
        popUp = try container.decode(ShipmentPopUpData.self, forKey: .popup)
    }
}

internal enum ShipmentActionType: String {
    case merge
    case split
}

internal struct ShipmentPopUpData: Equatable, Decodable {
    internal let title: String
    internal let body: String
    internal let okButton: String
    internal let cancelButton: String

    internal enum CodingKeys: String, CodingKey {
        case title
        case body
        case okButton = "button_ok"
        case cancelButton = "button_cancel"
    }
}

internal struct ShipmentAddressFormOrderGroupInfo: Decodable, Equatable {
    internal let name: String
    internal let description: String

    internal var badgeURL: URL?

    internal var descriptionBadgeURL: URL?

    internal enum CodingKeys: String, CodingKey {
        case name
        case description
        case badgeURL = "badge_url"
        case descriptionBadgeURL = "description_badge_url"
    }
}

public struct ShipmentAddressFormOrderCourierError: Decodable, Equatable {
    public let title: String
    public let description: String

    public init(title: String, description: String) {
        self.title = title
        self.description = description
    }
}

extension ShipmentAddressFormOrderCourierError {
    public enum CodingKeys: String, CodingKey {
        case title
        case description
    }
}

internal struct PopUp: Decodable, Equatable {
    internal let title: String
    internal let description: String
    internal let button: Button

    internal struct Button: Decodable, Equatable {
        internal let text: String
    }

    internal var eligibleToShow: Bool {
        return !title.isEmpty && !description.isEmpty && !button.text.isEmpty
    }
}
internal struct AddOnWording: Equatable {
    internal let packagingAndGreetingCard: String
    internal let onlyGreetingCard: String
    internal let invoiceNotSentToRecipient: String
}

extension AddOnWording: Decodable {
    private enum CodingKeys: String, CodingKey {
        case packagingAndGreetingCard = "packaging_and_greeting_card"
        case onlyGreetingCard = "only_greeting_card"
        case invoiceNotSentToRecipient = "invoice_not_sent_to_recipient"
    }
}

public typealias PrescriptionCheckoutID = String

public struct EpharmacyImageUploadResponse: Equatable {
    public let isShowImage: Bool
    public var text: String
    public let leftIconURL: URL?
    public let rightIconURL: URL?
    public let checkoutID: PrescriptionCheckoutID?
    public let isEnableValidation: Bool
    public let consultationFlow: Bool

    public var rejectedWording: String?

    public init(
        isShowImage: Bool,
        text: String,
        leftIconURL: URL?,
        rightIconURL: URL?,
        checkoutID: PrescriptionCheckoutID?,
        isEnableValidation: Bool,
        consultationFlow: Bool = false,
        rejectedWording: String? = nil
    ) {
        self.isShowImage = isShowImage
        self.text = text
        self.leftIconURL = leftIconURL
        self.rightIconURL = rightIconURL
        self.checkoutID = checkoutID
        self.isEnableValidation = isEnableValidation
        self.consultationFlow = consultationFlow
        self.rejectedWording = rejectedWording
    }
}

extension EpharmacyImageUploadResponse: Decodable {
    public enum CodingKeys: String, CodingKey {
        case isShowImage = "show_image_upload"
        case leftIconURL = "left_icon_url"
        case rightIconURL = "right_icon_url"
        case checkoutID = "checkout_id"
        case isEnableValidation = "front_end_validation"
        case text
        case consultationFlow = "consultation_flow"
        case rejectedWording = "rejected_wording"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let leftIconURLString = try container.decodeIfPresent(String.self, forKey: .leftIconURL) ?? ""
        let rightIconURLString = try container.decodeIfPresent(String.self, forKey: .rightIconURL) ?? ""
        let checkoutIDValue = try container.decodeIfPresent(String.self, forKey: .checkoutID)

        isShowImage = try container.decode(Bool.self, forKey: .isShowImage)
        text = try container.decode(String.self, forKey: .text)
        isEnableValidation = try container.decode(Bool.self, forKey: .isEnableValidation)
        leftIconURL = URL(string: leftIconURLString)
        rightIconURL = URL(string: rightIconURLString)
        checkoutID = nil
        consultationFlow = try container.decode(Bool.self, forKey: .consultationFlow)
        rejectedWording = try container.decode(String.self, forKey: .rejectedWording)
    }
}

public struct LogisticRatesMerchantVoucherCoupon {
    /// 0 -> (not available)
    /// 1 -> (available and eligible)
    /// -1 -> (available but not eligible)
    public enum MvcType: Int, Decodable {
        case eligable = 1
        case notEligable = 0
        case availableButNotEligable = -1
    }

    public let isMvc: MvcType
    public let title: String
    public let logoUrl: URL?
    public let errorMessage: String?

    public init(isMvc: LogisticRatesMerchantVoucherCoupon.MvcType, title: String, logoUrl: URL?, errorMessage: String?) {
        self.isMvc = isMvc
        self.title = title
        self.logoUrl = logoUrl
        self.errorMessage = errorMessage
    }
}

// MARK: - Extensions -

extension LogisticRatesMerchantVoucherCoupon: Decodable, Equatable {
    public enum CodingKeys: String, CodingKey {
        case isMvc = "is_mvc"
        case title = "mvc_title"
        case logoUrl = "mvc_logo"
        case errorMessage = "mvc_error_message"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        isMvc = (try? container.decode(LogisticRatesMerchantVoucherCoupon.MvcType.self, forKey: .isMvc)) ?? .notEligable
        title = try container.decode(String.self, forKey: .title)
        logoUrl = try? container.decode(URL.self, forKey: .logoUrl)
        errorMessage = try container.decode(String.self, forKey: .errorMessage)
    }
}

public enum PromoWidgetUserGroup: String, Equatable {
    case groupA = "variant_a"
    case groupB = "variant_b"
    case groupC = "variant_c"

    public var isOldUserGroup: Bool {
        switch self {
        case .groupA, .groupB:
            return false
        case .groupC:
            return true
        }
    }
}

public struct AddOn: Equatable {
    public var isEnabledButton: Bool?
    public var addOnDetailData: [AddOnDetailData]
    public var addOnButtonData: AddOnButtonData
    public var addOnBottomsheetData: AddOnBottomsheetData

    // need to add public init
    // to statisfy compiler when this struct used in public final class
    public init(
        isEnabledButton: Bool?,
        addOnDetailData: [AddOnDetailData],
        addOnButtonData: AddOnButtonData,
        addOnBottomsheetData: AddOnBottomsheetData
    ) {
        self.isEnabledButton = isEnabledButton
        self.addOnDetailData = addOnDetailData
        self.addOnButtonData = addOnButtonData
        self.addOnBottomsheetData = addOnBottomsheetData
    }
}

extension AddOn: Decodable {
    private enum CodingKeys: String, CodingKey {
        case status
        case addOnDetailData = "add_on_data"
        case addOnButtonData = "add_on_button"
        case addOnBottomsheetData = "add_on_bottomsheet"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // here we convert from int to Bool?
        let statusValue = try container.decode(Int.self, forKey: .status)

        /**
          NOTE: as for now we only have 3 status
          - case none or hidden = 0 // will not show addon card
          - case active = 1
          - case disabled = 2
         */
        var isEnabledButtonValue: Bool?
        // means other than 0 value we check it
        if statusValue > 0 {
            isEnabledButtonValue = statusValue == 1
        }

        isEnabledButton = isEnabledButtonValue

        addOnDetailData = try container.decode([AddOnDetailData].self, forKey: .addOnDetailData)
        addOnButtonData = try container.decode(AddOnButtonData.self, forKey: .addOnButtonData)
        addOnBottomsheetData = try container.decode(AddOnBottomsheetData.self, forKey: .addOnBottomsheetData)
    }
}

public struct AddOnDetailData: Equatable {
    public var addOnId: AddOnID
    public var addOnUniqueId: String
    public var addOnQty: Int
    public var addOnPrice: Int
    public var addOnMetaData: AddOnMetaData

    // need to add public init
    // to statisfy compiler when this struct used in public final class
    public init(
        addOnId: AddOnID,
        addOnUniqueId: String,
        addOnQty: Int,
        addOnPrice: Int,
        addOnMetaData: AddOnMetaData
    ) {
        self.addOnId = addOnId
        self.addOnUniqueId = addOnUniqueId
        self.addOnQty = addOnQty
        self.addOnPrice = addOnPrice
        self.addOnMetaData = addOnMetaData
    }
}

extension AddOnDetailData: Decodable {
    private enum CodingKeys: String, CodingKey {
        case addOnId = "add_on_id"
        case addOnUniqueId = "add_on_unique_id"
        case addOnQty = "add_on_qty"
        case addOnPrice = "add_on_price"
        case addOnMetaData = "add_on_metadata"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let addOnIdValue = try container.decode(Int.self, forKey: .addOnId)
        addOnId = AddOnID(rawValue: addOnIdValue)
        addOnQty = try container.decode(Int.self, forKey: .addOnQty)
        addOnUniqueId = try container.decode(String.self, forKey: .addOnUniqueId)
        addOnPrice = try container.decode(Int.self, forKey: .addOnPrice)
        addOnMetaData = try container.decode(AddOnMetaData.self, forKey: .addOnMetaData)
    }
}

public struct AddOnMetaData: Equatable {
    public var addOnNote: AddOnNote

    // need to add public init
    // to statisfy compiler when this struct used in public final class
    public init(addOnNote: AddOnNote) {
        self.addOnNote = addOnNote
    }
}

extension AddOnMetaData: Codable {
    private enum CodingKeys: String, CodingKey {
        case addOnNote = "add_on_note"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        addOnNote = try container.decode(AddOnNote.self, forKey: .addOnNote)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(addOnNote, forKey: .addOnNote)
    }
}

public struct AddOnNote: Equatable {
    public var isCustom: Bool
    public var recipientName: String
    public var senderName: String
    public var notes: String

    // need to add public init
    // to statisfy compiler when this struct used in public final class
    public init(
        isCustom: Bool,
        recipientName: String,
        senderName: String,
        notes: String
    ) {
        self.isCustom = isCustom
        self.recipientName = recipientName
        self.senderName = senderName
        self.notes = notes
    }
}

extension AddOnNote: Codable {
    private enum CodingKeys: String, CodingKey {
        case isCustom = "is_custom_note"
        case recipientName = "to"
        case senderName = "from"
        case notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        isCustom = try container.decode(Bool.self, forKey: .isCustom)
        recipientName = try container.decode(String.self, forKey: .recipientName)
        senderName = try container.decode(String.self, forKey: .senderName)
        notes = try container.decode(String.self, forKey: .notes)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(isCustom, forKey: .isCustom)
        try container.encode(recipientName, forKey: .recipientName)
        try container.encode(senderName, forKey: .senderName)
        try container.encode(notes, forKey: .notes)
    }
}

public struct AddOnButtonData: Equatable {
    public var title: String
    public var description: String
    public var leftIconURL: String
    public var rightIconURL: String
    public var isEnabledAction: Bool

    // need to add public init
    // to statisfy compiler when this struct used in public final class
    public init(
        title: String,
        description: String,
        leftIconURL: String,
        rightIconURL: String,
        isEnabledAction: Bool
    ) {
        self.title = title
        self.description = description
        self.leftIconURL = leftIconURL
        self.rightIconURL = rightIconURL
        self.isEnabledAction = isEnabledAction
    }
}

extension AddOnButtonData: Decodable {
    private enum CodingKeys: String, CodingKey {
        case title
        case description
        case leftIconURL = "left_icon_url"
        case rightIconURL = "right_icon_url"
        case action
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        leftIconURL = try container.decode(String.self, forKey: .leftIconURL)
        rightIconURL = try container.decode(String.self, forKey: .rightIconURL)

        // here we map the action for button into Bool
        let actionValue = try container.decode(Int.self, forKey: .action)
        /**
         NOTE: as for now we only have 3 action flag
          case noAction = 0 // means didn't have any action when user tap (this one possible when we get disabled state add on button)
          case openAddOnBottomsheet = 1
          case openDisabledAddOnBottomsheet = 2

         so we map the action into:
            true -> when action value > 0 (means button can do any action based on it's enabled or disabled status)
            false -> when action value == 0 (means disabled no action occured when user tap addon button)
         */
        isEnabledAction = actionValue > 0
    }
}

public struct AddOnBottomsheetData: Equatable {
    public var headerTitle: String
    public var description: String
    public var products: [AddOnBottomsheetProduct]
    public var tickerText: String

    // need to add public init
    // to statisfy compiler when this struct used in public final class
    public init(
        headerTitle: String,
        description: String,
        products: [AddOnBottomsheetProduct],
        tickerText: String
    ) {
        self.headerTitle = headerTitle
        self.description = description
        self.products = products
        self.tickerText = tickerText
    }
}

extension AddOnBottomsheetData: Decodable {
    private enum CodingKeys: String, CodingKey {
        case headerTitle = "header_title"
        case description
        case products
        case ticker

        internal enum TickerContentCodingKeys: String, CodingKey {
            case text
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        headerTitle = try container.decode(String.self, forKey: .headerTitle)
        description = try container.decode(String.self, forKey: .description)
        products = try container.decode([AddOnBottomsheetProduct].self, forKey: .products)

        let tickerContentNestedContainer = try container.nestedContainer(keyedBy: CodingKeys.TickerContentCodingKeys.self, forKey: .ticker)
        tickerText = try tickerContentNestedContainer.decode(String.self, forKey: .text)
    }
}

public struct AddOnBottomsheetProduct: Equatable {
    public var productName: String
    public var productImageURL: String

    // need to add public init
    // to statisfy compiler when this struct used in public final class
    public init(
        productName: String,
        productImageURL: String
    ) {
        self.productName = productName
        self.productImageURL = productImageURL
    }
}

extension AddOnBottomsheetProduct: Decodable {
    private enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case productImageURL = "product_image_url"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        productName = try container.decode(String.self, forKey: .productName)
        productImageURL = try container.decode(String.self, forKey: .productImageURL)
    }
}

public enum UIGroupType: Int, Codable {
    case `default` = 0
    case owoc = 1

    public init(from decoder: Decoder) throws {
        let groupTypeInt = try decoder.singleValueContainer().decode(Int.self)
        self = UIGroupType(rawValue: groupTypeInt) ?? .default
    }
}

internal struct SAFCartDetails: Equatable, Decodable {
    internal let bundleDetail: BundleDetail
    internal var products: [ShipmentAddressFormProductResponse]
    internal var cartDetailInfo: CartDetailInfo
    internal var errors: [String]

    internal func cartDetailState(
        isTradeIn: Bool,
        isPurchaseProtectionFeatureDisabled: Bool,
        parentHasError: Bool,
        shopId: ShipmentShopID,
        warehouseId: WarehouseID,
        mode: CheckoutMode,
        isFulfillment: Bool
    ) -> CartDetailState {
        let productsState = products.map { product -> ProductState in
            productState(
                from: product,
                isTradeIn: isTradeIn,
                isPurchaseProtectionFeatureDisabled: isPurchaseProtectionFeatureDisabled,
                bundleId: bundleDetail.bundleId,
                bundleType: bundleDetail.bundleType,
                parentHasError: parentHasError,
                shopId: shopId,
                warehouseId: warehouseId,
                mode: mode,
                isFulfillment: isFulfillment,
                offerID: cartDetailInfo.cartDetailType.offerID
            )
        }
        var giftState: [ProductState] = []
        let idRawValue: String
        if cartDetailInfo.cartDetailType.isOffer, let offerData = cartDetailInfo.cartDetailType.offerData {
            giftState = offerData.tiersApplied.first?.productBenefits.map(ProductState.init) ?? []
            idRawValue = cartDetailInfo.cartDetailType.offerID.rawValue
        } else {
            idRawValue = bundleDetail.bundleGroupId
        }
        return CartDetailState(
            id: CartDetailState.ID(rawValue: idRawValue),
            cartDetails: self,
            productState: productsState,
            giftState: giftState,
            parentHasError: parentHasError
        )
    }

    internal var isProductBundling: Bool {
        /**
         We have two condition for this model
          1. Product bundling, with list of products and bundleDetail info

             bundleDetail {
                bundleId: 123
                bundleGroupId: "abcde"
                ...
             },
             products: [
                product_1, product_2
             ]

          2. Regular or non bundling products, with value of bundleDetail filled with zero id or empty string
            All the regular product from this shop will be grouped in this data, meaning it supposed to be only have one SAFCartDetails for regular product

             bundleDetail {
                bundleId: 0
                bundleGroupId: ""
                ...
             },
             products: [
                product_1, product_2
             ]

         will consider  as product bundling (number 1) if have bundleId value
         */

        return bundleDetail.bundleId > 0
    }

    internal var isOfferProduct: Bool {
        cartDetailInfo.cartDetailType.isOffer
    }
}

internal enum CartDetailType: Decodable, Equatable {
    case BMGM(Offer)
    case none

    internal var offerID: OfferID {
        if case let .BMGM(offer) = self {
            return offer.offerID
        }
        return OfferID(rawValue: 0)
    }

    internal var isOffer: Bool {
        if case .BMGM = self {
            return true
        }
        return false
    }

    internal var offerData: Offer? {
        if case let .BMGM(offer) = self {
            return offer
        }

        return nil
    }
}

internal struct CartDetailInfo {
    internal let cartDetailType: CartDetailType
}

extension CartDetailInfo: Equatable, Decodable {
    private enum CodingKeys: String, CodingKey {
        case cartDetailType = "cart_detail_type"
        case bmgm
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cartDetailTypeString = try container.decode(String.self, forKey: .cartDetailType)
        if cartDetailTypeString == "BMGM" {
            let offer = try container.decode(Offer.self, forKey: .bmgm)
            cartDetailType = .BMGM(offer)
        } else {
            cartDetailType = .none
        }
    }
}

internal struct Tier {
    internal var tierID: OfferTierID
    internal var tierName: String
    internal var benefitQuantity: Int
    internal var benefitWording: String
    internal var actionWording: String
    internal var tierMessage: String
    internal var tierDiscountText: String
    internal var tierDiscountAmount: Int
    internal var priceBeforeBenefit: Int
    internal var priceAfterBenefit: Int
    internal var listProduct: [OfferProduct]
    internal var productBenefits: [OfferProductBenefit]
}

extension Tier: Equatable, Decodable {
    private enum CodingKeys: String, CodingKey {
        case tierID = "tier_id"
        case tierName = "tier_name"
        case benefitQuantity = "benefit_quantity"
        case benefitWording = "benefit_wording"
        case actionWording = "action_wording"
        case tierMessage = "tier_message"
        case tierDiscountText = "tier_discount_text"
        case tierDiscountAmount = "tier_discount_amount"
        case priceBeforeBenefit = "price_before_benefit"
        case priceAfterBenefit = "price_after_benefit"
        case listProduct = "list_product"
        case productBenefits = "products_benefit"
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let _tierID = try container.decode(Int.self, forKey: .tierID)
        tierID = OfferTierID(rawValue: _tierID)
        tierName = try container.decode(String.self, forKey: .tierName)
        benefitQuantity = try container.decode(Int.self, forKey: .benefitQuantity)
        benefitWording = try container.decode(String.self, forKey: .benefitWording)
        actionWording = try container.decode(String.self, forKey: .actionWording)
        tierMessage = try container.decode(String.self, forKey: .tierMessage)
        tierDiscountText = try container.decode(String.self, forKey: .tierDiscountText)
        tierDiscountAmount = try container.decode(Int.self, forKey: .tierDiscountAmount)
        priceBeforeBenefit = try container.decode(Int.self, forKey: .priceBeforeBenefit)
        priceAfterBenefit = try container.decode(Int.self, forKey: .priceAfterBenefit)
        listProduct = try container.decode([OfferProduct].self, forKey: .listProduct)
        productBenefits = try container.decode([OfferProductBenefit].self, forKey: .productBenefits)
    }
}

internal struct OfferProduct {
    internal var productID: ShipmentProductID
    internal var qty: Int
    internal var priceBeforeOffer: Int
    internal var priceAfterOffer: Int
    internal var cartID: CartID
}

extension OfferProduct: Equatable, Decodable {
    private enum CodingKeys: String, CodingKey {
        case productID = "product_id"
        case qty = "quantity"
        case priceBeforeOffer = "price_before_benefit"
        case priceAfterOffer = "price_after_benefit"
        case cartID = "cart_id"
    }
}

internal struct OfferProductBenefit: Equatable {
    public let productID: ShipmentProductID
    public let productName: String
    public let quantity: Int
    public let productImageURL: URL?
    public let price: Price
    public let weight: Weight
    public let actualWeight: Weight
}

extension OfferProductBenefit: Decodable {
    public enum CodingKeys: String, CodingKey {
        case productID = "product_id"
        case productName = "product_name"
        case quantity
        case productImageURL = "product_cache_image_url"
        case price = "final_price"
        case weight
        case actualWeight = "actual_weight"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let productID = try container.decode(Int.self, forKey: .productID)
        self.productID = ShipmentProductID(rawValue: productID)
        productName = try container.decode(String.self, forKey: .productName)
        quantity = try container.decode(Int.self, forKey: .quantity)
        productImageURL = try? container.decode(URL.self, forKey: .productImageURL)
        price = try container.decode(Price.self, forKey: .price)
        weight = try container.decode(Weight.self, forKey: .weight)
        actualWeight = try container.decode(Weight.self, forKey: .actualWeight)
    }
}

internal enum OfferTypeID: Int {
    case bmsm = 1
    case gwp = 2
}

internal struct Offer {
    internal var offerID: OfferID
    internal var offerTypeId: OfferTypeID
    internal var offerName: String
    internal var offerIcon: String
    internal var offerMessage: [String]
    internal var totalDiscount: Int
    internal var offerStatus: Int
    internal var isTierAchieved: Bool
    internal var tiersApplied: [Tier]

    internal var hasReachedMax: Bool {
        offerStatus == 2 /// 1 = normal. 2 = max applied reached
    }
}

extension Offer: Equatable, Decodable {
    private enum CodingKeys: String, CodingKey {
        case offerID = "offer_id"
        case offerTypeId = "offer_type_id"
        case offerName = "offer_name"
        case offerIcon = "offer_icon"
        case offerMessage = "offer_message"
        case totalDiscount = "total_discount"
        case tiersApplied = "tier_product"
        case offerStatus = "offer_status"
        case isTierAchieved = "is_tier_achieved"
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let _offerID = try container.decode(Int.self, forKey: .offerID)
        offerID = OfferID(rawValue: _offerID)

        // Offer type id of 2 is gwp, default is bmsm.
        let offerTypeID = try container.decode(Int.self, forKey: .offerTypeId)
        offerTypeId = offerTypeID == 2 ? .gwp : .bmsm

        offerName = try container.decode(String.self, forKey: .offerName)
        offerIcon = try container.decode(String.self, forKey: .offerIcon)
        offerMessage = try container.decode([String].self, forKey: .offerMessage)
        totalDiscount = try container.decode(Int.self, forKey: .totalDiscount)
        offerStatus = try container.decode(Int.self, forKey: .offerStatus)
        isTierAchieved = try container.decode(Bool.self, forKey: .isTierAchieved)
        tiersApplied = try container.decode([Tier].self, forKey: .tiersApplied)
    }
}

internal struct BundleDetail: Equatable {
    internal let bundleId: Int
    internal let bundleGroupId: String
    internal let bundleName: String
    internal let bundleType: String
    internal let bundleStatus: String
    internal let bundleDescription: String
    internal let bundlePrice: Int
    internal let bundlePriceFmt: String
    internal let bundleOriginalPrice: Int
    internal let bundleOriginalPriceFmt: String
    internal let bundleMinOrder: Int
    internal let bundleMaxOrder: Int
    internal let bundleQuota: Int
    internal let bundleQty: Int

    internal var usePriceSlashPromo: Bool {
        // Considered as slash price promo when value is different and price is lower than original
        return bundlePrice < bundleOriginalPrice
    }
}

extension BundleDetail: Decodable {
    private enum CodingKeys: String, CodingKey {
        case bundleId = "bundle_id"
        case bundleGroupId = "bundle_group_id"
        case bundleName = "bundle_name"
        case bundleType = "bundle_type"
        case bundleStatus = "bundle_status"
        case bundleDescription = "bundle_description"
        case bundlePrice = "bundle_price"
        case bundlePriceFmt = "bundle_price_fmt"
        case bundleOriginalPrice = "bundle_original_price"
        case bundleOriginalPriceFmt = "bundle_original_price_fmt"
        case bundleMinOrder = "bundle_min_order"
        case bundleMaxOrder = "bundle_max_order"
        case bundleQuota = "bundle_quota"
        case bundleQty = "bundle_qty"
    }
}

internal struct ShipmentAddressFormProductResponse: Equatable, Decodable {
    internal struct VariantDescription: Decodable, Equatable {
        internal let names: [String]
        internal let description: String
//        internal enum CodingKeys: String, CodingKey {
//            case names = "variant_name"
//            case description = "variant_description"
//        }
    }

    internal struct FreeShippingEligibility: Decodable, Equatable {
        internal let eligible: Bool
    }

    internal var id: ShipmentProductID
    internal let catId: Int // maybe category id ? https://tokopedia.slack.com/archives/G013C736QL9/p1593437918019200?thread_ts=1593432482.016900&cid=G013C736QL9

    internal let campaignId: Int

    internal var cartId: Int

    internal var categoryDescription: String?

    internal let name: String
    internal let quantity: Int

    internal var imageURL: URL?

    internal var note: String?

    /**
     seller force this product to be insuranced
     */
    internal var isForceInsurance: Bool

    internal var price: Price
    internal var originalPrice: Price
    internal var wholesalePrice: Price

    internal var isPreorder: Bool

    internal var isFreeReturn: Bool
    internal var preorder: ShipmentAddressFormProductPreorderResponse

    /**
     Weight in gram standart, 1 means 1 gram
     */
    internal let totalWeight: Weight
    internal let actualWeight: Weight
    internal let variant: VariantDescription
    internal let information: [String]
    internal let alertMessage: String

    internal var productCashbackString: String?
    internal var purchaseProtection: ShipmentAddressFormProductPurchaseProtectionResponse
    internal var tradeInInfo: ShipmentAddressFormProductTradeInInfo
    internal let trackerData: ShipmentAddressFormProductTrackerData
    internal var errors: [String]
    internal var mandatoryShipment: [ShipmentAddressFormProductShipmentMapping]

    internal var addOns: AddOn
    internal var variants: SAFProductVariant
    internal var ethicalDrug: EthicalDrug
    internal var freeShippingData: FreeShippingData
    internal let isFreeShipping: FreeShippingEligibility
    internal let isFreeShippingTc: FreeShippingEligibility

    internal let originWarehouseIDs: [Int]

    internal var addOnService: ShipmentAddressFormAddonServiceResponse

//    internal enum CodingKeys: String, CodingKey {
//        case id = "product_id"
//        case catId = "product_cat_id"
//        case campaignId = "campaign_id"
//        case categoryDescription = "product_category"
//        case cartId = "cart_id"
//        case name = "product_name"
//        case quantity = "product_quantity"
//        case imageURL = "product_image_src_200_square"
//        case note = "product_notes"
//        case isForceInsurance = "product_finsurance"
//        case price = "product_price"
//        case originalPrice = "product_original_price"
//        case wholesalePrice = "product_wholesale_price"
//        case isPreorder = "product_is_preorder"
//        case isFreeReturn = "product_is_free_returns"
//        case preorder = "product_preorder"
//        case totalWeight = "product_total_weight"
//        case actualWeight = "product_weight_actual"
//        case variant = "variant_description_detail"
//        case information = "product_information"
//        case alertMessage = "product_alert_message"
//        case productCashbackString = "product_cashback"
//        case purchaseProtection = "purchase_protection_plan_data"
//        case tradeInInfo = "trade_in_info"
//        case trackerData = "product_tracker_data"
//        case errors
//        case mandatoryShipment = "product_shipment_mapping"
//        case addOns = "add_ons"
//        case variants = "product_variants"
//        case ethicalDrug = "ethical_drug"
//        case freeShippingData = "free_shipping_general"
//        case isFreeShipping = "free_shipping"
//        case isFreeShippingTc = "free_shipping_extra"
//        case originWarehouseIDs = "origin_warehouse_ids"
//        case addOnService = "add_ons_product"
//    }
}

internal struct SAFProductVariant: Decodable, Equatable {
    internal let parentId: Int

    private enum CodingKeys: String, CodingKey {
        case parentId = "parent_id"
    }
}

internal struct ShipmentAddressFormAddonServiceResponse: Equatable {
    internal let title: String
    internal let bottomSheetData: ShipmentAddressFormAddonServiceBottomSheetData?
    internal let details: [ShipmentAddressFormAddonServiceDetails]
}

extension ShipmentAddressFormAddonServiceResponse: Decodable {
    internal enum CodingKeys: String, CodingKey {
        case title
        case bottomSheetData = "bottomsheet"
        case details = "data"
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decode(String.self, forKey: .title)

        let decodedBottomSheetData = try container.decode(ShipmentAddressFormAddonServiceBottomSheetData.self, forKey: .bottomSheetData)
        bottomSheetData = decodedBottomSheetData.isEnabled ? decodedBottomSheetData : nil

        details = try container.decode([ShipmentAddressFormAddonServiceDetails].self, forKey: .details)
    }
}

internal struct ShipmentAddressFormAddonServiceBottomSheetData: Decodable, Equatable {
    internal let title: String
    internal let isEnabled: Bool

    internal enum CodingKeys: String, CodingKey {
        case title
        case isEnabled = "is_shown"
    }
}

internal struct ShipmentAddressFormAddonServiceDetails: Equatable {
    internal let addOnId: AddOnID
    internal let uniqueId: String
    internal let price: Price

    internal var infoUrl: String?

    internal var name: String?

    internal let status: AddonInitialStatus
    internal let type: Int

    internal var iconUrl: String?

    internal let fixedQuantity: Bool
}

extension ShipmentAddressFormAddonServiceDetails: Decodable {
    internal enum CodingKeys: String, CodingKey {
        case addOnId = "id"
        case uniqueId = "unique_id"
        case price
        case infoUrl = "info_link"
        case name
        case status
        case type
        case iconUrl = "icon_url"
        case fixedQuantity = "fixed_quantity"
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedAddOnId = try container.decode(Int.self, forKey: .addOnId)
        addOnId = AddOnID(rawValue: decodedAddOnId)

        uniqueId = try container.decode(String.self, forKey: .uniqueId)

        let decodedPrice = try container.decode(Float.self, forKey: .price)
        price = Price(Int(decodedPrice))

        infoUrl = try container.decode(String.self, forKey: .infoUrl)

        name = try container.decode(String.self, forKey: .name)

        let decodedStatus = try container.decode(Int.self, forKey: .status)
        status = AddonInitialStatus(rawValue: decodedStatus) ?? .default

        type = try container.decode(Int.self, forKey: .type)

        iconUrl = try container.decode(String.self, forKey: .iconUrl)

        fixedQuantity = try container.decode(Bool.self, forKey: .fixedQuantity)
    }
}

public typealias EpharmacyGroupID = String

internal struct CheckoutPrescriptionData: Equatable {
    internal let epharmacyGroupId: EpharmacyGroupID
    internal let productsInfo: [CheckoutProductsInfo]
    internal let prescriptionImages: [CheckoutPrescriptionImages]

    // Can be nil if there is no consultation record
    internal let consultationData: CheckoutConsultationData?

    internal init(epharmacyGroupId: EpharmacyGroupID, productsInfo: [CheckoutProductsInfo], prescriptionImages: [CheckoutPrescriptionImages], consultationData: CheckoutConsultationData?) {
        self.epharmacyGroupId = epharmacyGroupId
        self.productsInfo = productsInfo
        self.prescriptionImages = prescriptionImages
        self.consultationData = consultationData
    }

    internal init(withConsultationData miniConsultationData: EpharmacyMiniConsulEpharmacyGroup) {
        let productsInfo = miniConsultationData.productsInfo.map { productInfo -> CheckoutProductsInfo in
            let products = productInfo.products.map { product -> CheckoutProducts in
                CheckoutProducts(
                    productId: ShipmentProductID(rawValue: Int(product.productId) ?? 0)
                )
            }

            return CheckoutProductsInfo(products: products)
        }

        let prescriptionImages = miniConsultationData.prescriptionImages.map { prescriptionImage -> CheckoutPrescriptionImages in
            CheckoutPrescriptionImages(
                prescriptionId: PrescriptionID(rawValue: String(prescriptionImage.prescriptionId) ?? "0"),
                status: prescriptionImage.status
            )
        }

        let consultationData = miniConsultationData.consultationData.map { consultation -> CheckoutConsultationData in
            let prescriptionIds = consultation.prescription.map { consultationPrescriptionData -> PrescriptionID in
                consultationPrescriptionData.id
            }

            let consultationStatus: CheckoutConsultationStatus = CheckoutConsultationStatus(rawValue: consultation.consultationStatus.rawValue
            ) ?? .other

            return CheckoutConsultationData(
                shopConsultationId: consultation.shopConsultationId,
                consultationMetadata: consultation.consultationString,
                prescriptionIds: prescriptionIds,
                consultationStatus: consultationStatus
            )
        }

        epharmacyGroupId = EpharmacyGroupID(rawValue: miniConsultationData.epharmacyGroupId)
        self.productsInfo = productsInfo
        self.prescriptionImages = prescriptionImages
        self.consultationData = consultationData
    }
}

internal struct CheckoutProductsInfo: Equatable {
    internal let products: [CheckoutProducts]

    internal init(products: [CheckoutProducts]) {
        self.products = products
    }
}

internal struct CheckoutPrescriptionImages: Equatable {
    internal let prescriptionId: PrescriptionID
    internal let status: String

    internal init(prescriptionId: PrescriptionID, status: String) {
        self.prescriptionId = prescriptionId
        self.status = status
    }
}

internal struct CheckoutProducts: Equatable {
    internal let productId: ShipmentProductID

    internal init(productId: ShipmentProductID) {
        self.productId = productId
    }
}

internal struct CheckoutConsultationData: Equatable {
    internal let shopConsultationId: Int
    internal let consultationMetadata: String
    internal let prescriptionIds: [PrescriptionID]
    internal let consultationStatus: CheckoutConsultationStatus

    internal init(shopConsultationId: Int, consultationMetadata: String, prescriptionIds: [PrescriptionID], consultationStatus: CheckoutConsultationStatus) {
        self.shopConsultationId = shopConsultationId
        self.consultationMetadata = consultationMetadata
        self.prescriptionIds = prescriptionIds
        self.consultationStatus = consultationStatus
    }
}

public typealias PrescriptionID = String

internal enum ShopType: String {
    case regular
    case powerMerchant = "gold_merchant"
    case officialStore = "official_store"
}

internal typealias Order = OrderState
internal struct OrderState {
    internal var checkoutMode: CheckoutMode
    internal let availableShopShipments: [ShipmentAddressFormShopShipmentResponse]
    internal var cartUniqueIdentifier: CartOrderID
    /// if shop group contains boCode when opening SAF, we will hit rates and validate to try applying BO shipment
    internal var boCode: String
    internal var boType: Int
    internal let warehouseId: ShipmentWarehouseID
    internal let isOrderPriority: Bool
    internal let isInsurance: Bool
    internal let isFullfillmentService: Bool
    internal let isPreorder: Bool

    /**
     ePharmacy consultation data (Mini Consultation)
     */
    /// Metadata for consultation
    internal var consultationMetadata: String?

    /// For empty prescription & accepted prescriptions
    internal var prescriptionIds: [PrescriptionID] = []

    /// Prescription status (accepted or rejected)
    internal var orderConsultationStatus: CheckoutConsultationStatus?

    /**
     Error from Backend
     */
    internal var errors: [String]

    internal var hasMerchantCode: Bool {
        shops.contains { $0.merchantCodes.isNotEmpty }
    }

    /**
     BBO promo or gratis ongkir promo by logistic
     */
    internal var logisticCode: PromoCode?

    // view data
    /**
     Show tradein label on top each shop group identity
     */
    internal var showTradeInLabel: Bool {
        switch checkoutMode {
        case .oneClickShipment(.tradeIn):
            return true
        default: return false
        }
    }

    /**
     Ticker on top of products view, when errors from BE exist
     */
    internal var errorTickers: [TickerContent] {
        if errors.isNotEmpty {
            return errors.map { TickerContent(type: .error, htmlContent: $0) }
        }

        if orderConsultationStatus == .rejected {
            let rejectedProductCount = shops.map { $0.prescriptionRejectedProductCount }.reduce(0, +)

            return [TickerContent(type: .error, htmlContent: "Yaah, ada \(rejectedProductCount) barang tidak bisa diproses. Kamu tetap bisa lanjut bayar yang lain. <a href='#'>\(String.consultationErrorTickerCta)</a>")]
        }

        /**
         errorsUnblocking is an error where error ticker will be shown but the order itself is not counted as error.
         This is to enable partial checkout
         Ex: Order A has 2 product, 1 product has error and another 1 doesn't. In this case there will be error ticker shown on order A.
            But the order will still be able to checkout with the product that doesn't have error.

         If the error message shown is from errors field—not to be confused with errorsUnblocking—it means all the products in that order has error.
         Meaning it won't be able to proceed to checkout at all.
         */
        return errorsUnblocking.map { TickerContent(type: .error, htmlContent: $0) }
    }

    /**
     Flag to indicate whether we can interact with error ticker or not
     */
    internal var isErrorTickersEnabled: Bool {
        guard orderConsultationStatus != nil else { return isEnabled }

        let allBundlingIsDisabled = shops.allSatisfy { $0.allBundlingIsDisabled }
        let orderHasBundling = shops.contains(where: { $0.hasBundling })

        if errors.isNotEmpty || (orderHasBundling && !allBundlingIsDisabled) {
            return false
        }

        return true
    }

    /**
     Disabled shop group from user interaction if errors from BE exists.
     when errors on shop group exist, or all product is disabled
     */
    internal var isEnabled: Bool {
        if hasPaymentLevelError { return false }

        let errorEmpty = errors.isEmpty
        /**
         check product disabled status

         there's special case,when user select outside expecting shipment, then then product should be disabled, but not all shop group.
         this case will be reflecting on `isErrorInvalidShipment`
         */
        let allProductsIsDisabled = shops.allSatisfy { $0.allProductIsDisabled }
        let allBundlingIsDisabled = shops.allSatisfy { $0.allBundlingIsDisabled }
        let orderHasBundling = shops.contains(where: { $0.hasBundling })

        return errorEmpty && (!allProductsIsDisabled || (orderHasBundling && !allBundlingIsDisabled))
    }

    /**
     this value will show the index based on current shop group on checkout
     currently, the value is set when receiving SAF Response.

     if there's any changes on shop group position, let's say on the future, if shop group position can be swapped, or
     some shopgroup can be deleted on current session, please update this logic to set this value
     */
    internal var indexLabel: String?
    internal var identity: ShopIdentityViewData
    /// valid only products
    internal var validProducts: [ProductState] {
        // if order is invalid, then all product is invalid
        if errors.isNotEmpty {
            return []
        }

        return shops.flatMap { shop -> [ProductState] in
            shop.products.filter { $0.errors.isEmpty && $0.isPrescriptionAccepted }
        }
    }

    /**
     All products (non-bundling & bundling) that are valid & enabled
     */
    internal var enabledValidProducts: [ProductState] {
        let validBundlingProducts = shops.flatMap { shop -> [ProductState] in
            shop.cartDetailState.flatMap { cartDetail -> [ProductState] in
                cartDetail.validProducts
            }
        }

        return validProducts.filter { $0.isEnabled } + validBundlingProducts.filter { $0.isEnabled }
    }

    internal var shipment: ShipperState? {
        didSet {
            // update product valid shipment, when shipment did change
//            if let newShipment = shipment {
//                for shop in shops {
//                    shops[id: shop.id]?.products = updateProductAfterShipmentDidChangeHook(
//                        products: shop.products,
//                        newValue: newShipment,
//                        oldValue: oldValue
//                    )
//                }
//            }
        }
    }

    /// Scheduled Delivery Node data
    internal var scheduledDelivery: ScheduledDeliveryShipperState?

    internal var safDropshipperData: ShipmentAddressFormDropshipperResponse?
    internal var dropshipperDetail: DropshipperDetailState?
    internal var insurance: InsuranceData?

    internal var subtotal: SubtotalState {
        SubtotalState(from: self)
    }

    internal var isChangeCourierEnabled: Bool
    internal var autoCourierSelection: Bool
    internal var hasCourierError: Bool
    internal var BOMetadata: ShipmentAddressFormOrderBOMetadata

    internal var errorsUnblocking: [String]
    internal var hasPaymentLevelError: Bool
    internal var isTokoNowPinPointed: Bool
    internal var addOnState: AddOnState
    internal var safScheduledDeliveryData: ShipmentAddressFormScheduledDelivery

    internal var productIds: String {
        let shopsProductIds = shops.map { shop -> String in
            let productIds = shop.products.map { product -> String in
                String(product.id.rawValue)
            }

            let bundleProductIds = shop.cartDetailState.map { cartDetail -> String in
                cartDetail.productState.map { product in
                    String(product.id.rawValue)
                }.joined(separator: ",")
            }

            return (productIds + bundleProductIds).joined(separator: ",")
        }

        return shopsProductIds.joined(separator: ",")
    }

    internal var productCategoryIds: String {
        let shopsProductCategoryIds = shops.map { shop -> String in
            let productCategoryIds = shop.products.map { product -> String in
                String(product.categoryId)
            }

            let bundleProductCategoryIds = shop.cartDetailState.map { cartDetail -> String in
                cartDetail.productState.map { product in
                    String(product.categoryId)
                }.joined(separator: ",")
            }

            return (productCategoryIds + bundleProductCategoryIds).joined(separator: ",")
        }

        return shopsProductCategoryIds.joined(separator: ",")
    }

    internal var shops: [ShopState] = []

    internal let groupType: GroupType
    internal let uiGroupType: UIGroupType

    /**
     `Add-ons as a service` data from BE to be passed to `SubtotalState`
     */
    internal var safAddOnServiceSubtotalSummary: [ShipmentAddressFormAddonServiceSummary]

    internal var orderDescription: String?

    internal var offerPrice: Int?

    internal var groupMetadata: String

    // OFOC
    internal var groupingState: GroupingState
    internal var shippingComponent: ShippingComponent
    internal var shipmentAction: [ShipmentAction]
    internal var splitOrderPopUp: SplitOrderDialogData?
}

extension OrderState: Identifiable {
    internal var id: CartOrderID {
        cartUniqueIdentifier
    }
}

extension OrderState: Equatable {}

extension ShipmentWarehouseID {
    internal static var invalid: Self {
        .init(rawValue: 0)
    }
}

/**
 listen to shipment changes, and everytime shipment productId is changing, will check if current selection shipment is valid for `products`.
 if not, then disable the respective product

 - Parameters:
    - products: product state
    - newValue: new changed `ShipperState`
    - oldValue: previous `ShipperState` value
 */
internal func updateProductAfterShipmentDidChangeHook(products: [ProductState], newValue: ShipperState, oldValue: ShipperState?) -> [ProductState] {
    guard
        /**
            data must be distinct
            */
        newValue.shipperProductId != oldValue?.shipperProductId,
        /**
            user must select shipment first
            */
        newValue.shipperProductId != .invalid
    else { return products }

    return products.map { product in
        guard product.mandatoryShipment.isNotEmpty else { return product }

        let productIds = product.mandatoryShipment.flatMap { $0.serviceIds.flatMap { $0.productIds }}

        var newProduct = product
        newProduct.isErrorInvalidShipment = !productIds.contains(newValue.shipperProductId)

        return newProduct
    }
}

internal enum ImageSource: Identifiable, Equatable {
    case url(URL)
    case local(String)

    internal var id: String {
        switch self {
        case let .url(url):
            return url.absoluteString
        case let .local(logoName):
            return logoName
        }
    }
}

internal struct ShopIdentityViewData: Equatable {
    internal let logos: [ImageSource]
    internal let name: String
    internal let freeShipmentLogo: URL?
    internal let preOrderLabel: String?
    internal let campaignLabel: String?
    internal let warningTicker: [TickerContent]
    internal var epharmacyPartnerName: String?
}

/**
 This is mode for subtitle
 */
internal enum CheckboxWithDescriptionSubtitle: Equatable {
    case egold(String?, Price)
}

/**
 View data for `CheckboxWithDescriptionNode`
 */
internal struct CheckboxWithDescriptionViewData: Equatable {
    internal var title: String
    internal var isSelected: Bool
    internal var isEnabled: Bool
    internal var bottomSheetData: CheckboxWithDescriptionBottomSheet?
    internal var subtitle: CheckboxWithDescriptionSubtitle?
    internal var hyperlinkText: CheckboxWithDescriptionHyperlinkText?
    internal var iconUrl: URL?
}

internal struct CheckboxWithDescriptionBottomSheet: Equatable {
    internal let title: String
    internal let description: String
    internal let logoName: String?

    internal static let dropshipper = CheckboxWithDescriptionBottomSheet(
        title: "Dropshipper",
        description: "Penjual, sebagai supplier akan mengirim barang ke pembeli Anda dengan mengatasnamakan toko anda Syarat dan ketentuan toko berlaku",
        logoName: "tooltip_dropshipper"
    )

    internal static let dropshipperNotAvailableBecauseFreeShipment = CheckboxWithDescriptionBottomSheet(
        title: "Dropshipper tidak tersedia",
        description: "Pengiriman secara dropshipping tidak bisa dipilih karena kamu menggunakan Bebas Ongkir",
        logoName: "tooltip_dropshipper"
    )
}

internal struct CheckboxWithDescriptionHyperlinkText: Equatable {
    internal let text: String
    internal let url: String
}

internal struct SplitOrderDialogData: Equatable {
    internal let title: String
    internal let description: String
    internal let buttonTitle: String
    internal let secondaryButtonTitle: String?
}

public typealias DeviceID = String
public typealias LeasingID = Int

public enum OCSMode: Equatable {
    case `default`
    case tradeIn(deviceId: DeviceID)
    case leasing(id: LeasingID)
}

public enum CheckoutMode: Equatable {
    case `default`(source: String)
    case oneClickShipment(OCSMode)

    internal var isOneClickShipment: Bool {
        if case .oneClickShipment = self {
            return true
        } else {
            return false
        }
    }

    internal var isTradeIn: Bool {
        if case .oneClickShipment(.tradeIn) = self {
            return true
        } else {
            return false
        }
    }

    internal func getLeasingId() -> LeasingID {
        if case let .oneClickShipment(.leasing(id)) = self {
            return id
        } else {
            return 0
        }
    }

    internal func getDeviceId() -> DeviceID {
        if case let .oneClickShipment(.tradeIn(id)) = self {
            return id
        } else {
            return ""
        }
    }
}

internal struct CartDetailState: Identifiable, Equatable {
    internal typealias ID = String

    internal let id: CartDetailState.ID
    internal var cartDetails: SAFCartDetails
    internal var productState: [ProductState]
    internal var giftState: [ProductState]

    // Flag to determine if shop group or payment level has error
    internal var parentHasError: Bool

    // MARK: - Computed properties

    internal var offerHeaderString: NSAttributedString? {
        guard cartDetails.isOfferProduct, case let .BMGM(offer) = cartDetails.cartDetailInfo.cartDetailType else { return nil }

        let offerMessage = offer.offerMessage.joined(separator: " • ")
        return (try? offerMessage.htmlWithSwiftSoup(typography: .display3, textColor: .TN500) ?? NSAttributedString.display3(offerMessage))
    }

    internal var validProducts: [ProductState] {
        // if cartDetails is invalid, then all product is invalid
        if cartDetails.errors.isNotEmpty { return [] }

        // return products that have no error
        return productState.filter { $0.errors.isEmpty }
    }

    internal var giftValidProducts: [ProductState] {
        // if cartDetails is invalid, then all product is invalid
        if cartDetails.errors.isNotEmpty { return [] }

        // return products that have no error
        return giftState.filter { $0.errors.isEmpty }
    }

    /**
     Ticker if error from BE exist
     */
    internal var errorTickers: [TickerContent] {
        var tickers: [TickerContent] = []

        tickers.append(contentsOf: cartDetails.errors.map { TickerContent(type: .error, htmlContent: $0) })

        return tickers
    }

    /**
     prevent user interaction if any user error exist
     */
    internal var isEnabled: Bool {
        guard !parentHasError else { return false }
        return cartDetails.errors.isEmpty
    }
}

internal typealias Product = ProductState

internal struct ProductState: Identifiable, Equatable {
    internal var id: ShipmentProductID
    internal let cartId: Int
    internal let categoryId: Int
    internal let categoryDescription: String?
    internal let bundleId: Int
    internal let bundleType: String
    internal var quantity: Int
    internal let isForceInsurance: Bool
    internal var preOrderDurationDays: Int
    internal let totalWeight: Weight
    internal let actualWeight: Weight
    internal var errors: [String]
    internal var mandatoryShipment: [ShipmentAddressFormProductShipmentMapping]
    internal var offerID: OfferID

    /**
     Ticker if error from BE exist
     */
    internal var errorTickers: [TickerContent] {
        var tickers: [TickerContent] = []

        if !isPrescriptionAccepted,
            shouldDisplayProductErrorTicker,
            let htmlContent = consultationRejectedTickerContent {
            tickers.append(TickerContent(type: .error, htmlContent: htmlContent))
        }

        if isErrorInvalidShipment {
            tickers.append(.invalidProductShipment)
        }
        tickers.append(contentsOf: errors.map { TickerContent(type: .error, htmlContent: $0) })

        return tickers
    }

    /**
     Flag to indicate whether we can interact with error ticker or not
     */
    internal var isErrorTickersEnabled: Bool {
        guard epharmacyGroupId != nil else { return isEnabled }

        if isErrorInvalidShipment || errors.isNotEmpty {
            return false
        }

        return true
    }

    internal var title: String
    internal var subtitle: String
    internal var price: Price
    /**
     available if mode is TradeIn
     */
    internal var oldDevicePrice: Price
    internal var originalPrice: Price
    internal var deviceModel: String
    internal var diagnosticId: Int

    internal var showOriginalPrice: Bool {
        originalPrice != 0 && price < originalPrice
    }

    internal var variantDescription: String?
    /// value from BE, put on top price
    internal var information: [String]
    /// value from BE, put on top price
    internal var alertMessage: String?
    /// value from BE, put on bottom price
    internal var ethicalDrug: EthicalDrug?

    /// render value for information and alertMessage
    internal var informationAndAlertMessage: String? {
        var label: String?

//        if let mergedInformation = information.joined(separator: ", ") {
//            label = (label ?? "") + mergedInformation
//        }

        if let alertMessage = alertMessage {
            if label != nil {
                label = (label ?? "") + ", "
            }

            label = (label ?? "") + alertMessage
        }

        return label
    }

    internal var note: String?
    internal var imageLink: URL?
    internal var isPreOrder: Bool

    /**
     Flag for Mini Consultation, will be nil if it is not Mini Consultation product
     */
    internal var epharmacyGroupId: EpharmacyGroupID?

    /**
        Default value will be `true` for approved prescriptions and non-Mini Consultation flow
        Value will be `false` if prescription is rejected
     */
    internal var isPrescriptionAccepted: Bool

    /**
     Flag to display error ticker for Mini Consultation
        Default value will be `false`
        Value will be `true` when there is partial rejection in 1 shop group
     */
    internal var shouldDisplayProductErrorTicker: Bool = false

    /**
     Error ticker `htmlContent` from BE for Mini Consultation
     */
    internal var consultationRejectedTickerContent: String?

    // Flag to determine if shop group or payment level has error
    internal var parentHasError: Bool

    /**
     prevent user interaction if any user error exist
     */
    internal var isEnabled: Bool {
        guard !parentHasError else { return false }
        return (isPrescriptionAccepted) && (!isErrorInvalidShipment && errors.isEmpty)
    }

    /**
     Flag determine if this product can't be send with current selected shipment
     */
    internal var isErrorInvalidShipment: Bool = false
    internal var potentialCashbackAmount: Price {
        Price((price * Price(quantity) * Price(potentialCashbackPercentage)).rawValue / 100)
    }

    internal var potentialCashbackPercentage: Int
    internal var purchaseProtection: PurchaseProtectionCheckboxViewData?

    internal var trackerData: ShipmentAddressFormProductTrackerData
    internal var addOnState: AddOnState
    internal var variants: SAFProductVariant

    internal var freeShippingData: FreeShippingData
    internal let isFreeShipping: Bool
    internal let isFreeShippingTc: Bool

    /**
     Data for add-on picker (`add-ons as a service`)
     */
    internal var addOnPickerData: AddonPickerData?

    internal var productImageSize: Int
}

extension ProductState {
    internal init(from gift: OfferProductBenefit) {
        let subtitle = "\(gift.quantity) x \(gift.price.currencyDescription)"

        id = gift.productID
        cartId = 0
        categoryId = 0
        categoryDescription = nil
        bundleId = 0
        bundleType = ""
        quantity = gift.quantity
        isForceInsurance = false
        preOrderDurationDays = 0
        totalWeight = gift.weight * Weight(integerLiteral: gift.quantity)
        actualWeight = gift.actualWeight
        errors = []
        mandatoryShipment = []
        offerID = ""
        title = gift.productName
        self.subtitle = subtitle
        price = 0
        oldDevicePrice = 0
        originalPrice = 0
        deviceModel = ""
        diagnosticId = 0
        variantDescription = nil
        information = []
        alertMessage = nil
        ethicalDrug = nil
        note = nil
        imageLink = gift.productImageURL
        isPreOrder = false
        epharmacyGroupId = nil
        isPrescriptionAccepted = true
        shouldDisplayProductErrorTicker = false
        consultationRejectedTickerContent = nil
        parentHasError = false
        isErrorInvalidShipment = false
        potentialCashbackPercentage = 0
        purchaseProtection = nil
        trackerData = ShipmentAddressFormProductTrackerData(attribution: "", listName: "")
        addOnState = AddOnState(addOn: AddOn(isEnabledButton: nil, addOnDetailData: [], addOnButtonData: AddOnButtonData(title: "", description: "", leftIconURL: "", rightIconURL: "", isEnabledAction: false), addOnBottomsheetData: AddOnBottomsheetData(headerTitle: "", description: "", products: [], tickerText: "")))
        variants = SAFProductVariant(parentId: 0)
        freeShippingData = FreeShippingData(boName: "", boType: BOType.none, badgeUrl: "")
        isFreeShipping = false
        isFreeShippingTc = false
        addOnPickerData = nil
        productImageSize = 56
    }
}

internal func productState(
    from response: ShipmentAddressFormProductResponse,
    isTradeIn: Bool,
    isPurchaseProtectionFeatureDisabled: Bool,
    bundleId: Int,
    bundleType: String,
    parentHasError: Bool,
    shopId: ShipmentShopID,
    warehouseId: WarehouseID,
    mode: CheckoutMode,
    isFulfillment: Bool,
    offerID: OfferID
) -> ProductState {
    let price: Price = {
        if isTradeIn {
            return response.price
        } else { // normal
            return response.wholesalePrice // use wholesale price, so when whole sale is true, the price will scale itself
        }
    }()

    let originalPrice: Price = {
        if isTradeIn {
            return response.tradeInInfo.newDevicePrice
        } else { // normal
            return response.originalPrice
        }
    }()

    let ethicalDrug: EthicalDrug? = {
        guard response.ethicalDrug.isNeedPrescription else { return nil }
        return response.ethicalDrug
    }()

    let addOnPickerData: AddonPickerData? = {
        guard response.addOnService.details.isNotEmpty else { return nil }

        return AddonPickerData(
            from: response,
            price: price,
            shopId: shopId,
            warehouseId: warehouseId,
            mode: mode,
            isFulfillment: isFulfillment
        )
    }()

    let isOffer = offerID.rawValue != "0"

    var title = response.name
    var subtitle = String(response.quantity) + " x " + price.currencyDescription
    var productImageSize = 66

    // If it's bundle product
    if bundleId != 0 {
        title = "\(response.quantity) x " + response.name
        subtitle = ""
        productImageSize = 56
    }

    // If it's offer product
    if isOffer {
        productImageSize = 56
    }

    return ProductState(
        id: response.id,
        cartId: response.cartId,
        categoryId: response.catId,
        categoryDescription: response.categoryDescription,
        bundleId: bundleId,
        bundleType: bundleType,
        quantity: response.quantity,
        isForceInsurance: response.isForceInsurance,
        preOrderDurationDays: Int(response.preorder.durationDay) ?? 0,
        totalWeight: response.totalWeight,
        actualWeight: response.actualWeight,
        errors: response.errors,
        mandatoryShipment: response.mandatoryShipment,
        offerID: offerID,
        title: title,
        subtitle: subtitle,
        price: price,
        oldDevicePrice: response.tradeInInfo.oldDevicePrice,
        originalPrice: originalPrice,
        deviceModel: response.tradeInInfo.deviceModel,
        diagnosticId: response.tradeInInfo.diagnosticId,
        variantDescription: response.variant.description,
        information: response.information,
        alertMessage: response.alertMessage,
        ethicalDrug: ethicalDrug,
        note: response.note,
        imageLink: response.imageURL,
        isPreOrder: response.isPreorder,
        isPrescriptionAccepted: true,
        parentHasError: parentHasError,
        potentialCashbackPercentage: Int(response.productCashbackString?.replacingOccurrences(of: " %", with: "") ?? "0") ?? 0,
        purchaseProtection: isPurchaseProtectionFeatureDisabled ? nil : purchaseProtectionCheckboxViewData(from: response.purchaseProtection),
        trackerData: response.trackerData,
        addOnState: AddOnState(addOn: response.addOns),
        variants: response.variants,
        freeShippingData: response.freeShippingData,
        isFreeShipping: response.isFreeShipping.eligible,
        isFreeShippingTc: response.isFreeShippingTc.eligible,
        addOnPickerData: addOnPickerData,
        productImageSize: productImageSize
    )
}

public struct EthicalDrug: Equatable {
    public let isNeedPrescription: Bool
    public let iconURL: URL?
    public let text: String

    public init(
        isNeedPrescription: Bool,
        iconURL: URL?,
        text: String
    ) {
        self.isNeedPrescription = isNeedPrescription
        self.iconURL = iconURL
        self.text = text
    }
}

extension EthicalDrug: Decodable {
    public enum CodingKeys: String, CodingKey {
        case isNeedPrescription = "need_prescription"
        case iconURL = "icon_url"
        case text
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let iconUrlString = try container.decodeIfPresent(String.self, forKey: .iconURL) ?? ""

        isNeedPrescription = try container.decode(Bool.self, forKey: .isNeedPrescription)
        iconURL = URL(string: iconUrlString)
        text = try container.decode(String.self, forKey: .text)
    }
}

public struct AddonPickerData: Equatable {
    public let title: String
    public var ctaText: String?
    public var details: [AddonPickerDetailData]
    public var cartProduct: AddonPickerCartProduct
    public var pageSource: AddonPageSource

    public var pageSourceName: String {
        switch pageSource {
        case let .checkout(_, isOCS):
            return isOCS ? "ocs" : "normal"
        case .occ:
            return "occ"
        default:
            return ""
        }
    }

    public init(
        title: String,
        ctaText: String?,
        details: [AddonPickerDetailData],
        cartProduct: AddonPickerCartProduct,
        pageSource: AddonPageSource
    ) {
        self.title = title
        self.ctaText = ctaText
        self.details = details
        self.cartProduct = cartProduct
        self.pageSource = pageSource
    }
}

public struct AddonPickerDetailData: Equatable {
    public var addOnId: AddOnID
    public var addOnUniqueId: String
    public var status: AddonInitialStatus
    public var name: String
    public var infoUrl: String?
    public var price: Price
    public var type: Int
    public var iconUrl: URL?
    public var fixedQuantity: Bool

    public init(
        addOnId: AddOnID,
        addOnUniqueId: String,
        status: AddonInitialStatus,
        name: String,
        infoUrl: String?,
        price: Price,
        type: Int,
        iconUrl: URL? = nil,
        fixedQuantity: Bool
    ) {
        self.addOnId = addOnId
        self.addOnUniqueId = addOnUniqueId
        self.status = status
        self.name = name
        self.infoUrl = infoUrl
        self.price = price
        self.type = type
        self.iconUrl = iconUrl
        self.fixedQuantity = fixedQuantity
    }
}


public typealias CategoryID = String
public typealias ProductID = String
public typealias ParentProductID = String
/**
 Product data from other page (Checkout, OCC)
 */
public struct AddonPickerCartProduct: Equatable {
    public let cartId: CartID
    public let productId: ProductID
    public let shopId: ShopID
    public let productPrice: Int
    public let discountedPrice: Int
    public var quantity: Int
    public let categoryId: CategoryID
    public let warehouseId: WarehouseID
    public let productParentId: ParentProductID
    public let productName: String

    public init(
        cartId: CartID,
        productId: ProductID,
        shopId: ShopID,
        productPrice: Int,
        discountedPrice: Int,
        quantity: Int,
        categoryId: CategoryID,
        warehouseId: WarehouseID,
        productParentId: ParentProductID,
        productName: String
    ) {
        self.cartId = cartId
        self.productId = productId
        self.discountedPrice = discountedPrice
        self.shopId = shopId
        self.productPrice = productPrice
        self.quantity = quantity
        self.categoryId = categoryId
        self.warehouseId = warehouseId
        self.productParentId = productParentId
        self.productName = productName
    }
}

extension AddonPickerCartProduct {
    internal func mapToLocalParam() -> SaveAddOnCartProduct {
        SaveAddOnCartProduct(
            cartID: cartId.intValue,
            productID: productId.intValue,
            warehouseID: warehouseId.intValue,
            productName: productName,
            productImageURL: "", // Empty because BE don't need the value
            productParentID: productParentId.intValue
        )
    }
}

public enum AddonInitialStatus: Int, Equatable {
    case `default` = 0
    case selected = 1
    case unselect = 2
    case mandatory = 3
}

public struct EpharmacyMiniConsulEpharmacyGroup: Decodable, Equatable {
    public let epharmacyGroupId: String
    public let productsInfo: [EpharmacyMiniConsulProductInfo]
    public let prescriptionSource: [String]

    public init(
        epharmacyGroupId: String,
        productsInfo: [EpharmacyMiniConsulProductInfo],
        prescriptionSource: [String]
    ) {
        self.epharmacyGroupId = epharmacyGroupId
        self.productsInfo = productsInfo
        self.prescriptionSource = prescriptionSource
    }

    private enum CodingKeys: String, CodingKey {
        case epharmacyGroupId = "epharmacy_group_id"
        case productsInfo = "products_info"
        case prescriptionSource = "prescription_source"
    }
}

public struct EpharmacyMiniConsulProductInfo: Decodable, Equatable {
    public let shopId: String
    public let shopName: String
    public let shopType: String
    public let shopLocation: String
    public let shopLogoUrl: String
    public let partnerLogoUrl: String
    public let products: [EpharmacyMiniConsulProductModel]

    public init(
        shopId: String,
        shopName: String,
        shopType: String,
        shopLocation: String,
        shopLogoUrl: String,
        partnerLogoUrl: String,
        products: [EpharmacyMiniConsulProductModel]
    ) {
        self.shopId = shopId
        self.shopName = shopName
        self.shopType = shopType
        self.shopLocation = shopLocation
        self.shopLogoUrl = shopLogoUrl
        self.partnerLogoUrl = partnerLogoUrl
        self.products = products
    }

    private enum CodingKeys: String, CodingKey {
        case shopId = "shop_id_str"
        case shopName = "shop_name"
        case shopType = "shop_type"
        case shopLocation = "shop_location"
        case shopLogoUrl = "shop_logo_url"
        case partnerLogoUrl = "partner_logo_url"
        case products
    }
}

public struct EpharmacyMiniConsulProductModel: Decodable, Equatable {
    public let productId: String
    public let productName: String
    public let quantity: Int
    public let isEthicalDrug: Bool
    public let productImage: String
    public let itemWeight: Int
    public let productTotalWeightFmt: String
    public let qtyComparison: EpharmacyQuantityComparison?
    public let price: Int
    public let productIdInt: Int
    public let cartId: Int

    public init(
        productId: String,
        productName: String,
        quantity: Int,
        isEthicalDrug: Bool,
        productImage: String,
        itemWeight: Int,
        productTotalWeightFmt: String,
        qtyComparison: EpharmacyQuantityComparison?,
        price: Int,
        productIdInt: Int,
        cartId: Int
    ) {
        self.productId = productId
        self.productName = productName
        self.quantity = quantity
        self.isEthicalDrug = isEthicalDrug
        self.productImage = productImage
        self.itemWeight = itemWeight
        self.productTotalWeightFmt = productTotalWeightFmt
        self.qtyComparison = qtyComparison
        self.price = price
        self.productIdInt = productIdInt
        self.cartId = cartId
    }

    private enum CodingKeys: String, CodingKey {
        case productId = "product_id_str"
        case productName = "name"
        case quantity
        case isEthicalDrug = "is_ethical_drug"
        case productImage = "product_image"
        case itemWeight = "item_weight"
        case productTotalWeightFmt = "product_total_weight_fmt"
        case qtyComparison = "qty_comparison"
        case price
        case productIdInt = "product_id"
        case cartId = "cart_id"
    }
}

public struct EpharmacyQuantityComparison: Equatable, Decodable {
    public let initialQty: Int?
    public let recommendedQty: Int?

    public init(
        initialQty: Int?,
        recommendedQty: Int?
    ) {
        self.initialQty = initialQty
        self.recommendedQty = recommendedQty
    }

    private enum CodingKeys: String, CodingKey {
        case initialQty = "initial_qty"
        case recommendedQty = "recommend_qty"
    }
}
internal enum CheckoutConsultationStatus: Int, Equatable {
    case approved = 2
    case rejected = 4
    case other
}

internal struct PromoCode: Equatable {
    internal var code: String

    /**
     flag to determine if current code is valid or not.

     when validating promo code, BE can say some code can be invalid.
     when code is invalid, we can't on checkout(payment), but we can throw the code away.

     when the code is invalid because maybe let's say wrong shipment
     when user change the shipment, we need to revalidate the promo, so we need to keep the code.
     */
    internal var isValid: Bool

    /**
     return valid code based
     */
    internal var validCode: String? {
        isValid ? code : nil
    }

    internal init?(code: String, isValid: Bool) {
        self.code = code
        self.isValid = isValid
    }
}

public enum ShipperMode: Equatable {
    case loading
    case normal(duration: ShipperDetailViewData, courier: ShipperDetailViewData?)
}

public typealias Shipment = ShipperState
public struct ShipperState: Equatable {
    public var shipperId: ShipmentID
    public var shipperProductId: ShipmentProductID

    /**
     current selected shipment
     */
    public var selectedShipmentData: SelectedShipmentData?

    /**
     current ui
     */
    public var mode: ShipperMode

    /**
     shipping widget experience
     available values:
     - checkout revamp
     - default (pre checkout revamp)
     */
    public let widgetExperience: ShippingWidgetExperience

    /**
     Change style on showing shipment: default, tradeInDropOff
     */
    public var viewStyle: ShipperNodeStyle

    /**
     Flag to set `ShipperNode` with red border color to get user attention
     */
    public var isHighlighted: Bool

    /**
     Animate wiggle on `ShipperNode`
     */
    public var wiggling: Bool

    /**
     Show or hide shipment picker, if nil will hide the picker
     */
    public var showShipmentPicker: ShipperPickerParams?

    /**
     Enable or disable the shipment picker view.
     There are cases where the shipmentPicker view is enabled but user interaction is not allowed.
     This is why there is separate field for enabling view and enabling interaction.
     */
    public var enableShipmentPicker: Bool

    /**
     Enable or disable the shipment picker user interaction
     */
    public var enableShipmentPickerInteraction: Bool

    public init(
        shipperId: ShipmentID,
        shipperProductId: ShipmentProductID,
        selectedShipmentData: SelectedShipmentData? = nil,
        mode: ShipperMode,
        widgetExperience: ShippingWidgetExperience,
        viewStyle: ShipperNodeStyle,
        isHighlighted: Bool,
        wiggling: Bool,
        showShipmentPicker: ShipperPickerParams? = nil,
        enableShipmentPicker: Bool,
        enableShipmentPickerInteraction: Bool
    ) {
        self.shipperId = shipperId
        self.shipperProductId = shipperProductId
        self.selectedShipmentData = selectedShipmentData
        self.mode = mode
        self.widgetExperience = widgetExperience
        self.viewStyle = viewStyle
        self.isHighlighted = isHighlighted
        self.wiggling = wiggling
        self.showShipmentPicker = showShipmentPicker
        self.enableShipmentPicker = enableShipmentPicker
        self.enableShipmentPickerInteraction = enableShipmentPickerInteraction
    }
}

public enum ShipperErrorState: Equatable {
    case saf // Shipment address form (Checkout)
    case rates // Logistic Rates
    case none
}

public enum UnifyIcon: CaseIterable {
    case add
}

public struct ShipperDetailViewData: Equatable {
    public var logo: UnifyIcon?
    public var titleLogo: URL?
    public var freeShipmentLogoURL: URL?
    public var title: ShipperTitle
    public var cashOnDeliveryTitle: String?
    public var subtitle: ShipperDetailSubtitle?
    public var subSubtitle: ShipperDetailSubtitle?
    public var accessibilityIdentifier: String
    public var titleAccessibilityIdentifier: String
    public var chevronAccessibilityIdentifier: String
    public var hasArrowLogo: Bool
    public var hasRefreshButton: Bool
    public var accessibilityLabel: String
    public let errorState: ShipperErrorState

    public init(
        logo: UnifyIcon? = nil,
        titleLogo: URL? = nil,
        freeShipmentLogoURL: URL? = nil,
        title: ShipperTitle,
        cashOnDeliveryTitle: String? = nil,
        subtitle: ShipperDetailSubtitle? = nil,
        subSubtitle: ShipperDetailSubtitle? = nil,
        accessibilityIdentifier: String,
        titleAccessibilityIdentifier: String = "",
        chevronAccessibilityIdentifier: String = "",
        hasArrowLogo: Bool,
        hasRefreshButton: Bool,
        accessibilityLabel: String,
        errorState: ShipperErrorState = .none
    ) {
        self.logo = logo
        self.titleLogo = titleLogo
        self.freeShipmentLogoURL = freeShipmentLogoURL
        self.title = title
        self.cashOnDeliveryTitle = cashOnDeliveryTitle
        self.subtitle = subtitle
        self.subSubtitle = subSubtitle
        self.accessibilityIdentifier = accessibilityIdentifier
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.chevronAccessibilityIdentifier = chevronAccessibilityIdentifier
        self.hasArrowLogo = hasArrowLogo
        self.hasRefreshButton = hasRefreshButton
        self.accessibilityLabel = accessibilityLabel
        self.errorState = errorState
    }
}

public enum ShipperDetailSubtitle: Equatable {
    case price(Price)
    case slashPrice(oldPrice: Price, newPrice: Price)
    case text(String, useSmallText: Bool = false, isError: Bool = false)
    case statement(
        price: Price,
        text: String,
        tncLabel: String,
        tncLink: URL?
    )
    case statementWithoutPrice(text: String, tncLabel: String, tncLink: URL?)
    case tokonowPinPoint(text: String, address: PinPointAddressDetailDataParams)
}

public enum ShipperTitle: Equatable {
    case text(String)
    case html(String)
}

public enum ShipperNodeStyle {
    case `default`
    case tradeInDropOff
}

public struct SelectedShipmentData: Equatable {
    public let ratesId: RatesID

    public let shipperServiceName: String
    public let shipperProductName: String

    public let isFreeShipment: Bool
    /// set true, so when user select duration, the product will be hidden
    public var hideProduct: Bool = false
    public let freeShipmentPromoCode: String
    public let freeShipmentBenefitAmount: Price
    public let freeShipmentDiscountedPrice: Price
    public let freeShipmentImageURL: URL?

    public let keroUnixTime: KeroUnixTimeID
    public let checksum: String
    public let insurancePrice: Price? // Used in old checkout
    public var shipperInsurance: ShipperInsuranceState? // Used in checkout revamp
    public let orderPriorityPrice: Price
    public var price: Price

    public var onTimeGuaranteeDelivery: LogisticRatesServiceOnTimeDelivery?
    public var cashOnDelivery: LogisticRatesServiceProductCODResponse?
    public var merchantVoucherCouponLogoUrl: URL?
    public var etaDescription: String?

    public var isChangeCourierEnabled: Bool
    public var tokoNowBenefitDescription: String?

    /// data to be sent to checkout when BO is applied
    public let freeShippingMetadata: String

    public let shippingPrice: Float
    public let shippingSubsidy: Float
    public let benefitClass: String
    public let boCampaignId: Int
    public let etaText: String

    public init(
        ratesId: RatesID,
        shipperServiceName: String,
        shipperProductName: String,
        isFreeShipment: Bool,
        hideProduct: Bool = false,
        freeShipmentPromoCode: String,
        freeShipmentBenefitAmount: Price,
        freeShipmentDiscountedPrice: Price,
        freeShipmentImageURL: URL? = nil,
        keroUnixTime: KeroUnixTimeID,
        checksum: String,
        insurancePrice: Price? = nil,
        shipperInsurance: ShipperInsuranceState? = nil,
        orderPriorityPrice: Price,
        price: Price,
        onTimeGuaranteeDelivery: LogisticRatesServiceOnTimeDelivery? = nil,
        cashOnDelivery: LogisticRatesServiceProductCODResponse? = nil,
        merchantVoucherCouponLogoUrl: URL? = nil,
        etaDescription: String? = nil,
        isChangeCourierEnabled: Bool,
        tokoNowBenefitDescription: String? = nil,
        freeShippingMetadata: String,
        shippingPrice: Float,
        shippingSubsidy: Float,
        benefitClass: String,
        boCampaignId: Int,
        etaText: String
    ) {
        self.ratesId = ratesId
        self.shipperServiceName = shipperServiceName
        self.shipperProductName = shipperProductName
        self.isFreeShipment = isFreeShipment
        self.hideProduct = hideProduct
        self.freeShipmentPromoCode = freeShipmentPromoCode
        self.freeShipmentBenefitAmount = freeShipmentBenefitAmount
        self.freeShipmentDiscountedPrice = freeShipmentDiscountedPrice
        self.freeShipmentImageURL = freeShipmentImageURL
        self.keroUnixTime = keroUnixTime
        self.checksum = checksum
        self.insurancePrice = insurancePrice
        self.shipperInsurance = shipperInsurance
        self.orderPriorityPrice = orderPriorityPrice
        self.price = price
        self.onTimeGuaranteeDelivery = onTimeGuaranteeDelivery
        self.cashOnDelivery = cashOnDelivery
        self.merchantVoucherCouponLogoUrl = merchantVoucherCouponLogoUrl
        self.etaDescription = etaDescription
        self.isChangeCourierEnabled = isChangeCourierEnabled
        self.tokoNowBenefitDescription = tokoNowBenefitDescription
        self.freeShippingMetadata = freeShippingMetadata
        self.shippingPrice = shippingPrice
        self.shippingSubsidy = shippingSubsidy
        self.benefitClass = benefitClass
        self.boCampaignId = boCampaignId
        self.etaText = etaText
    }
}

public struct ShipperInsuranceState: Equatable {
    public let insurancePrice: Price
    public var insuranceType: ShipperInsuranceType
    public let insuranceDetailedInfo: String

    public var isSelected: Bool = false

    public init(
        insurancePrice: Price,
        insuranceType: ShipperInsuranceType,
        insuranceDetailedInfo: String,
        isSelected: Bool = false
    ) {
        self.insurancePrice = insurancePrice
        self.insuranceType = insuranceType
        self.insuranceDetailedInfo = insuranceDetailedInfo
        self.isSelected = isSelected
    }
}

public enum ShipperInsuranceAction: Equatable {
    case didTap
    case showDetail
}

public enum ShipperInsuranceType: Equatable {
    case optional
    case required
    case notAvailable

//    public init(fromScheduledDelivery type: InsuranceResponse.InsuranceType) {
//        switch type {
//        case .optional:
//            self = .optional
//        case .mustInsurance:
//            self = .required
//        case .noInsurance:
//            self = .notAvailable
//        }
//    }

    public init(fromRates type: LogisticRatesServiceProductInsuranceTypeResponse) {
        switch type {
        case .optional:
            self = .optional
        case .required:
            self = .required
        case .notSupported:
            self = .notAvailable
        }
    }
}

public struct PinPointAddressDetailDataParams: Equatable {
    public let addressId: Int
    public let addressName: String
    public let addressStreetName: String
    public let addressReceiverName: String
    public let addressReceiverPhone: String
    public let addressPostalCode: String
    public let addressDistrictId: Int
    public let addressDistrictName: String
    public let addressProvinceId: String
    public let addressProvinceName: String
    public let addressCityId: String
    public let addressCityName: String
    public let isPrimary: Bool

    public init(addressId: Int,
                addressName: String,
                addressStreetName: String,
                addressReceiverName: String,
                addressReceiverPhone: String,
                addressPostalCode: String,
                addressDistrictId: Int,
                addressDistrictName: String,
                addressProvinceId: String,
                addressProvinceName: String,
                addressCityId: String,
                addressCityName: String,
                isPrimary: Bool) {
        self.addressId = addressId
        self.addressName = addressName
        self.addressStreetName = addressStreetName
        self.addressReceiverName = addressReceiverName
        self.addressReceiverPhone = addressReceiverPhone
        self.addressPostalCode = addressPostalCode
        self.addressDistrictId = addressDistrictId
        self.addressDistrictName = addressDistrictName
        self.addressProvinceId = addressProvinceId
        self.addressProvinceName = addressProvinceName
        self.addressCityId = addressCityId
        self.addressCityName = addressCityName
        self.isPrimary = isPrimary
    }
}
public enum WidgetState: Equatable {
    case loading
    case now(ShipperDetailViewData) // TokoNow shipment
    case error
}

public struct ScheduledDeliveryShipperState: Equatable {
    public let requestParams: ShipmentRequestType
    public var widgetState: WidgetState = .loading
    public let widgetExperience: ShippingWidgetExperience
    public var noticeData: ScheduledDeliveryPickerContentState.Notice?
    public var services: [ScheduledDeliveryServiceState] = []
    public var selectedShipment: ScheduledDeliveryShipment? {
        didSet {
            updateMinimumFreeShipmentAndInsurance()
        }
    }

    public var orderShipperId: ShipmentID
    public var orderShipperProductId: ShipmentProductID
    public var validationMetadata: String
    public let isUsingShopGroupInsurance: Bool

    @NeverEqual
    internal var minFreeShipment: String?
    public var shipperInsurance: ShipperInsuranceState?

    internal let isRecommend: Bool?

    private mutating func updateMinimumFreeShipmentAndInsurance() {
        guard let selectedShipment = selectedShipment, widgetExperience == .checkoutRevamp else {
            minFreeShipment = nil
            shipperInsurance = nil
            return
        }

        minFreeShipment = selectedShipment.promoText

        guard selectedShipment.insurance.insuranceType != .noInsurance else {
            shipperInsurance = nil
            return
        }

        let insurance = selectedShipment.insurance
        let isSelected: Bool = {
            switch insurance.insuranceType {
            case .mustInsurance:
                return true
            case .optional:
                return insurance.insuranceUsedType == .logisticInsurance ? true : isUsingShopGroupInsurance
            case .noInsurance:
                return false
            }
        }()

        shipperInsurance = ShipperInsuranceState(
            insurancePrice: Price(Int64(insurance.insurancePrice)), // Converts to Int64 because `Price` expects Int64
            insuranceType: ShipperInsuranceType(fromScheduledDelivery: insurance.insuranceType),
            insuranceDetailedInfo: insurance.insuranceUsedInfo,
            isSelected: isSelected
        )
    }

    public init(
        requestParams: ShipmentRequestType,
        widgetState: WidgetState = .loading,
        widgetExperience: ShippingWidgetExperience,
        noticeData: ScheduledDeliveryPickerContentState.Notice? = nil,
        services: [ScheduledDeliveryServiceState] = [],
        selectedShipment: ScheduledDeliveryShipment? = nil,
        orderShipperId: ShipmentID,
        orderShipperProductId: ShipmentProductID,
        validationMetadata: String,
        isUsingShopGroupInsurance: Bool = false,
        isRecommend: Bool? = false
    ) {
        self.requestParams = requestParams
        self.widgetState = widgetState
        self.widgetExperience = widgetExperience
        self.noticeData = noticeData
        self.services = services
        self.selectedShipment = selectedShipment
        self.orderShipperId = orderShipperId
        self.orderShipperProductId = orderShipperProductId
        self.validationMetadata = validationMetadata
        self.isUsingShopGroupInsurance = isUsingShopGroupInsurance
        self.isRecommend = isRecommend
    }
}

internal struct DropshipperDetailState {
    internal var isToggledOn: Bool = false
    internal var name: String = ""
    internal var nameError: String?
    internal var phoneNumber: String = ""
    internal var phoneNumberError: String?

    internal init(isToggledOn: Bool = false, name: String = "", nameError: String? = nil, phoneNumber: String = "", phoneNumberError: String? = nil) {
        self.isToggledOn = isToggledOn
        self.name = name
        self.nameError = nameError
        self.phoneNumber = phoneNumber
        self.phoneNumberError = phoneNumberError
    }

    internal mutating func validateName() {
        if name.count < 3, name.count > 0 {
            nameError = .errorDropshipperNameTooShort
        } else {
            nameError = nil
        }
    }

    internal mutating func validatePhoneNumber() {
        if phoneNumber.count < 10, phoneNumber.count > 0 {
            phoneNumberError = .errorDropshipperPhoneNumberNotValid
        } else {
            phoneNumberError = nil
        }
    }

    /**
     Call this function, to validate checkout requirement
     */
    internal mutating func validateCheckout() {
        if name.isEmpty {
            nameError = .errorEmptyDropshipperName
        }

        if phoneNumber.isEmpty {
            phoneNumberError = .errorEmptyDropshipperPhoneNumber
        }

        // additional check if not empty
        if nameError == nil {
            validateName()
        }

        if phoneNumberError == nil {
            validatePhoneNumber()
        }
    }
}

extension DropshipperDetailState: Equatable {}

internal struct InsuranceData: Equatable {
    internal var isSelected: Bool
    internal var price: Price
}

internal struct SubtotalState {
    /**
     Flag if current shop group use free shipment.
     if current shop group use free shipment, and shipment price is zero (after substract it with shipment discount)

     then the value of the shipment will not be Rp0, but "Bebas Ongkir"
     */
    internal var useFreeShipment: Bool
    internal var quantity: Int
    internal var bundlingQuantity: Int
    internal var totalProductPrice: Price
    internal var totalBundlingPrice: Price

    internal var totalOfferPrice: Price
    internal var totalPriceBeforeOffer: Price
    /**
     Available when trade in
     */
    internal var totalOldDevicePrice: Price
    internal var finalDeviceModel: String
    internal var finalDiagnosticId: Int
    internal var totalShipment: Price?
    internal var totalFreeShipmentBenefit: Price?
    internal var totalInsurance: Price?
    internal var totalAdditionalFee: Price?
    internal var totalQuantityPurchaseProtection: Int
    internal var totalPurchaseProtectionCost: Price?
    internal var totalPriorityOrderFee: Price?

    // Subtotal data for gifting
    internal var addOnPrice: Price?

    // Subtotal data for `add-ons as a service`
    internal var addOnServiceSubtotalData: [AddonServiceSummaryData]

    internal var subtotal: Price {
        var total = totalProductPrice + totalBundlingPrice

        if let totalShipment = totalShipment {
            let totalShipmentWithDiscount = totalShipment - (totalFreeShipmentBenefit ?? 0)
            let finalTotalShipment = totalShipmentWithDiscount < 0 ? 0 : totalShipmentWithDiscount
            total += finalTotalShipment
        }

        if totalOldDevicePrice != 0 {
            total -= totalOldDevicePrice
        }

        if let totalInsurance = totalInsurance {
            total += totalInsurance
        }

        if let totalAdditionalFee = totalAdditionalFee {
            total += totalAdditionalFee
        }

        if let totalPurchaseProtectionCost = totalPurchaseProtectionCost {
            total += totalPurchaseProtectionCost
        }

        if let totalPriorityOrderFee = totalPriorityOrderFee {
            total += totalPriorityOrderFee
        }

        // Total price for `add-ons as a service`
        if addOnServiceSubtotalData.isNotEmpty {
            total += addOnServiceSubtotalData.map { $0.price }.reduce(0, +)
        }

        // Total price for gifting
        if let addOnPrice = addOnPrice {
            total += addOnPrice
        }

        return total
    }

    internal var details: [TitleDescriptionViewData] {
        var details: [TitleDescriptionViewData] = []

        details.append(
            TitleDescriptionViewData(
                id: "price",
                title: "Harga (\(quantity + bundlingQuantity) barang)",
                description: (totalProductPrice + totalBundlingPrice).currencyDescription
            )
        )

        // Subtotal summary for `add-ons as a service`
        if addOnServiceSubtotalData.isNotEmpty {
            let addOnServiceSubtotal = addOnServiceSubtotalData.map { data -> TitleDescriptionViewData in
                TitleDescriptionViewData(
                    id: "add_ons_service_subtotal_with_type_\(data.type)",
                    title: data.title,
                    description: data.price.currencyDescription
                )
            }

            details.append(contentsOf: addOnServiceSubtotal)
        }

        // Subtotal summary for gifting
        if let addOnPrice = addOnPrice {
            details.append(
                TitleDescriptionViewData(
                    id: "gifting_addon",
                    title: "Pelengkap Hadiah",
                    description: addOnPrice.currencyDescription
                )
            )
        }

        if let totalShipment = totalShipment {
            let finalShipmentPrice = totalShipment - (totalFreeShipmentBenefit ?? 0)
            let isFreeShipment = finalShipmentPrice <= 0
            let description: String

            if useFreeShipment, isFreeShipment {
                description = "Rp0"
            } else {
                description = finalShipmentPrice.currencyDescription
            }

            details.append(
                TitleDescriptionViewData(
                    id: "shipment",
                    title: "Ongkos Kirim",
                    description: description
                )
            )
        }

        if let totalInsurance = totalInsurance, totalInsurance != 0 {
            details.append(
                TitleDescriptionViewData(
                    id: "insurance",
                    title: "Biaya Asuransi Pengiriman",
                    description: totalInsurance.currencyDescription
                )
            )
        }

        if let totalAdditionalFee = totalAdditionalFee, totalAdditionalFee != 0 {
            details.append(
                TitleDescriptionViewData(
                    id: "additional_fee",
                    title: "Biaya Tambahan Penjual",
                    description: totalAdditionalFee.currencyDescription
                )
            )
        }

        if let totalPurchaseProtectionCost = totalPurchaseProtectionCost, totalPurchaseProtectionCost != 0 {
            details.append(
                TitleDescriptionViewData(
                    id: "purchase_protection",
                    title: "Proteksi Produk (\(totalQuantityPurchaseProtection) barang)",
                    description: totalPurchaseProtectionCost.currencyDescription
                )
            )
        }

        if let totalPriorityOrderFee = totalPriorityOrderFee, totalPriorityOrderFee != 0 {
            details.append(
                TitleDescriptionViewData(
                    id: "priority_order_fee",
                    title: "Biaya Order Prioritas",
                    description: totalPriorityOrderFee.currencyDescription
                )
            )
        }

        if totalOldDevicePrice != 0 {
            details.append(
                TitleDescriptionViewData(
                    id: "trade_in",
                    title: "Tukar Tambah",
                    description: "- " + totalOldDevicePrice.currencyDescription
                )
            )
        }

        return details
    }
}

extension SubtotalState: Equatable {}

extension SubtotalState {
    /**
     Init subtotal from current `OrderState`
     Reuse to calculate subtotal on `OrderState`
     */
    internal init(from viewData: OrderState) {
        let validProducts = viewData.validProducts

        useFreeShipment = viewData.shipment?.selectedShipmentData?.isFreeShipment == true || viewData.scheduledDelivery != nil
        quantity = validProducts.map(\.quantity).reduce(0, +)

        totalProductPrice = { () -> Price in
            switch viewData.checkoutMode {
            case .oneClickShipment(.tradeIn):
                return validProducts.reduce(Price()) { $0 + $1.originalPrice * Price($1.quantity) }
            default:
                return validProducts.reduce(Price()) { $0 + $1.price * Price($1.quantity) }
            }
        }()

        totalOldDevicePrice = validProducts.reduce(0) { $0 + $1.oldDevicePrice }
        finalDeviceModel = validProducts.first?.deviceModel ?? ""
        finalDiagnosticId = validProducts.first?.diagnosticId ?? 0

        // Combined value of bundling prices from list of bundlings
        totalBundlingPrice = viewData.shops.map { shop -> Price in
            shop.cartDetailState.map { cartDetailState -> Price in
                Price(cartDetailState.cartDetails.bundleDetail.bundlePrice * cartDetailState.cartDetails.bundleDetail.bundleQty)
            }.reduce(0, +)
        }.reduce(0, +)

        // Combined Value of Offer prices from list of offer products before offer
        totalPriceBeforeOffer = viewData.shops.map { shop -> Price in
            shop.cartDetailState.map { cartDetailState -> Price in
                cartDetailState.validProducts.reduce(Price()) { $0 + $1.price * Price($1.quantity) }
            }.reduce(0, +)
        }.reduce(0, +)

        // Offer Price
        totalOfferPrice = viewData.shops.map { shop -> Price in
            shop.cartDetailState.map { cartDetailState -> Price in
                guard case let .BMGM(offer) = cartDetailState.cartDetails.cartDetailInfo.cartDetailType else { return Price(0) }
                return Price(offer.totalDiscount)
            }.reduce(0, +)
        }.reduce(0, +)

        // Get count off all product in bundling including quantity per product
        bundlingQuantity = viewData.shops.map { shop -> Int in
            shop.cartDetailState.map { cartDetailState -> Int in
                cartDetailState.productState.map { productState -> Int in
                    guard productState.errors.isEmpty else { return 0 }
                    return productState.quantity
                }.reduce(0, +)
            }.reduce(0, +)
        }.reduce(0, +)

        if validProducts.isNotEmpty || viewData.shops.contains(where: { $0.hasBundling }) {
            var selectedShipmentDataPrice: Price?
            var shipperId: ShipmentID = .invalid
            var shipperProductId: ShipmentProductID = .invalid

            if let shipment = viewData.shipment {
                selectedShipmentDataPrice = shipment.selectedShipmentData?.price
                shipperId = shipment.shipperId
                shipperProductId = shipment.shipperProductId
            }

            if let scheduledShipment = viewData.scheduledDelivery?.selectedShipment {
                selectedShipmentDataPrice = Price(scheduledShipment.realPrice)
                shipperId = scheduledShipment.shipperId
                shipperProductId = scheduledShipment.shipperProductId
            }

            totalShipment = selectedShipmentDataPrice

            // clamp benefit, so benefit will not over shipment value, to help calculate summary value
            totalFreeShipmentBenefit = {
                if let totalShipment = selectedShipmentDataPrice, totalShipment > 0 {
                    var benefitAmount: Price?

                    if let shipment = viewData.shipment {
                        benefitAmount = shipment.selectedShipmentData?.freeShipmentBenefitAmount
                    }

                    if let scheduledShipment = viewData.scheduledDelivery?.selectedShipment {
                        benefitAmount = Price(scheduledShipment.benefitAmount)
                    }

                    return benefitAmount?.clamp(0 ... totalShipment)
                } else {
                    return nil
                }
            }()

            // We will check which insurance state is available in the following order:
            // 1. Normal order (Checkout Revamp)
            // 2. Scheduled Delivery/NOW! (Checkout Revamp)
            // 3. Normal order (old experience)
            if let ratesInsurance = viewData.shipment?.selectedShipmentData?.shipperInsurance {
                totalInsurance = ratesInsurance.isSelected ? ratesInsurance.insurancePrice : nil
            } else if let scheduledDeliveryInsurance = viewData.scheduledDelivery?.shipperInsurance {
                totalInsurance = scheduledDeliveryInsurance.isSelected ? scheduledDeliveryInsurance.insurancePrice : nil
            } else {
                totalInsurance = viewData.insurance?.isSelected == true ? viewData.insurance?.price : nil
            }

            totalPriorityOrderFee = viewData.isOrderPriority ? (viewData.shipment?.selectedShipmentData?.orderPriorityPrice ?? 0) : 0

            totalAdditionalFee = { () -> Price in
                let selectedShopShipment = viewData.availableShopShipments.first(where: { $0.id == shipperId })
                let selectedProduct = selectedShopShipment?.shipperProducts.first(where: { $0.id == shipperProductId })

                return selectedProduct?.additionalFee ?? 0
            }()

            let purchaseProtectionProducts: [ProductState] = {
                let regularProducts = validProducts
                    .filter { $0.purchaseProtection?.isSelected == true }

                let bundlingProducts = viewData.shops
                    .flatMap { shop -> [ProductState] in
                        shop.cartDetailState.flatMap { cartDetail -> [ProductState] in
                            cartDetail.productState.filter { $0.purchaseProtection?.isSelected == true }
                        }
                    }

                return regularProducts + bundlingProducts
            }()

            // total selected purchase protection
            totalQuantityPurchaseProtection = purchaseProtectionProducts.reduce(0) { $0 + $1.quantity }

            // no need to multiply protection price by qty because BE already give the total protection price
            totalPurchaseProtectionCost = purchaseProtectionProducts.reduce(
                Price(), { $0 + ($1.purchaseProtection?.protectionPrice ?? Price()) }
            )

            if totalPurchaseProtectionCost == 0 {
                totalPurchaseProtectionCost = nil
            }
        } else {
            totalShipment = nil
            totalFreeShipmentBenefit = nil
            totalInsurance = nil
            totalPriorityOrderFee = 0
            totalAdditionalFee = nil
            totalQuantityPurchaseProtection = 0
            totalPurchaseProtectionCost = 0
        }

        addOnPrice = {
            var addOnPrices: [Int] = []

            if viewData.addOnState.addOn.isEnabledButton == true {
                addOnPrices += viewData.addOnState.addOn.addOnDetailData.map { addOnDetail in
                    addOnDetail.addOnPrice
                }
            }

            for productState in validProducts where productState.addOnState.addOn.isEnabledButton == true {
                addOnPrices += productState.addOnState.addOn.addOnDetailData.map { addOnDetail -> Int in
                    addOnDetail.addOnPrice
                }
            }

            guard addOnPrices.isNotEmpty else { return nil }

            return Price(addOnPrices.reduce(0, +))
        }()

        addOnServiceSubtotalData = {
            guard viewData.safAddOnServiceSubtotalSummary.isNotEmpty,
                viewData.enabledValidProducts.isNotEmpty
            else { return [] }

            /**
             Iterate through subtotal summary data from BE
             */
            let subtotalSummaryData: [AddonServiceSummaryData] = viewData.safAddOnServiceSubtotalSummary.map { subtotalSummary -> AddonServiceSummaryData? in
                var totalPrice: Price = 0
                var totalQuantity = 0

                /**
                 Iterate through enabled & valid products that supports `add-ons as a service`
                 */
                viewData.enabledValidProducts.filter { $0.addOnPickerData != nil }.map { product in
                    /**
                     Get product quantity
                     */
                    let productQuantity = product.quantity

                    /**
                     1. Get products that have add-ons
                     2. Get first selected/mandatory add-on details that have matching `type` with current subtotal summary
                     */
                    guard let validAddOnDetails = product.addOnPickerData?.details,
                        let selectedAddOnDetail = validAddOnDetails.first(where: { ($0.status == .selected || $0.status == .mandatory) && ($0.type == subtotalSummary.type) })
                    else { return }

                    /**
                     Price & quantity from each products are multiplied by:
                     1. 1 if `fixedQuantity == true`
                     2. Each product quantity if `fixedQuantity == false`
                     */
                    totalPrice += Price(Int(selectedAddOnDetail.price.rawValue) * (selectedAddOnDetail.fixedQuantity ? 1 : productQuantity))
                    totalQuantity += selectedAddOnDetail.fixedQuantity ? 1 : productQuantity
                }

                /**
                 Quantity has to be > 0 to indicate that this order have selected add-ons
                 */
                guard totalQuantity > 0 else { return nil }

                /**
                 Replace "{{qty}}" from BE with quantity
                 */
                let title = subtotalSummary.title.replacingOccurrences(of: "{{qty}}", with: "\(totalQuantity)")

                return AddonServiceSummaryData(
                    title: title,
                    price: totalPrice,
                    quantity: totalQuantity,
                    type: subtotalSummary.type
                )
            }
            .compactMap { $0 }
            .sorted { $0.type < $1.type } // Data should be displayed sorted by it's `type`

            return subtotalSummaryData
        }()
    }
}

internal struct AddOnState: Equatable {
    internal var addOn: AddOn
}

internal struct ShopState: Identifiable, Equatable {
    internal var id: CartShopID

    internal var shopId: ShipmentShopID
    internal let shopType: ShopType
    internal var shopName: String
    internal let shopBadgeURL: URL?
    internal let shopDistrictId: Int
    internal let shopPostalCode: String
    internal let shopLatitude: String
    internal let shopLongitude: String
    internal let isTokonow: Bool

    internal let uiGroupType: UIGroupType

    internal var products: [ProductState]

    internal var cartDetailState: [CartDetailState]

    internal var shopTier: Int

    /**
     Promo provided by merchant
     */
    internal var merchantCodes: [PromoCode]

    internal var countProductsInBundlings: Int {
        cartDetailState.map { $0.productState.count }.reduce(0) { x, y in
            x + y
        }
    }

    internal var totalProductAndBundlingCount: Int {
        products.count + countProductsInBundlings
    }

    internal var allProductIsDisabled: Bool {
        products.allSatisfy { !$0.isEnabled && !$0.isErrorInvalidShipment }
    }

    internal var anyProductUsePurchaseProtection: Bool {
        products.contains(where: { $0.purchaseProtection?.isSelected == true })
    }

    internal var anyProductUseAddOn: Bool {
        products.contains(where: {
            $0.addOnPickerData?.details.contains(where: { $0.status == .selected || $0.status == .mandatory }) == true
        })
    }

    internal var hasBundling: Bool {
        cartDetailState.isNotEmpty
    }

    internal var allBundlingIsDisabled: Bool {
        cartDetailState.allSatisfy { !$0.isEnabled }
    }

    internal var anyBundlingUsePurchaseProtection: Bool {
        cartDetailState.contains(where: {
            $0.productState.contains(where: { $0.purchaseProtection?.isSelected == true })
        })
    }

    internal var anyBundlingUseAddOn: Bool {
        cartDetailState.contains(where: {
            $0.productState.contains(where: {
                $0.addOnPickerData?.details.contains(where: { $0.status == .selected || $0.status == .mandatory }) == true
            })
        })
    }

    internal var prescriptionRejectedProductCount: Int {
        products.filter { !$0.isPrescriptionAccepted }.count
    }

    internal var anyProductUseEpharmConsul: Bool {
        products.contains(where: { $0.epharmacyGroupId != nil })
    }

    internal var allProductEpharmGroupId: String {
        products.compactMap { $0.epharmacyGroupId?.rawValue }.joined(separator: ",")
    }

    internal var shopNeedPrescription: Bool {
        products.contains { $0.ethicalDrug?.isNeedPrescription == true }
    }

    internal var productNeedPrescriptionCount: Int {
        products.filter { $0.ethicalDrug?.isNeedPrescription == true }.count
    }

    internal var bundlingProducts: [CartDetailState] {
        cartDetailState.filter { $0.cartDetails.isProductBundling }
    }

    internal var offerProducts: [CartDetailState] {
        cartDetailState.filter { $0.cartDetails.isOfferProduct }
    }
}

public enum ShipmentRequestType: Equatable {
    case scheduledDeliveryWithRates(ScheduledDeliveryParams)
    case scheduledDelivery(ScheduledDeliveryRatesRequest)

    fileprivate var shouldShowRadioButton: Bool {
        switch self {
        case .scheduledDeliveryWithRates: return true
        case .scheduledDelivery: return false
        }
    }
}
public struct ScheduledDeliveryParams: Equatable {
    public let scheduledDeliveryParams: ScheduledDeliveryRatesRequest
    public let logisticRatesParams: LogisticRatesParams
    public let ratesMetadata: RatesMetadata

    /// - Parameters:
    ///   - scheduledDeliveryParams: Request parameters for fetching scheduled delivery data.
    ///   - logisticRatesParams: Request parameters for fetching rates-related data.
    ///   - ratesMetadata: Rates metadata containing cartData string,
    public init(
        scheduledDeliveryParams: ScheduledDeliveryRatesRequest,
        logisticRatesParams: LogisticRatesParams,
        ratesMetadata: RatesMetadata
    ) {
        self.scheduledDeliveryParams = scheduledDeliveryParams
        self.logisticRatesParams = logisticRatesParams
        self.ratesMetadata = ratesMetadata
    }
}

public struct ScheduledDeliveryRatesRequest: Equatable {
    public struct LocationData: Equatable {
        public let districtId: DistrictID
        public let postalCode: Int?
        public let geoloc: String?

        public init(districtId: DistrictID, postalCode: Int? = nil, geoloc: String? = nil) {
            self.districtId = districtId
            self.postalCode = postalCode
            self.geoloc = geoloc
        }
    }

    public let origin: LocationData
    public let destination: LocationData
    public let spids: String?
    public let warehouseId: ShipmentWarehouseID
    public let catId: String?
    public let products: String?
    public let boMetadata: String?
    public let weight: String
    public let actualWeight: String?
    public let type: String?
    public let userHistory: Int?
    public let uniqueId: String?
    public let poTime: Int?
    public let shopId: ShipmentShopID?
    public let isFulfillment: Bool?
    public let shopTier: Int?
    public let timeSlotId: Int?
    public let scheduleDate: String?
    public let source: String?
    public let orderValue: Int?
    public let cartData: String?
    public let insurance: Int?
    public let productInsurance: Int?
    public let groupingState: GroupingState?
    public let startDate: String?

    public init(
        origin: ScheduledDeliveryRatesRequest.LocationData,
        destination: ScheduledDeliveryRatesRequest.LocationData,
        spids: String? = nil,
        warehouseId: ShipmentWarehouseID,
        catId: String? = nil,
        products: String? = nil,
        boMetadata: String? = nil,
        weight: String,
        actualWeight: String? = nil,
        type: String? = nil,
        userHistory: Int? = nil,
        uniqueId: String? = nil,
        poTime: Int? = nil,
        shopId: ShipmentShopID? = nil,
        isFulfillment: Bool? = nil,
        shopTier: Int? = nil,
        timeSlotId: Int? = nil,
        scheduleDate: String? = nil,
        source: String? = nil,
        orderValue: Int? = nil,
        cartData: String? = nil,
        insurance: Int? = nil,
        productInsurance: Int? = nil,
        groupingState: GroupingState? = .normal,
        startDate: String? = ""
    ) {
        self.origin = origin
        self.destination = destination
        self.spids = spids
        self.warehouseId = warehouseId
        self.catId = catId
        self.products = products
        self.boMetadata = boMetadata
        self.weight = weight
        self.actualWeight = actualWeight
        self.type = type
        self.userHistory = userHistory
        self.uniqueId = uniqueId
        self.poTime = poTime
        self.shopId = shopId
        self.isFulfillment = isFulfillment
        self.shopTier = shopTier
        self.timeSlotId = timeSlotId
        self.scheduleDate = scheduleDate
        self.source = source
        self.orderValue = orderValue
        self.cartData = cartData
        self.insurance = insurance
        self.productInsurance = productInsurance
        self.groupingState = groupingState
        self.startDate = startDate
    }
}

extension ScheduledDeliveryRatesRequest.LocationData {
    internal func toFormattedString() -> String {
        guard let postalCode = postalCode, let geoloc = geoloc else { return "" }
        return "\(districtId.rawValue)" + "|" + "\(postalCode)" + "|" + geoloc
    }
}

internal struct PurchaseProtectionCheckboxViewData {
    internal let protectionPrice: Price
    internal let protectionPricePerProduct: Price

    internal var title: String
    internal var subtitle: String
    internal var isEnabled: Bool
    internal var isSelected: Bool
    internal var learnMoreURL: URL?

    internal var accessibilityLabel: String {
        let accessibilityLabel: String

        if isSelected {
            accessibilityLabel = "Nonaktifkan \(title). \(subtitle)"
        } else {
            accessibilityLabel = "Centang untuk \(title). \(subtitle)"
        }

        return accessibilityLabel
    }
}

extension PurchaseProtectionCheckboxViewData: Equatable {}

extension PurchaseProtectionCheckboxViewData {
    // kinda convenience init
    internal init() {
        self.init(
            protectionPrice: 0,
            protectionPricePerProduct: 0,
            title: "",
            subtitle: "",
            isEnabled: false,
            isSelected: false,
            learnMoreURL: nil
        )
    }
}

public enum AddonPageSource: Equatable {
    case pdp
    case cart(level: AddonLevel)
    case checkout(level: AddonLevel, isOCS: Bool)
    case occ(level: AddonLevel)

    public var addonLevel: AddonLevel {
        // Currently hardcoded to product level only, as expected by BE
        switch self {
        case .pdp, .cart, .checkout, .occ:
            return .product
        }
    }

    public var source: String {
        switch self {
        case .pdp:
            return "pdp_platform_post_atc"
        default:
            return "ios"
        }
    }
}

public enum AddonLevel: String {
    case product
    case order

    public var rawValue: String {
        switch self {
        case .product:
            return "PRODUCT_ADDON"
        case .order:
            return "ORDER_ADDON"
        }
    }
}

internal struct SaveAddOnCartProduct: Encodable, Equatable {
    internal var cartID: Int
    internal var productID: Int
    internal var warehouseID: Int
    internal var productName: String
    internal var productImageURL: String
    internal var productParentID: Int

    internal enum CodingKeys: String, CodingKey {
        case cartID = "cart_id"
        case productID = "product_id"
        case warehouseID = "warehouse_id"
        case productName = "product_name"
        case productImageURL = "product_image_url"
        case productParentID = "product_parent_id"
    }
}

public enum ShippingWidgetExperience: Equatable {
    case `default`
    case checkoutRevamp
}

public struct ShipperPickerParams: Equatable {
    public let userAddress: Address
    public var shipperId: ShipmentID
    public var shipperProductId: ShipmentProductID
    public var isFreeShipment: Bool
    public let metadata: RatesMetadata
    public var isTradeIn: Bool
    /// mode to determine which data will be show from picker
    public let mode: ShipperPickerMode
    /// params generated based on that rows data
    public let requestParams: LogisticRatesParams

    public init(
        userAddress: Address,
        shipperId: ShipmentID,
        shipperProductId: ShipmentProductID,
        isFreeShipment: Bool,
        isTradeIn: Bool,
        mode: ShipperPickerMode,
        requestParams: LogisticRatesParams,
        metadata: RatesMetadata
    ) {
        self.userAddress = userAddress
        self.shipperId = shipperId
        self.shipperProductId = shipperProductId
        self.isFreeShipment = isFreeShipment
        self.metadata = metadata
        self.isTradeIn = isTradeIn
        self.mode = mode
        self.requestParams = requestParams
    }
}

public enum ShipperPickerMode: Equatable {
    case duration
    case courier

    public var viewControllerTitle: String {
        switch self {
        case .duration:
            return "Metode Pengiriman"
        case .courier:
            return "Kurir"
        }
    }
}

public struct Address: Equatable {
    public let id: AddressID
    public let title: String
    public let receiverName: String
    public let phoneNumber: String
    public let detail: String
    public let isPrimary: Bool // If true, "status" should equal 2
    public let districtId: Int
    public let districtName: String
    public let postalCode: String
    public let latitude: String
    public let longitude: String
    public let provinceId: Int
    public let provinceName: String
    public let cityId: Int
    public let cityName: String
    public let stateCode: Int
    public let stateDetail: String
    public var disabled: Bool
    public let status: Int // 0: inactive, 1: active, 2: primary
    public let tokonowAddressData: LocalizedAddress.TokoNow

    public var getReceiverNameIfActiveAddress: String {
        guard status == 1 else { return "" }
        return receiverName
    }

    public init(id: AddressID, title: String, receiverName: String, phoneNumber: String, detail: String, isPrimary: Bool, districtId: Int, districtName: String, postalCode: String, latitude: String, longitude: String, provinceId: Int, provinceName: String, cityId: Int, cityName: String, stateCode: Int, stateDetail: String, disabled: Bool, status: Int, tokonowAddressData: LocalizedAddress.TokoNow) {
        self.id = id
        self.title = title
        self.receiverName = receiverName
        self.phoneNumber = phoneNumber
        self.detail = detail
        self.isPrimary = isPrimary
        self.districtId = districtId
        self.districtName = districtName
        self.postalCode = postalCode
        self.latitude = latitude
        self.longitude = longitude
        self.provinceId = provinceId
        self.provinceName = provinceName
        self.cityId = cityId
        self.cityName = cityName
        self.stateCode = stateCode
        self.stateDetail = stateDetail
        self.disabled = disabled
        self.status = status
        self.tokonowAddressData = tokonowAddressData
    }
}

public struct ScheduledDeliveryPickerContentState: Equatable {
    public struct Notice: Equatable {
        public let imageUrl: URL
        public let title: String
        public let description: String

        public init(title: String, description: String) {
            imageUrl = URL(string: "https://images.tokopedia.net/img/now/schedule-delivery/schedule-bottomsheet-info-icon.png")! // urlString is explicitly hardcoded.
            self.title = title
            self.description = description
        }
    }

    public var additionalScheduleDeliveryDescription: String?
    public var notice: Notice?

    public var services: IdentifiedArrayOf<ScheduledDeliveryServiceState> = []

    public var products: IdentifiedArrayOf<ScheduledDeliveryProductState> = []

    public var selectedShipment: ScheduledDeliveryShipment?

    public init(
        additionalScheduleDeliveryDescription: String? = nil,
        notice: ScheduledDeliveryPickerContentState.Notice? = nil,
        services: IdentifiedArrayOf<ScheduledDeliveryServiceState>,
        products: IdentifiedArrayOf<ScheduledDeliveryProductState>,
        selectedShipment: ScheduledDeliveryShipment? = nil
    ) {
        self.additionalScheduleDeliveryDescription = additionalScheduleDeliveryDescription
        self.notice = notice
        self.services = services
        self.products = products
        self.selectedShipment = selectedShipment
    }
}

public struct ScheduledDeliveryServiceState: Equatable, Identifiable, Selectable {
    public typealias ID = String
    public let id: ID
    public let title: String
    public let dateString: String
    public var isSelected: Bool
    public let isAvailable: Bool

    public var products: IdentifiedArrayOf<ScheduledDeliveryProductState> = []

    public init(
        id: ScheduledDeliveryServiceState.ID,
        title: String,
        dateString: String,
        isSelected: Bool,
        isAvailable: Bool,
        products: IdentifiedArrayOf<ScheduledDeliveryProductState>
    ) {
        self.id = id
        self.title = title
        self.dateString = dateString
        self.isSelected = isSelected
        self.isAvailable = isAvailable
        self.products = products
    }
}

public struct ScheduledDeliveryProductState: Equatable, Identifiable {
    public enum DividerStyle: Equatable {
        case cell
        case section
    }

    public typealias ID = Int
    public let id: ID
    public let title: String
    public let validationMetadata: String
    public let finalPrice: Int
    public let realPrice: Int
    public let textFinalPrice: String
    public let textRealPrice: String
    public let insurance: InsuranceResponse
    public let titlePrefix: String
    public let textEta: String

    public var promoText: String?

    public var remainingSlot: String?

    public var isSelected: Bool
    public let isAvailable: Bool
    public var dividerStyle: DividerStyle
    public var showUnavailableProductSection: Bool

    public var shipperId: ShipmentID
    public var shipperProductId: ShipmentProductID
    public var promoCode: String
    public var freeShippingMetadata: String
    public var shippingSubsidy: Float
    public var benefitClass: String
    public var boCampaignId: Int
    public var onTimeDelivery: OntimeDeliveryGuaranteeResponse
    public var keroUnixTime: String
    public var checksum: String
    public var ratesId: RatesID
    public var benefitAmount: Int

    public init(
        id: ScheduledDeliveryProductState.ID,
        title: String,
        validationMetadata: String,
        finalPrice: Int,
        realPrice: Int,
        textFinalPrice: String,
        textRealPrice: String,
        insurance: InsuranceResponse,
        titlePrefix: String,
        textEta: String,
        promoText: String? = nil,
        remainingSlot: String? = nil,
        isSelected: Bool,
        isAvailable: Bool,
        dividerStyle: ScheduledDeliveryProductState.DividerStyle,
        showUnavailableProductSection: Bool,
        shipperId: ShipmentID,
        shipperProductId: ShipmentProductID,
        promoCode: String,
        freeShippingMetadata: String,
        shippingSubsidy: Float,
        benefitClass: String,
        boCampaignId: Int,
        onTimeDelivery: OntimeDeliveryGuaranteeResponse,
        keroUnixTime: String,
        checksum: String,
        ratesId: RatesID,
        benefitAmount: Int
    ) {
        self.id = id
        self.title = title
        self.validationMetadata = validationMetadata
        self.finalPrice = finalPrice
        self.realPrice = realPrice
        self.textFinalPrice = textFinalPrice
        self.textRealPrice = textRealPrice
        self.insurance = insurance
        self.titlePrefix = titlePrefix
        self.textEta = textEta
        self.promoText = promoText
        self.remainingSlot = remainingSlot
        self.isSelected = isSelected
        self.isAvailable = isAvailable
        self.dividerStyle = dividerStyle
        self.showUnavailableProductSection = showUnavailableProductSection
        self.shipperId = shipperId
        self.shipperProductId = shipperProductId
        self.promoCode = promoCode
        self.freeShippingMetadata = freeShippingMetadata
        self.shippingSubsidy = shippingSubsidy
        self.benefitClass = benefitClass
        self.boCampaignId = boCampaignId
        self.onTimeDelivery = onTimeDelivery
        self.keroUnixTime = keroUnixTime
        self.checksum = checksum
        self.ratesId = ratesId
        self.benefitAmount = benefitAmount
    }
}

public struct ScheduledDeliveryShipment: Equatable {
    public var validationMetadata: String?
    public var finalPrice: Int
    public var realPrice: Int
    public var textFinalPrice: String
    public var textRealPrice: String
    public var title: String

    public var textEta: String?

    public var promoText: String?

    public var insurance: InsuranceResponse
    public var serviceId: String
    public var productId: Int

    // Courier data
    public var shipperId: ShipmentID
    public var shipperProductId: ShipmentProductID
    public var promoCode: String?
    public var freeShippingMetadata: String
    public var shippingSubsidy: Float
    public var benefitClass: String
    public var boCampaignId: Int
    public var onTimeDelivery: OntimeDeliveryGuaranteeResponse
    public var keroUnixTime: String
    public var checksum: String
    public var ratesId: RatesID
    public var benefitAmount: Int

    public var resetPreviousShipment: Bool = false

    public init(
        validationMetadata: String?,
        finalPrice: Int,
        realPrice: Int,
        textFinalPrice: String,
        textRealPrice: String,
        title: String,
        textEta: String?,
        promoText: String?,
        insurance: InsuranceResponse,
        serviceId: String,
        productId: Int,
        shipperId: ShipmentID,
        shipperProductId: ShipmentProductID,
        promoCode: String?,
        freeShippingMetadata: String,
        shippingSubsidy: Float,
        benefitClass: String,
        boCampaignId: Int,
        onTimeDelivery: OntimeDeliveryGuaranteeResponse,
        keroUnixTime: String,
        checksum: String,
        ratesId: RatesID,
        benefitAmount: Int
    ) {
        self.validationMetadata = validationMetadata
        self.finalPrice = finalPrice
        self.realPrice = realPrice
        self.textFinalPrice = textFinalPrice
        self.textRealPrice = textRealPrice
        self.title = title
        self.textEta = textEta
        self.promoText = promoText
        self.insurance = insurance
        self.serviceId = serviceId
        self.productId = productId
        self.shipperId = shipperId
        self.shipperProductId = shipperProductId
        self.promoCode = promoCode
        self.freeShippingMetadata = freeShippingMetadata
        self.shippingSubsidy = shippingSubsidy
        self.benefitClass = benefitClass
        self.boCampaignId = boCampaignId
        self.onTimeDelivery = onTimeDelivery
        self.keroUnixTime = keroUnixTime
        self.checksum = checksum
        self.ratesId = ratesId
        self.benefitAmount = benefitAmount
    }
}

extension ScheduledDeliveryShipment {
    public static let empty = Self(
        validationMetadata: nil,
        finalPrice: 0,
        realPrice: 0,
        textFinalPrice: "",
        textRealPrice: "",
        title: "",
        textEta: "",
        promoText: "",
        insurance: .noInsurance,
        serviceId: "",
        productId: 0,
        shipperId: 0,
        shipperProductId: 0,
        promoCode: "",
        freeShippingMetadata: "",
        shippingSubsidy: 0,
        benefitClass: "",
        boCampaignId: 0,
        onTimeDelivery: OntimeDeliveryGuaranteeResponse(available: false, value: 0, textLabel: "", textDetail: "", urlDetail: "", iconUrl: ""),
        keroUnixTime: "",
        checksum: "",
        ratesId: "",
        benefitAmount: 0
    )

    public init(
        ratesResponse: LogisticRatesResponse,
        shipperId: ShipmentID,
        shipperProductId: ShipmentProductID
    ) {
        var selectedService: LogisticRatesServiceResponse? = ratesResponse.services.first(where: { $0.error == nil })
        var selectedProduct: LogisticRatesServiceProductResponse? = selectedService?.products.first(where: { $0.error == nil })

        if shipperId.rawValue != 0, shipperProductId.rawValue != 0 {
            for service in ratesResponse.services {
                for product in service.products where product.id == shipperProductId && product.shipperId == shipperId {
                    selectedService = service
                    selectedProduct = product
                }
            }
        }

        if let selectedService = selectedService, let selectedProduct = selectedProduct {
            var finalPrice = selectedProduct.price
            let realPrice = selectedProduct.price
            var title = "<b>\(selectedProduct.name) (\(realPrice.currencyDescription))</b>"
            var textEta = selectedProduct.eta.description
            var promoText: String?
            var promoCode: String?
            var freeShippingMetadata = ""
            var shippingSubsidy = 0
            var benefitClass = ""
            var boCampaignId = 0
            var benefitAmount = 0

            if let promoStacking = ratesResponse.promoStackings.first(where: { $0.shipperId == selectedProduct.shipperId && $0.shipperProductId == selectedProduct.id }) {
                promoText = promoStacking.benefitDecription

                if promoStacking.isDisabled == false, promoStacking.isPromo {
                    finalPrice = promoStacking.discountRate
                    title = promoStacking.text.chosenCourier
                    textEta = promoStacking.eta.description
                    promoCode = promoStacking.promoCode
                    freeShippingMetadata = (try? promoStacking.freeShippingMetadata.jsonString()) ?? ""
                    shippingSubsidy = promoStacking.freeShippingMetadata.shippingSubsidy
                    benefitClass = promoStacking.freeShippingMetadata.benefitClass
                    boCampaignId = promoStacking.boCampaignId
                    benefitAmount = Int(promoStacking.totalBenefit.rawValue)
                }
            }

            var onTimeDelivery = OntimeDeliveryGuaranteeResponse(available: false, value: 0, textLabel: "", textDetail: "", urlDetail: "", iconUrl: "")
            if let onTimeDeliveryGuarantee = selectedProduct.onTimeDeliveryGuarantee {
                onTimeDelivery = OntimeDeliveryGuaranteeResponse(
                    available: true,
                    value: onTimeDeliveryGuarantee.amount,
                    textLabel: onTimeDeliveryGuarantee.text,
                    textDetail: "",
                    urlDetail: onTimeDeliveryGuarantee.detailURL?.absoluteString ?? "",
                    iconUrl: onTimeDeliveryGuarantee.iconURL?.absoluteString ?? ""
                )
            }

            let insuranceType: InsuranceResponse.InsuranceType = {
                switch selectedProduct.insurance.type {
                case .required:
                    return .mustInsurance
                case let .optional(isSelected):
                    return .optional
                case .notSupported:
                    return .noInsurance
                }

            }()

            let insurance = InsuranceResponse(
                insuranceType: insuranceType,
                insurancePrice: selectedProduct.insurance.price,
                insuranceTypeInfo: "", // Not used
                insuranceUsedType: selectedProduct.insurance.usedType ? .logisticInsurance : .noInsurance,
                insuranceUsedInfo: selectedProduct.insurance.info,
                insuranceUsedDefault: false // Not used
            )

            self.init(
                validationMetadata: nil,
                finalPrice: Int(finalPrice.rawValue),
                realPrice: Int(realPrice.rawValue),
                textFinalPrice: finalPrice.currencyDescription,
                textRealPrice: realPrice.currencyDescription,
                title: title,
                textEta: textEta,
                promoText: promoText,
                insurance: insurance,
                serviceId: "",
                productId: 0,
                shipperId: selectedProduct.shipperId,
                shipperProductId: selectedProduct.id,
                promoCode: promoCode,
                freeShippingMetadata: freeShippingMetadata,
                shippingSubsidy: Float(shippingSubsidy),
                benefitClass: benefitClass,
                boCampaignId: boCampaignId,
                onTimeDelivery: onTimeDelivery,
                keroUnixTime: selectedProduct.keroUnixTime.rawValue,
                checksum: selectedProduct.checksum,
                ratesId: ratesResponse.ratesId,
                benefitAmount: benefitAmount
            )
        } else {
            self.init(
                validationMetadata: nil,
                finalPrice: 0,
                realPrice: 0,
                textFinalPrice: "",
                textRealPrice: "",
                title: "<b>\(String.scheduledDeliveryErrorTitle)</b>",
                textEta: .scheduledDeliveryNotProvided,
                promoText: "",
                insurance: .noInsurance,
                serviceId: "",
                productId: 0,
                shipperId: ShipmentID(rawValue: 0),
                shipperProductId: ShipmentProductID(rawValue: 0),
                promoCode: "",
                freeShippingMetadata: "",
                shippingSubsidy: 0,
                benefitClass: "",
                boCampaignId: 0,
                onTimeDelivery: OntimeDeliveryGuaranteeResponse(available: false, value: 0, textLabel: "", textDetail: "", urlDetail: "", iconUrl: ""),
                keroUnixTime: "",
                checksum: "",
                ratesId: RatesID(rawValue: ""),
                benefitAmount: 0
            )
        }
    }
}

internal struct TitleDescriptionViewData: Identifiable, Equatable {
    internal var id: String
    internal var title: String
    internal var description: String
    internal var accessibilityIdentifier: String?
    internal var subDescription: String?
    internal var slashedPrice: String?
    internal var isDiscount: Bool = false
    internal var isLoading: Bool = false
    internal var tooltipInfo: TooltipInfoViewData?
    internal var price: Price?
    internal var showChevronDown: Bool = false
    internal var showChevronUp: Bool = false
}

internal struct TooltipInfoViewData: Equatable {
    internal var title: String
    internal var info: String
}

public struct InsuranceResponse {
    public enum InsuranceType: Decodable {
        case noInsurance
        case optional
        case mustInsurance
    }

    public enum InsuranceUsedType: Decodable {
        case noInsurance
        case logisticInsurance
        case tokopediaInsurance
    }

    public let insuranceType: InsuranceType
    public let insurancePrice: Int
    public let insuranceTypeInfo: String
    public let insuranceUsedType: InsuranceUsedType
    public let insuranceUsedInfo: String
    public let insuranceUsedDefault: Bool

    public init(
        insuranceType: InsuranceResponse.InsuranceType,
        insurancePrice: Int,
        insuranceTypeInfo: String,
        insuranceUsedType: InsuranceResponse.InsuranceUsedType,
        insuranceUsedInfo: String,
        insuranceUsedDefault: Bool
    ) {
        self.insuranceType = insuranceType
        self.insurancePrice = insurancePrice
        self.insuranceTypeInfo = insuranceTypeInfo
        self.insuranceUsedType = insuranceUsedType
        self.insuranceUsedInfo = insuranceUsedInfo
        self.insuranceUsedDefault = insuranceUsedDefault
    }
}
extension InsuranceResponse: Decodable, Equatable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let insuranceTypeInt = try container.decode(Int.self, forKey: CodingKeys.insuranceType)
        if insuranceTypeInt == 3 {
            insuranceType = .mustInsurance
        } else if insuranceTypeInt == 2 {
            insuranceType = .optional
        } else {
            insuranceType = .noInsurance
        }

        insurancePrice = try container.decode(Int.self, forKey: CodingKeys.insurancePrice)
        insuranceTypeInfo = try container.decode(String.self, forKey: CodingKeys.insuranceTypeInfo)
        let insuranceUsedTypeInt = try container.decode(Int.self, forKey: CodingKeys.insuranceUsedType)
        if insuranceUsedTypeInt == 2 {
            insuranceUsedType = .tokopediaInsurance
        } else if insuranceUsedTypeInt == 1 {
            insuranceUsedType = .logisticInsurance
        } else {
            insuranceUsedType = .noInsurance
        }

        insuranceUsedInfo = try container.decode(String.self, forKey: CodingKeys.insuranceUsedInfo)
        let insuranceUsedDefaultInt = try container.decode(Int.self, forKey: CodingKeys.insuranceUsedDefault)
        insuranceUsedDefault = (insuranceUsedDefaultInt == 2) ? true : false
    }

    public static let noInsurance = Self(
        insuranceType: .noInsurance,
        insurancePrice: 0,
        insuranceTypeInfo: "",
        insuranceUsedType: .noInsurance,
        insuranceUsedInfo: "",
        insuranceUsedDefault: false
    )
}

public struct OntimeDeliveryGuaranteeResponse: Equatable, Decodable {
    public let available: Bool
    public let value: Int
    public let textLabel: String
    public let textDetail: String
    public let urlDetail: String
    public let iconUrl: String

    public init(
        available: Bool,
        value: Int,
        textLabel: String,
        textDetail: String,
        urlDetail: String,
        iconUrl: String
    ) {
        self.available = available
        self.value = value
        self.textLabel = textLabel
        self.textDetail = textDetail
        self.urlDetail = urlDetail
        self.iconUrl = iconUrl
    }
}
