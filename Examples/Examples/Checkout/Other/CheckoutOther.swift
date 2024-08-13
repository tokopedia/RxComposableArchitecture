//
//  CheckoutOther.swift
//  Examples
//
//  Created by jefferson.setiawan on 21/03/24.
//

import Foundation

public struct TransactionCartPayment: Equatable {
    internal let url: String
    internal let callbackUrl: String
    internal let queryString: String
    internal let failedCallBackUrl: String?
    internal var shouldAuthorizedRequest: Bool = false

    public init(url: String,
                callbackUrl: String = "",
                queryString: String = "",
                shouldAuthorizedRequest: Bool = false,
                failedCallBackUrl: String? = nil) {
        self.url = url
        self.callbackUrl = callbackUrl
        self.queryString = queryString
        self.failedCallBackUrl = failedCallBackUrl
        self.shouldAuthorizedRequest = shouldAuthorizedRequest
    }
}

internal struct DonationCheckboxViewData: Equatable {
    internal var checkboxViewData: CheckboxWithDescriptionViewData
    /**
     used to determine, will send analytics
     */
    internal var defaultIsSelectedFromServer: Bool
    internal var amount: Price
}

internal struct EgoldCheckboxViewData: Equatable {
    internal var _rawResponse: ShipmentAddressFormEGoldResponse
    internal var checkboxViewData: CheckboxWithDescriptionViewData
    internal var amount: Price

    internal static func egoldAmount(response: ShipmentAddressFormEGoldResponse, totalPrice: Price) -> Price {
        let totalPrice = totalPrice

        /**
         detail logic: https://tokopedia.atlassian.net/wiki/spaces/PI/pages/800917825/Checkout+Screen+Documentation#Egold-Section
         */
        guard let targetTier = { () -> ShipmentAddressFormEGoldTierResponse? in
            if response.isTiering {
                return response.tiers.last { tier -> Bool in
                    tier.minimumTotal < totalPrice
                }
            } else {
                let tier = response.tiers.first { tier -> Bool in
                    tier.maximum == response.range.maximum
                }

                if let tier = tier {
                    return ShipmentAddressFormEGoldTierResponse(
                        basis: tier.basis,
                        minimum: response.range.minimum,
                        maximum: response.range.maximum,
                        minimumTotal: tier.minimumTotal
                    )
                } else {
                    return nil
                }
            }
        }()
        else {
            return 0
        }

        let totalAmount = { () -> Int64 in
            let targetTierBasis = Int64(targetTier.basis)

            guard !totalPrice.isMultiple(of: targetTierBasis) else {
                return targetTierBasis
            }

            let additionalValue = targetTierBasis - (totalPrice % targetTierBasis)

            guard (additionalValue + totalPrice).isMultiple(of: targetTierBasis) else {
                return 0
            }

            if additionalValue >= targetTier.minimum {
                return additionalValue
            } else if additionalValue <= targetTier.minimum {
                return additionalValue + targetTierBasis
            } else {
                return 0
            }
        }()

        return Price(totalAmount)
    }

    internal mutating func recalculateAmount(with newTotalPrice: Price) {
        let newAmount = Self.egoldAmount(response: _rawResponse, totalPrice: newTotalPrice)

        amount = newAmount
        let subPrefix = _rawResponse.message.subtitle
        checkboxViewData.subtitle = .egold(subPrefix, newAmount)
        checkboxViewData.title = _rawResponse.message.title
    }
}

internal struct PromoState: Equatable {
    /**
     value needed for tracking, no use on checkout flow logic
     */
    internal var trackingDetails: [ShipmentAddressFormTrackingDetailResponse] = []

    /**
     value needed for determining spesific shipment based on applied merchant,
     used only to pass back when request shipment list/rates.
     */
    internal var merchantVoucerCoupon: [CartOrderID: [ShipmentAddressFormPromoAdditionalInfo.ShipmentBenefit]] = [:]

    /**
     View for determining promo section view state
     */
    internal var widgetView: CheckoutPromoWidgetData = CheckoutPromoWidgetData(view: .loadingContent, viewData: nil)

    /**
     Additional parameter for promo widget
     */
    internal var promoWidgetMandatoryData: MandatoryPromoWidgetData = MandatoryPromoWidgetData(userGroup: .groupC, isExpandable: true, isUsingNewPromoWidget: false, isOcc: false)

    /**
     Promo provided by tokopedia
     */
    internal var globalCode: PromoCode?

    internal var discountAmount: Price = 0
    internal var cashbackAmount: Price = 0
    internal var shippingDiscountAmount: Price = 0

    /**
     Params use for `PromoCheckoutViewController`, if value exist, will push new vc with this value
     */
    internal var openPromoPickerWithParams: PromoCheckoutParameter?

    internal var isEnabled: Bool = true

    internal var isAutoApplied: Bool = false

    internal var isBOUnstackEnabled: Bool = false
}

internal struct CheckoutPromoWidgetData: Equatable {
    /**
     Current view that will be subscribed

     Will be manipulated so
     */
    internal var view: PromoWidgetViewMode

    /**
     Property that will hold promo widget's view data
     */
    internal var viewData: PromoWidgetViewData?
}

public enum PromoWidgetViewMode: Equatable {
    case `default`(PromoWidgetViewData)
    case disabled(message: String, leftIconUrl: URL?)
    case error(PromoWidgetViewData)
    case loadingContent
    
    
// TODO JEFF: comment
//    internal func convertToViewState(
//        mandatoryData: MandatoryPromoWidgetData,
//        promoViewState: EntrypointInfoStateType,
//        promoViewInteractable: Bool
//    ) -> PromoWidgetWrapper.ViewState {
//        switch self {
//        case let .default(viewData):
//            let contentState = PromoWidget.State(
//                with: viewData,
//                viewState: promoViewState,
//                isInteractionEnabled: promoViewInteractable,
//                mandatoryData: mandatoryData
//            )
//
//            return .default(contentState)
//        case let .disabled(message, leftIconUrl):
//            let promoNodeState = Promo.State(
//                isExpandable: mandatoryData.isExpandable,
//                viewState: promoViewState,
//                isInteractionEnabled: promoViewInteractable,
//                isOldUserGroup: mandatoryData.userGroup.isOldUserGroup,
//                isUsingNewPromoWidget: mandatoryData.isUsingNewPromoWidget,
//                titles: [message],
//                subtitle: nil,
//                promoExists: false,
//                leftIconUrl: leftIconUrl
//            )
//
//            return .disabled(promoNodeState)
//        case let .error(latestViewData):
//            let errorState = PromoWidgetErrorState(
//                message: .errorPromoMessage,
//                latestViewData: latestViewData,
//                isExpandable: mandatoryData.isExpandable,
//                isUsingNewPromoWidget: mandatoryData.isUsingNewPromoWidget
//            )
//
//            return .error(errorState)
//        case .loadingContent:
//            return .loadingContent(
//                isExpandable: mandatoryData.isExpandable,
//                isUsingNewPromoWidget: mandatoryData.isUsingNewPromoWidget
//            )
//        }
//    }
}

public struct PromoWidgetViewData: Equatable {
    public var titles: [String]
    public let subtitle: String?

    /// Currently only used for non-expandable widget
    public let promoExists: Bool

    /// To perform animation in expandable promo widget
    public var benefitAmount: Int

    /// Need to be passed to support A/B testing (only used for `Promo Revamp`)
    public var leftIconUrl: URL?

    /// Need to be passed to support A/B testing (only used for `Promo Revamp`)
    public let useLeftIcon: Bool

    /// Data from `.last_apply` or `validate_use_promo_revamp` or `get_last_apply` (only used for `Promo Revamp`)
    /// `.last_apply` is a response field on implementor (`cart_revamp_v4`, `shipment_address_form_v4`, and `get_occ_multi`)
    public let promoSummaries: [PromoDescriptionViewData]

    /// Param to hit `GetPromoListRecommendation` API (only used for `Promo Revamp`)
    public var getPromoListRecomParam: CouponListParamData?

    /// Data from `GetPromoListRecommendation` (only used for `Promo Revamp`)
    /// Implementor can't assign value to this property because this data will only be used internally for promo widget
    internal var boBenefitData: BOBenefitData?

    /// Recommended promo count for tracker
    internal var recommendedPromoCount: Int

    /// Data from `GetPromoListRecommendation` (only used for `Promo Revamp`)
    /// Implementor can't assign value to this property because this data will only be used internally for promo widget
    internal var isAutoExpand: Bool

    public init(
        titles: [String],
        subtitle: String? = nil,
        promoExists: Bool = false,
        benefitAmount: Int,
        leftIconUrl: URL?,
        useLeftIcon: Bool,
        promoSummaries: [PromoDescriptionViewData] = [],
        getPromoListRecomParam: CouponListParamData?
    ) {
        self.titles = titles
        self.subtitle = subtitle
        self.promoExists = promoExists
        self.benefitAmount = benefitAmount
        self.leftIconUrl = leftIconUrl
        self.useLeftIcon = useLeftIcon
        self.promoSummaries = promoSummaries
        self.getPromoListRecomParam = getPromoListRecomParam
        recommendedPromoCount = 0
        isAutoExpand = false
    }
}

public struct PromoDescriptionViewData: Equatable {
    public let title: String
    public let description: String?
    public var subDescription: String?
    public let promoType: String

    /**
     To indicate that this data is a free shipping promo
     */
    public var isBebasOngkir: Bool {
        promoType == "bebas_ongkir"
    }

    public init(
        title: String,
        description: String? = nil,
        subDescription: String? = nil,
        promoType: String
    ) {
        self.title = title
        self.description = description
        self.subDescription = subDescription
        self.promoType = promoType
    }
}

public struct AddOnSelectionRequestParams: Equatable {
    public var products: [AddOnProduct]
    public var shopData: AddOnShopDetail
    public var addOnInfoWording: AddOnInfoWording
    public var selectedAddOnData: [AddOnDetailData]
    public var checkoutType: AddOnCheckoutType
    public var bottomsheetTitleText: String
    public var pageSource: AddOnPageSource
    public var recipientName: String

    // need to add public init
    // to statisfy compiler when this struct used in public final class
    public init(
        products: [AddOnProduct],
        shopData: AddOnShopDetail,
        addOnInfoWording: AddOnInfoWording,
        selectedAddOnData: [AddOnDetailData],
        checkoutType: AddOnCheckoutType,
        bottomsheetTitleText: String,
        pageSource: AddOnPageSource,
        recipientName: String
    ) {
        self.products = products
        self.shopData = shopData
        self.addOnInfoWording = addOnInfoWording
        self.selectedAddOnData = selectedAddOnData
        self.checkoutType = checkoutType
        self.bottomsheetTitleText = bottomsheetTitleText
        self.pageSource = pageSource
        self.recipientName = recipientName
    }
}

public struct AddOnProduct: Equatable {
    public var cartID: CartID
    public var parentProductID: ParentProductID
    public var productID: ProductID
    public var productName: String
    public var productImageURL: String
    public var warehouseID: WarehouseID
    public var quantity: Int
    public var price: Int

    // need to add public init
    // to statisfy compiler when this struct used in public final class
    public init(
        cartID: CartID,
        parentProductID: ParentProductID,
        productID: ProductID,
        productName: String,
        productImageURL: String,
        warehouseID: WarehouseID,
        quantity: Int,
        price: Int
    ) {
        self.cartID = cartID
        self.parentProductID = parentProductID
        self.productID = productID
        self.productName = productName
        self.productImageURL = productImageURL
        self.warehouseID = warehouseID
        self.quantity = quantity
        self.price = price
    }
}

public struct AddOnShopDetail: Equatable {
    public var shopTitle: String
    public var shopType: AddOnShopType

    // need to add public init
    // to statisfy compiler when this struct used in public final class
    public init(
        shopTitle: String,
        shopType: AddOnShopType
    ) {
        self.shopTitle = shopTitle
        self.shopType = shopType
    }
}

public enum AddOnShopType: Equatable {
    /**
      NOTES: how to fill the addOnKey
      1. for nonTokoCabang (product level addOn) -> `cartstring-cartid` (eg: `1-2-3-4-112`)
      2. for Tokocabang (order level addOn) -> `cartstring-0` (eg: `1-2-3-4-0`)
     */

    case nonTokoCabang(addOnKey: String)
    case tokoCabang(addOnKey: String)
}

public struct AddOnInfoWording: Equatable {
    public var packageAndGreetingCardInfoText: String
    public var onlyGreetingCardInfoText: String
    public var invoiceNotSentText: String

    // need to add public init
    // to statisfy compiler when this struct used in public final class
    public init(
        packageAndGreetingCardInfoText: String,
        onlyGreetingCardInfoText: String,
        invoiceNotSentText: String
    ) {
        self.packageAndGreetingCardInfoText = packageAndGreetingCardInfoText
        self.onlyGreetingCardInfoText = onlyGreetingCardInfoText
        self.invoiceNotSentText = invoiceNotSentText
    }
}

public enum AddOnCheckoutType: String {
    case `default` = "normal"
    case ocs
    case occ
}

public enum AddOnPageSource: String {
    case checkout
    case occ
}

public struct MandatoryPromoWidgetData: Equatable {
    /// To support A/B testing (only used for `Promo Revamp`)
    public let userGroup: PromoWidgetUserGroup

    /// To indicate whether the widget is expandable/not
    public let isExpandable: Bool

    /// To indicate whether the widget should use new UI/not
    public let isUsingNewPromoWidget: Bool

    /// For tracker
    public let isOcc: Bool

    public init(
        userGroup: PromoWidgetUserGroup,
        isExpandable: Bool,
        isUsingNewPromoWidget: Bool,
        isOcc: Bool
    ) {
        self.userGroup = userGroup
        self.isExpandable = isExpandable
        self.isUsingNewPromoWidget = isUsingNewPromoWidget
        self.isOcc = isOcc
    }
}

public struct PromoCheckoutParameter: Equatable {
    public let couponListParam: CouponListParamData
    public let pageSource: PromoCheckoutPageSource

    public init(
        couponListParam: CouponListParamData,
        pageSource: PromoCheckoutPageSource
    ) {
        self.couponListParam = couponListParam
        self.pageSource = pageSource
    }
}

public struct CouponListParamData: Equatable, Decodable {
    /**
     CheckoutType will be used to send `cart_type` params when requesting

     This params also effecting analytics.
     if you adapting promo list for new page, make sure your new params or if you choose to select current one, is suitable for your case.
     */
    public enum CheckoutType: String, Decodable, Equatable {
        /**
         Used by old/standart checkout
         */
        case `default`
        /**
         One Click Shipment
         */
        case ocs
        /**
         One Click Checkout
         */
        case occ = "occmulti"
    }

    /**
     State will be used to send `state` params when requesting

     This params also affecting analytics
     if you adapting promo list for new page, make sure your new params or if you choose to select current one, is suitable for your case.
     */
    public enum State: Equatable {
        /**
         Representing Cart Page
         */
        case cart

        /**
         Representing all Checkout page
         */
        case checkout(CheckoutType)

        public var rawValue: String {
            switch self {
            case .cart:
                return "cart"
            case .checkout:
                return "checkout"
            }
        }

        public var type: CouponListParamData.CheckoutType {
            switch self {
            case .cart:
                return .default
            case let .checkout(type):
                return type
            }
        }
    }

    /**
     Representation of global codes, you want to supply any codes that already used and categorized as global codes or global promo.

     global codes or global promo is any promo that tokopedia provide with its own budget.
     as for now, only 1 possible codes should be filled, but for future proof, its design as array, and no validation attempted on view model to filter double code for now.

     each promo section (divided by tokopedia, or each merchant on your cart) can only provide 1 coupon
     */
    public var codes: [String]

    /**
     Any codes that user fill in manually, for example some promo provide manual input voucher code ("TOPED100").

     all that codes should be placed here
     as for now, only 1 possible codes should be filled, but for future proof, its design as array, and no validation attempted on view model to filter double code for now
     */
    public var attemptedCodes: [String]

    /**
     Will send this as true if you want to do non mutating transaction, for example fetching `coupon_list_recommendation`,
     and set it to false if you want to do mutating function on promo state for example `validate_use_promo_revamp`.
     */
    public var skipApply: Bool

    /**
     isSuggested is flag on cart or checkout, please refer to Promo BE for more detail
     */
    public let isSuggested: Bool

    /**
     isTradeIn is flag on cart or checkout, please refer to Promo BE for more detail
     */
    public var isTradeIn: Bool

    /**
     isTradeInDropOff is flag on cart or checkout, please refer to Promo BE for more detail
     */
    public var isTradeInDropOff: Bool

    /**
     Determining source who access/call Promo page
     */
    public var state: State

    /**
     Array of orders on cart.
     */
    public var orders: [CouponListOrderParamsData]

    /**
     Flag to support A/B test for Promo Revamp
     */
    public let isCartCheckoutRevamp: Bool

    private enum CodingKeys: String, CodingKey {
        case codes
        case attemptedCodes = "attempted_codes"
        case skipApply = "skip_apply"
        case isSuggested = "is_suggested"
        case isTradeIn = "is_trade_in"
        case isTradeInDropOff = "is_trade_in_drop_off"
        case cartType = "cart_type"
        case state
        case orders
        case isCartCheckoutRevamp = "is_cart_checkout_revamp"
    }

    public init(codes: [String], attemptedCodes: [String], skipApply: Bool, isSuggested: Bool, isTradeIn: Bool, isTradeInDropOff: Bool, state: State, orders: [CouponListOrderParamsData], isCartCheckoutRevamp: Bool) {
        self.codes = codes
        self.attemptedCodes = attemptedCodes
        self.skipApply = skipApply
        self.isSuggested = isSuggested
        self.isTradeIn = isTradeIn
        self.isTradeInDropOff = isTradeInDropOff
        self.state = state
        self.orders = orders
        self.isCartCheckoutRevamp = isCartCheckoutRevamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        codes = try container.decode([String].self, forKey: .codes)
        attemptedCodes = try container.decode([String].self, forKey: .attemptedCodes)

        let skipApplyRawValue = try container.decode(Int.self, forKey: .skipApply)
        skipApply = skipApplyRawValue == 1

        let isSuggestedRawValue = try container.decode(Int.self, forKey: .isSuggested)
        isSuggested = isSuggestedRawValue == 1

        let isTradeInRawValue = try container.decode(Int.self, forKey: .isTradeIn)
        isTradeIn = isTradeInRawValue == 1

        let isTradeInDropOffRawValue = try container.decode(Int.self, forKey: .isTradeInDropOff)
        isTradeInDropOff = isTradeInDropOffRawValue == 1

        let stateRawValue = try container.decode(String.self, forKey: .state)

        if stateRawValue == "cart" {
            state = .cart
        } else if stateRawValue == "checkout" {
            let checkoutMode = try container.decode(CheckoutType.self, forKey: .cartType)
            state = .checkout(checkoutMode)
        } else {
            throw DecodingError.valueNotFound(String.self, DecodingError.Context(codingPath: [CodingKeys.state], debugDescription: "failed to decode state"))
        }

        orders = try container.decode([CouponListOrderParamsData].self, forKey: .orders)
        isCartCheckoutRevamp = try container.decode(Bool.self, forKey: .isCartCheckoutRevamp)
    }

    public func toJSONValue() -> [String: JSONValue] {
        var dict = [String: JSONValue]()

        dict["codes"] = .array(codes.map { JSONValue.string($0) })
        dict["attempted_codes"] = .array(attemptedCodes.map { JSONValue.string($0) })
        dict["skip_apply"] = .int(skipApply ? 1 : 0)
        dict["is_suggested"] = .int(isSuggested ? 1 : 0)
        dict["is_trade_in"] = .int(isTradeIn ? 1 : 0)
        dict["is_trade_in_drop_off"] = .int(isTradeInDropOff ? 1 : 0)
        dict["cart_type"] = .string(state.type.rawValue)
        dict["state"] = .string(state.rawValue)
        dict["orders"] = .array(orders.map { JSONValue.object($0.toJSONValue()) })
        dict["is_cart_checkout_revamp"] = .bool(isCartCheckoutRevamp)

        return dict
    }
}

internal struct BOBenefitData: Equatable {
    internal let message: String
    internal let displayRightIcon: Bool

    internal init(
        message: String,
        displayRightIcon: Bool
    ) {
        self.message = message
        self.displayRightIcon = displayRightIcon
    }
}

public enum PromoCheckoutPageSource: Equatable {
    case physical(PromoCheckoutPageType)
    case digital

    internal var isPhysicalGoods: Bool {
        switch self {
        case .physical:
            return true
        case .digital:
            return false
        }
    }
}

public enum PromoCheckoutPageType: Equatable {
    case cart(totalPrice: Int, totalItem: Int)
    case checkout
    case occ

    internal var isOCC: Bool {
        switch self {
        case .occ:
            return true
        case .cart, .checkout:
            return false
        }
    }

    internal var value: String {
        switch self {
        case .cart:
            return "cart"
        case .checkout:
            return "checkout"
        case .occ:
            return "occ"
        }
    }
}

public struct CouponListOrderParamsData: Codable, Equatable {
    public let shopId: Int
    public var uniqueId: CartShopID
    public var orderCartString: CartOrderID
    public var products: [CouponListProductParamsData]
    public var logisticCodes: [String]
    public var merchantCodes: [String]
    public var isChecked: Bool
    public var shippingId: Int?
    public var spId: Int?
    public var boType: Int?
    public var isPO: Bool?
    public var duration: String?
    public var warehouseID: Int?
    public var isInsurancePrice: Bool
    public var freeShippingMetadata: String?
    public var shippingPrice: Float?
    public var shippingSubsidy: Float?
    public var benefitClass: String?
    public var boCampaignId: Int?
    public var etaText: String?
    public var validationMetadata: String?

    public init(
        shopId: Int,
        uniqueId: CartShopID,
        orderCartString: CartOrderID = "",
        products: [CouponListProductParamsData],
        logisticCodes: [String],
        merchantCodes: [String],
        isChecked: Bool,
        shippingId: Int,
        spId: Int,
        boType: Int,
        isPO: Bool,
        duration: String,
        warehouseID: Int,
        isInsurancePrice: Bool,
        freeShippingMetadata: String = "",
        shippingPrice: Float? = 0,
        shippingSubsidy: Float? = 0,
        benefitClass: String? = "",
        boCampaignId: Int? = 0,
        etaText: String? = "",
        validationMetadata: String = ""
    ) {
        self.shopId = shopId
        self.uniqueId = uniqueId
        self.orderCartString = orderCartString
        self.products = products
        self.logisticCodes = logisticCodes
        self.merchantCodes = merchantCodes
        self.isChecked = isChecked
        self.shippingId = shippingId
        self.spId = spId
        self.boType = boType
        self.isPO = isPO
        self.duration = duration
        self.warehouseID = warehouseID
        self.isInsurancePrice = isInsurancePrice
        self.freeShippingMetadata = freeShippingMetadata
        self.shippingPrice = shippingPrice
        self.shippingSubsidy = shippingSubsidy
        self.benefitClass = benefitClass
        self.boCampaignId = boCampaignId
        self.etaText = etaText
        self.validationMetadata = validationMetadata
    }

    public enum CodingKeys: String, CodingKey {
        case shopId = "shop_id"
        case uniqueId = "unique_id"
        case orderCartString = "cart_string_group"
        case products = "product_details"
        case logisticCodes = "logistic_codes"
        case merchantCodes = "merchant_codes"
        case isChecked = "is_checked"
        case shippingId = "shipping_id"
        case spId = "sp_id"
        case isInsurancePrice = "is_insurance_price"
        case freeShippingMetadata = "free_shipping_metadata"
        case shippingPrice = "shipping_price"
        case shippingSubsidy = "shipping_subsidy"
        case benefitClass = "benefit_class"
        case boCampaignId = "bo_campaign_id"
        case etaText = "eta_txt"
        case validationMetadata = "validation_metadata"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        shopId = try container.decode(Int.self, forKey: .shopId)
        let _uniqueId = try container.decode(String.self, forKey: .uniqueId)
        uniqueId = _uniqueId
        let _orderCartString = try container.decode(String.self, forKey: .orderCartString)
        orderCartString = _orderCartString
        products = try container.decode([CouponListProductParamsData].self, forKey: .products)
        logisticCodes = try container.decode([String].self, forKey: .logisticCodes)
        merchantCodes = try container.decode([String].self, forKey: .merchantCodes)
        isChecked = try container.decode(Bool.self, forKey: .isChecked)

        shippingId = try container.decodeIfPresent(Int.self, forKey: .shippingId)
        spId = try container.decodeIfPresent(Int.self, forKey: .spId)

        let isInsurancePriceRawValue = try container.decodeIfPresent(Int.self, forKey: .isInsurancePrice)
        isInsurancePrice = isInsurancePriceRawValue == 1 ? true : false

        freeShippingMetadata = try container.decodeIfPresent(String.self, forKey: .freeShippingMetadata)
        validationMetadata = try container.decodeIfPresent(String.self, forKey: .validationMetadata)
    }

    public func toJSONValue() -> [String: JSONValue] {
        var dict = [String: JSONValue]()

        dict["shop_id"] = .int(shopId)
        dict["unique_id"] = .string(uniqueId)
        dict["cart_string_group"] = .string(orderCartString)
//        dict["product_details"] = .array(products.map { JSONValue.object($0.toJSONValue()) })

        let codes = Array(Set(logisticCodes + merchantCodes))

        dict["codes"] = .array(codes.map { JSONValue.string($0) })
        dict["is_checked"] = .bool(isChecked)
        dict["shipping_id"] = .int(shippingId ?? 0)
        dict["sp_id"] = .int(spId ?? 0)
        dict["is_insurance_price"] = .int(isInsurancePrice ? 1 : 0)
        dict["free_shipping_metadata"] = .string(freeShippingMetadata ?? "")
        dict["shipping_price"] = .float(shippingPrice ?? 0)
        dict["shipping_subsidy"] = .float(shippingSubsidy ?? 0)
        dict["benefit_class"] = .string(benefitClass ?? "")
        dict["bo_campaign_id"] = .int(boCampaignId ?? 0)
        dict["eta_text"] = .string(etaText ?? "")
        dict["validation_metadata"] = .string(validationMetadata ?? "")

        return dict
    }
}

public struct CouponListProductParamsData: Codable, Equatable {
    public var productId: Int
    public let cartId: String
    public let quantity: Int
    public var isChecked: Bool
    public var bundleId: Int?

    public init(productId: Int, cartId: String, quantity: Int, isChecked: Bool = true, bundleId: Int? = 0) {
        self.productId = productId
        self.cartId = cartId
        self.quantity = quantity
        self.isChecked = isChecked
        self.bundleId = bundleId
    }

    public func toJSONValue() -> [String: JSONValue] {
        var dict = [String: JSONValue]()

        dict["product_id"] = .int(productId)
        dict["cart_id"] = .string(cartId)
        dict["quantity"] = .int(quantity)
        dict["is_checked"] = .bool(isChecked)
        dict["bundle_id"] = .int(bundleId ?? 0)

        return dict
    }
}

public struct AddOnDisableInfoData: Equatable {
    public var titleBottomsheetText: String
    public var description: String
    public var products: [AddOnInfoProductData]
    public var tickerText: String

    // need to add public init
    // to statisfy compiler when this struct used in public final class
    public init(
        titleBottomsheetText: String,
        description: String,
        products: [AddOnInfoProductData],
        tickerText: String
    ) {
        self.titleBottomsheetText = titleBottomsheetText
        self.description = description
        self.products = products
        self.tickerText = tickerText
    }
}

public struct AddOnInfoProductData: Equatable {
    public var productName: String
    public var productImageUrl: String

    // need to add public init
    // to statisfy compiler when this struct used in public final class
    public init(
        productName: String,
        productImageUrl: String
    ) {
        self.productName = productName
        self.productImageUrl = productImageUrl
    }
}

internal struct CheckoutPaymentFeeParameter: Equatable {
    internal var profileCode: String
    internal var paymentAmount: Float
    internal var additionalData: String
}

internal enum PaymentFeeViewMode: Equatable {
    case loading
    case normal
}

internal struct PaymentFeeViewData: Equatable {
    internal var viewMode: PaymentFeeViewMode
    internal var currentTotalPrice: Price?
    internal var feeData: CheckoutPaymentFeeDetail?
    internal var paymentFeeTickerMessage: String?
}

internal struct CheckoutPaymentFeeDetail: Equatable, Decodable {
    
    internal var code: String?
    internal var title: String?
    internal let fee: Price

    internal var tooltipInfo: String?
    internal let showTooltip: Bool
    internal let showSlashed: Bool
    internal let slashedFee: Price
    internal let minPrice: Price
    internal let maxPrice: Price
}

import CasePaths

internal struct UploadPrescriptionState: Equatable {
    /**
     Current node ui
     */
    internal var mode: ViewMode = .loading

    internal enum ViewMode: Equatable {
        case loading
        case content(UploadPrescriptionRootState)

        internal var content: UploadPrescriptionRootState? {
            get {
                extract(case: ViewMode.content, from: self)
            }
            set {
                guard let contentState = newValue else { return }
                self = .content(contentState)
            }
        }
    }
}

internal struct UploadPrescriptionRootState: Equatable {
    /**
     Flag to show upload prescription widget
     */
    internal let isShowImage: Bool

    /**
     Widget's title
     */
    internal var title: String

    /**
     Widget's subtitle
     */
    internal var subtitle: String?

    /**
     Widget's left icon, default to prescription icon, if fail show broken image
     */
    internal let leftIcon: URL?

    /**
     Widget's right icon, default to chevron right, if fail show broken image
     */
    internal let rightIcon: URL?

    /**
     Flag to set `UploadPrescriptionNode` with red subtitle color to get user attention
     */
    internal var isHighlighted: Bool = false

    /**
     Animate wiggle on `UploadPrescriptionNode`
     */
    internal var wiggling: Bool = false

    /**
     Uploaded prescription checkout id
     */
    internal let checkoutID: PrescriptionCheckoutID?

    /**
     Uploaded prescription checkout id
     */
    internal let isEnableUploadPrescriptionValidation: Bool

    /**
     Is products has ethical product
     */
    internal var hasEthicalDrug: Bool {
        isShowImage && checkoutID != nil
    }

    // used to block checkout flow if users manipulate the recommended quantity from doctor in cart, this derived from PPG response
    internal var isCheckoutFlowApprovedByPPG: Bool = true
}

internal enum DynamicDataParamLevel: String, Encodable {
    case payment = "payment_level"
    case order = "order_level"
    case product = "product_level"
}

internal enum DynamicDataParamAttribute: String, Encodable {
    case donation
    case addOn = "addon_details"
}

// DynamicDataParam
internal struct DynamicDataParam: Equatable {
    internal var level: DynamicDataParamLevel

    /**
     - Donation: Empty string
     - Add on:
        - Order level: Empty string
        - Product level: cartString
     */
    internal var parentUniqueId: String

    /**
     - Donation: Empty string
     - Add on:
        - Order level: cartString
        - Product level: cartId
     */
    internal var uniqueId: String
    internal var attribute: DynamicDataParamAttribute
    internal var donation: Bool?
    internal var addon: DynamicDataAddOn?
}

internal struct DynamicDataAddOn: Equatable {
    internal var addOnData: [DynamicDataSaveAddOn]
    internal var source: String
}

extension DynamicDataAddOn: Encodable {
    internal enum CodingKeys: String, CodingKey {
        case addOnData = "add_on_data"
        case source
    }
}

// DynamicDataSaveAddOn
internal struct DynamicDataSaveAddOn: Equatable {
    internal var addOnId: Int
    internal var addOnQty: Int
    internal var addOnMetadata: DynamicDataSaveAddOnMetadata
}

extension DynamicDataSaveAddOn: Encodable {
    internal enum CodingKeys: String, CodingKey {
        case addOnId = "add_on_id"
        case addOnQty = "add_on_qty"
        case addOnMetadata = "add_on_metadata"
    }
}

// DynamicDataSaveAddOnMetadata
internal struct DynamicDataSaveAddOnMetadata: Equatable {
    internal var addOnNote: DynamicDataSaveAddOnNote
}

extension DynamicDataSaveAddOnMetadata: Encodable {
    internal enum CodingKeys: String, CodingKey {
        case addOnNote = "add_on_note"
    }
}

// DynamicDataSaveAddOnNote
internal struct DynamicDataSaveAddOnNote: Equatable {
    internal var isCustomNote: Bool
    internal var to: String
    internal var from: String
    internal var notes: String
}

extension DynamicDataSaveAddOnNote: Encodable {
    internal enum CodingKeys: String, CodingKey {
        case isCustomNote = "is_custom_note"
        case to
        case from
        case notes
    }
}

internal struct FreeShipmentData {
    internal let orderId: CartOrderID
    internal let promoCode: String
    internal let shipmentId: ShipmentID
    internal let shipmentProductId: ShipmentProductID
    internal let promoStacking: LogisticRatesPromoStackingResponse?
}

internal struct ShipmentAddressFormParams {
    private let language: String = "id"
    private let cornerId: Int = 0
    internal var deviceId: String // DeviceID

    /**
     is current session `One Click Shipment` or not
     */
    internal var isOCS: Bool

    internal var skipOnboarding: Bool

    /**
     Flag current checkout will be trade in
     */
    internal var isTradeIn: Bool

    /**
     Will be used for trade in
     */
    internal var vehicleLeasingId: LeasingID

    /**
     Flag current checkout using multi addresss
     */
    internal let isMulti: Bool

    internal var chosenAddress: ShipmentAddressFormChosenAddressParams?

    internal var isPlusWidgetSelected: Bool

    internal var isCheckoutReimagine: Bool

    internal var shipmentActionType: String

    internal init(
        vehicleLeasingId: LeasingID = 0,
        isOCS: Bool = false,
        skipOnboarding: Bool = false,
        isTradeIn: Bool = false,
        isMulti: Bool = false,
        deviceId: DeviceID,
        chosenAddress: ShipmentAddressFormChosenAddressParams? = nil,
        isPlusWidgetSelected: Bool = false,
        isCheckoutReimagine: Bool = true,
        shipmentActionType: ShipmentActionType
    ) {
        self.vehicleLeasingId = vehicleLeasingId
        self.isOCS = isOCS
        self.skipOnboarding = skipOnboarding
        self.isTradeIn = isTradeIn
        self.isMulti = isMulti
        self.deviceId = deviceId
        self.chosenAddress = chosenAddress
        self.isPlusWidgetSelected = isPlusWidgetSelected
        self.isCheckoutReimagine = isCheckoutReimagine
        self.shipmentActionType = shipmentActionType.rawValue
    }
}

extension ShipmentAddressFormParams: Encodable {
    internal enum CodingKeys: String, CodingKey {
        case language = "lang"
        case cornerId = "corner_id"
        case vehicleLeasingId = "vehicle_leasing_id"
        case deviceId = "dev_id"
        case isOCS = "is_ocs"
        case skipOnboarding = "skip_onboarding"
        case isTradeIn = "is_trade_in"
        case isMulti = "is_multi"
        case chosenAddress = "chosen_address"
        case isPlusWidgetSelected = "is_plus_selected"
        case isCheckoutReimagine = "is_checkout_reimagine"
        case shipmentActionType = "shipment_action"
    }
}

extension ShipmentAddressFormParams: Equatable {}

internal struct SaveAddOnRequestParams: Encodable, Equatable {
    internal var addOnDetailData: [SaveAddOnDetailData]
    internal var source: String

    internal enum CodingKeys: String, CodingKey {
        case addOnDetailData = "add_ons"
        case source
    }
}

internal struct SaveAddOnDetailData: Encodable, Equatable {
    internal var addOnKey: String
    internal var addOnLevel: String
    internal var cartProducts: [SaveAddOnCartProduct]
    internal var addOnData: [SaveAddOnData]

    internal enum CodingKeys: String, CodingKey {
        case addOnKey = "add_on_key"
        case addOnLevel = "add_on_level"
        case cartProducts = "cart_products"
        case addOnData = "add_on_data"
    }
}

internal struct SaveAddOnData: Encodable, Equatable {
    internal var addOnID: Int
    internal var addOnUniqueID: String
    internal var addOnQty: Int
    internal var addOnMetadata: SaveAddOnMetadata

    internal enum CodingKeys: String, CodingKey {
        case addOnID = "add_on_id"
        case addOnUniqueID = "add_on_unique_id"
        case addOnQty = "add_on_qty"
        case addOnMetadata = "add_on_metadata"
    }
}

internal struct SaveAddOnMetadata: Encodable, Equatable {
    internal var addOnNote: SaveAddOnNoteMetadata

    internal enum CodingKeys: String, CodingKey {
        case addOnNote = "add_on_note"
    }
}

internal struct SaveAddOnNoteMetadata: Encodable, Equatable {
    internal var isCustomNote: Bool
    internal var recipientText: String
    internal var fromText: String
    internal var notesText: String

    internal enum CodingKeys: String, CodingKey {
        case isCustomNote = "is_custom_note"
        case recipientText = "to"
        case fromText = "from"
        case notesText = "notes"
    }
}

internal enum OrderAction: Equatable {
    /**
     User tap insurance info button on shop group
     */
    case userTapInsuranceInfoButton

    /**
     Side effect when user switch from free shipment to non free shipment

     - Parameters:
        forSelectedOption: Used to update checkout state with new shipment when its normal flow
        forSelectedScheduled: Used to update checkout state with new shipment when its NOW scheduled  flow
     */
    case receiveResetFreeShipment

    /**
     Response on validating selected free shipment shipment

     - Parameters:
        forSelectedOption: Used to update checkout state with new shipment when its normal flow
        forSelectedScheduled: Used to update checkout state with new shipment when its NOW scheduled  flow
     */
    case receiveValidateCouponResponse

    case dropshipperDetail(Int)

    /**
     to send analytics
     */
    case toggleSubtotal

    /**
     To scroll to disabled product when error ticker for Mini Consultation is tapped
     */
    case tapConsultationErrorTicker

    /**
     to send analytics
     */
    case viewOrderErrorTicker([TickerContent])

    case addOnAction(AddOnAction)

    case shipper(ShipperAction)

    case scheduledDelivery(ScheduledDeliveryShipperAction)

    case shop(identifier: CartShopID, action: ShopAction)

    /**
     Action from split order popup,
     `true` means user continue to split,
     `false` means user cancel split order.
     */
    case splitOrderAction(shouldContinue: Bool)
}
internal enum AddOnAction: Equatable {
    case userTapAddonCard
    case didLoad

    // This action is for AddOn, not Gifting
    case userTapAddOnDetail(addOnType: Int)
}

public enum ShipperAction: Equatable {
    /**
     To refresh rates when user cannot change courier and there is courier error from saf or rates
     */
    case refreshRates

    /**
     To refresh SAF after user select pinpoint when cannot change courier.
     This action is handled in CheckoutViewController+Reducer.
     */
    case refreshSaf

    /**
     When user select option from picker.
     this action is also called by checkoutViewController when fetching each shop group non zero shipment and shipper id.

     - Parameters:
     - validation: set validation true if validating selected shipper is neccessary. this validation will validating if current shipper is free shipment, which need to apply promo code to server.

     validation options is there so when user select option and it will be validated by backend, then i can call the same function to set the view if success.
     */
    case receiveShipperPickerResult(SelectedShipper)

    /**
     Action when after open shipment picker, user update it's address with pin point
     */
    case needUpdateAddressAfterPinPoint(Address, fromMode: ShipperPickerMode)

    /**
     When user tap duration shipment like `Reguler`, `Same Day`
     */
    case openShipperPicker

    /**
     When user tap product from duration like `JNE Reg`, `Gojek Instant`
     */
    case openShipperProductPicker

    /**
     dismiss shipper picker if currently open
     */
    case dismissShipperPicker

    /**
     Stop wiggle animation. wiggle animation can be triggered if when user tapped checkout, shop group shipper doesn't yet pick any shipment
     */
    case stopShipperWiggle

    /**
     Actions from shipper insurance node, includes check box taps and showing insurance info bottom sheet
     */
    case insurance(ShipperInsuranceAction)
}

public enum ScheduledDeliveryShipperAction: Equatable {
    case didLoad
    case refresh
    case shipmentSelectionDidChanged(oldValue: ScheduledDeliveryShipment?, newValue: ScheduledDeliveryShipment)
    case showScheduledDeliveryCoachmark
    case invertShipperCell

    // Side Effects
    case retrieveScheduledDeliveryOnlyData//(Result<ScheduledDeliveryRatesResponse, NetworkError>)
    case retrieveScheduledDeliveryData//(Result<ScheduledDeliveryAndRatesResponse, NetworkError>)
    case didSelectScheduledDeliveryShipment(ScheduledDeliveryShipment)

    // Scope
    case content//(ScheduledDeliveryShipperContentAction)
    case insurance(ShipperInsuranceAction)
}

public struct SelectedShipper: Equatable {
    public var previousShipperId: ShipmentID
    public var previousShipperProductId: ShipmentProductID
    public var previousIsFreeShipment: Bool

    /// mode to determine which data will be show from picker
    public var mode: ShipperPickerMode
    /// selected option
    public var option: ShipperPickerSelectedOption

    /**
     If current selected shipper indicate that will reset free shipment
     */
    public var resetFreeShipment: Bool {
        previousIsFreeShipment && !option.selectedCourier.isFreeShipment
    }

    public init(
        previousShipperId: ShipmentID,
        previousShipperProductId: ShipmentProductID,
        previousIsFreeShipment: Bool,
        mode: ShipperPickerMode,
        option: ShipperPickerSelectedOption
    ) {
        self.previousShipperId = previousShipperId
        self.previousShipperProductId = previousShipperProductId
        self.previousIsFreeShipment = previousIsFreeShipment
        self.mode = mode
        self.option = option
    }
}

public struct ShipperPickerSelectedOption: Equatable {
    public var ratesId: RatesID
    public var selectedDuration: LogisticRatesServiceResponse
    public var selectedCourier: LogisticRatesServiceProductResponse

    /// Promo stacking response, if shipment is free shipment, the data is used for validate use param in implementor
    public var promoStacking: LogisticRatesPromoStackingResponse?

    public init(
        ratesId: RatesID,
        selectedDuration: LogisticRatesServiceResponse,
        selectedCourier: LogisticRatesServiceProductResponse,
        promoStacking: LogisticRatesPromoStackingResponse? = nil
    ) {
        self.ratesId = ratesId
        self.selectedDuration = selectedDuration
        self.selectedCourier = selectedCourier
        self.promoStacking = promoStacking
    }
}

internal enum ShopAction: Equatable {
    case product(identifier: ShipmentProductID, action: ProductAction)
    case cartDetails(identifier: CartDetailState.ID, action: CartDetailAction)
}

internal enum ProductAction: Equatable {
    /**
     tick and untick checkbox on purchase protection node, also
     - update subtotal on shop group
     - update summary on checkout
     */
    case userTapPurchaseProtectionCheckbox

    case viewProductErrorTicker
    case addOnAction(AddOnAction)
//    case receiveAddonPickerCallback([AddonPickerCallbackData])
}

internal enum CartDetailAction: Equatable {
    case product(identifier: ShipmentProductID, action: ProductAction)
    case openOfferDetail
}

internal enum AddressAction: Equatable {
    /**
     When user redirected to add new address, this should be the callback when it finish / success
     */
    case finishAddNewAddress

    /**
     Action when user cancelling add new Address, will send user back to previous page
     */
    case cancelAddNewAddress
    case finishSelectNewAddress
    case cancelSelectNewAddress
    case openAddressPicker
    case closeAddressPicker
    case pickAddress(AddressID)
    case tapChooseIndomaret
    case setLocalizedAddress(LocalizedAddress)
    case changeAddressResponse(Result<ChangeShipmentAddressResponse, NetworkError>)
    case forceSyncAddressResponse(Result<LocalizedAddress, AddressLocalizationServiceError>)
}

public struct ChangeShipmentAddressResponse: Decodable, Equatable {
    public var isSuccess: Bool
    public let messages: [String]?

    public enum CodingKeys: String, CodingKey {
        case isSuccess = "success"
        case messages = "message"
    }

    public init(
        isSuccess: Bool,
        messages: [String]?
    ) {
        self.isSuccess = isSuccess
        self.messages = messages
    }
}

public enum AddressLocalizationServiceError: Error, Equatable {
    /**
     Timeout waiting for emit result from Store
     it's an unexpected case, should not be happend. please report to developer if you get this value
     */
    case timeout

    /**
     Basic NetworkError
     */
    case networkError(NetworkError)
}

internal struct CheckoutEpharmacyPPGData: Equatable {
    internal let checkoutPrescriptionData: [CheckoutPrescriptionData]
    internal var checkoutError: String?
}

internal enum CheckoutPlusWidgetAction: Equatable {
    case buttonTap
}

internal enum SummaryAction: Equatable {
    case checkout
    case showEmptyShipment
//    case validateCheckoutResponse(Result<RequestCheckoutResponse, NetworkError>)
//    case saveAddOnsResponse(AddressID, Result<SaveAddonResponse, TPError<AddonBottomSheetErrorState>>)
    case updateDynamicData(addressId: AddressID)
//    case updateDynamicDataResponse(Result<UpdateDynamicDataResponse, TPError<UpdateDynamicDataError>>, addressId: AddressID)
    case refetchPaymentFee
    case tapTooltipButton
    case tapChevron

    // Egold
    case tapEGoldCheckbox
    case tapEGoldTermsAndConditions

    case tapTermsAndConditions
}

internal enum PromoAction: Equatable {
    /**
     Process response to state
     */
//    case validateCouponResponse(Result<ValidateCouponResponseData, NetworkError>, source: ValidateCouponSource)

    /**
     revalidating shopgroup shipment status, on mvc status.
     will be executed after success validate use
     */
//    case mvcStatusResponse([IdentifiedLogisticRatesMVCOnlyResponse])

    /**
     Action if user reset promo on `PromoCheckoutViewController`.
     need new title for promo section title
     */
    case resetPromo(newTitle: String, shouldResetShipment: Bool)

    /**
     Trigger to show or close promo picker.
     */
    case openPromoPicker

    /**
     Trigger to close picker promo. You need to close the picker after open promo, because open promo picker trigger to fill the data, and once data is filled.
     you need to clear it, so next trigger will sended (because disctint value is neccessary or it will be filter out).
     */
    case closePromoPicker

    /**
     Apply or unapply bebas ongkir after user choose / remove BO coupon from promo page
     */
    case setBOCoupon
}
