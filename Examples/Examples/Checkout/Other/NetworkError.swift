//
//  NetworkError.swift
//  Examples
//
//  Created by jefferson.setiawan on 21/03/24.
//

import Foundation
public typealias ShipmentShopID = Int

public enum NetworkError: Error, Equatable {
    case noInternet
    case serverError
    case pageNotFound
    case underMaintenance
    case fullVisitor
    case timeout
}

internal struct EmptyStateData: Equatable {
    internal let title: String?
    internal let message: String
    internal let logoName: String
    internal let callback: [EmptyStateCallBack]

    internal init(title: String?, message: String, logoName: String, callback: [EmptyStateCallBack]) {
        self.title = title
        self.message = message
        self.logoName = logoName
        self.callback = callback
    }

    /**
     Create `EmptyStateData` from `NetworkError`
     */
    internal init(from networkError: NetworkError, callback: [EmptyStateCallBack]) {
        title = "networkError.title"
        message = "networkError.message"
        logoName = "networkError.imageSource"
        self.callback = callback
    }
}

internal struct EmptyStateCallBack: Equatable {
    internal let ctaTitle: String
    internal let ctaActions: [CheckoutAction]
}

internal struct ShipmentAddressFormExpiredInfoResponse: Decodable, Equatable {
    internal let title: String
    internal let description: String
    internal let buttonTitle: String

    internal enum CodingKeys: String, CodingKey {
        case title, description
        case buttonTitle = "Button"
    }
}

public typealias CartID = String
public typealias CartOrderID = String
public typealias CartShopID = String

public typealias OfferID = String
public typealias OfferTierID = String
public typealias RatesID = String
public typealias ShipmentID = Int
public typealias ShipmentProductID = Int

public struct LogisticRatesResponse: Decodable, Equatable {
    public let ratesId: RatesID
    public let origin: LogisticRatesOrigin
    public let weight: String
    public var services: [LogisticRatesServiceResponse]
    public var promoStackings: [LogisticRatesPromoStackingResponse]
    public let preOrder: LogisticRatesPreOrderResponse

    public enum CodingKeys: String, CodingKey {
        case ratesId = "rates_id"
        case origin
        case weight
        case services
        case promoStackings = "promo_stackings"
        case preOrder = "pre_order"
    }

    public init(
        ratesId: RatesID,
        origin: LogisticRatesOrigin,
        weight: String,
        services: [LogisticRatesServiceResponse],
        promoStackings: [LogisticRatesPromoStackingResponse],
        preOrder: LogisticRatesPreOrderResponse
    ) {
        self.ratesId = ratesId
        self.origin = origin
        self.weight = weight
        self.services = services
        self.promoStackings = promoStackings
        self.preOrder = preOrder
    }
}

public struct LogisticRatesPreOrderResponse: Decodable, Equatable {
    public let header: String
    public let label: String
    public let display: Bool

    public init(header: String, label: String, display: Bool) {
        self.header = header
        self.label = label
        self.display = display
    }
}

public struct LogisticRatesOrigin: Decodable, Equatable {
    public let cityName: String

    private enum CodingKeys: String, CodingKey {
        case cityName = "city_name"
    }

    public init(cityName: String) {
        self.cityName = cityName
    }
}

public struct LogisticRatesServiceResponse {
    public let serviceId: Int
    public let name: String

    /// to support bebas ongkir weight, free shipment name could different on bottom sheet vs selected courier widget
    /// will place here the custom selected courier widget naming from `promo_stacking.texts.choosen_courier`
    public var freeShipmentDisplayName: String?
    /// will place here the custom selected courier widget naming from `promo_stacking.texts.promo_message`
    public var freeShipmentDescription: String?

    /// The order priority displaying service
    public let order: Int
    public var isPromo: Bool
    public var products: [LogisticRatesServiceProductResponse]
    public let note: String?
    public let additionalDescription: String?
    /// eta -> Estimated Time Arrival
    public var eta: LogisticRatesEstimatedTimeArrivalResponse

    /// COD -> cash on delivery
    public var codDescription: String?
    public let error: LogisticRatesServiceErrorResponse?
    public let orderPriorityPrice: Price?
    public let merchantVoucherCoupon: LogisticRatesMerchantVoucherCoupon

    /// url image to show when selection, for now only used on BBO
    public let imageURL: URL?
    public let isFreeShipment: Bool

    /// helper to save `bebas ongkir extra` data
    public let isBebasOngkirExtra: Bool

    /// generalize to support BBO as service, for default service, will use `range`, BBO will use `benefit`
    public let priceDescription: LogisticRatesServicePriceDescription
    /// helper for BBO service
    public let isEnabled: Bool

    public let dynamicPriceLabelText: String
    public var tokonowBenefitDescription: String?

    /// indicate to hide this service from bottom sheet and selection
    public var isHidden: Bool

    /// If the value is greater than zero, we will auto select this service and also hide the courier selection UI.
    /// This will mimic how free shipment flow when you select one.
    /// After selection, we only show the service name.
    public var autoSelectShipperProductId: ShipmentProductID

    /// data to be sent to checkout when BO is applied
    public let freeShippingMetadata: String

    // MARK: - Revamp OCC to Use ShipperPicker Module Requirements -

    /// PromoStacking's  benefitDescription.
    public let benefitDescription: String

    /// Bebas Ongkir Type. If service isn't categorized as free shipment, this value must be .none.
    public let boType: BOType

    /// Bebas Ongkir Quota
    /// this field was introduced in Checkout Revamp to show BO quota in shipper picker bottom sheet
    public let boQuotaText: String?

    /// Text used for ticker wording under “Pilih Kurir”
    public var courierTickerText: String?

    public init(
        serviceId: Int,
        name: String,
        freeShipmentDisplayName: String? = nil,
        freeShipmentDescription: String? = nil,
        order: Int,
        isPromo: Bool,
        products: [LogisticRatesServiceProductResponse],
        note: String?,
        additionalDescription: String?,
        eta: LogisticRatesEstimatedTimeArrivalResponse,
        codDescription: String? = nil,
        error: LogisticRatesServiceErrorResponse?,
        orderPriorityPrice: Price?,
        merchantVoucherCoupon: LogisticRatesMerchantVoucherCoupon,
        imageURL: URL?,
        isFreeShipment: Bool,
        isBebasOngkirExtra: Bool,
        priceDescription: LogisticRatesServicePriceDescription,
        isEnabled: Bool,
        dynamicPriceLabelText: String,
        tokonowBenefitDescription: String? = nil,
        isHidden: Bool,
        autoSelectShipperProductId: ShipmentProductID,
        freeShippingMetadata: String,
        benefitDescription: String,
        boType: BOType,
        boQuotaText: String? = nil,
        courierTickerText: String? = nil
    ) {
        self.serviceId = serviceId
        self.name = name
        self.freeShipmentDisplayName = freeShipmentDisplayName
        self.freeShipmentDescription = freeShipmentDescription
        self.order = order
        self.isPromo = isPromo
        self.products = products
        self.note = note
        self.additionalDescription = additionalDescription
        self.eta = eta
        self.codDescription = codDescription
        self.error = error
        self.orderPriorityPrice = orderPriorityPrice
        self.merchantVoucherCoupon = merchantVoucherCoupon
        self.imageURL = imageURL
        self.isFreeShipment = isFreeShipment
        self.isBebasOngkirExtra = isBebasOngkirExtra
        self.priceDescription = priceDescription
        self.isEnabled = isEnabled
        self.dynamicPriceLabelText = dynamicPriceLabelText
        self.tokonowBenefitDescription = tokonowBenefitDescription
        self.isHidden = isHidden
        self.autoSelectShipperProductId = autoSelectShipperProductId
        self.freeShippingMetadata = freeShippingMetadata
        self.benefitDescription = benefitDescription
        self.boType = boType
        self.boQuotaText = boQuotaText
        self.courierTickerText = courierTickerText
    }
}

/**
 https://tokopedia.atlassian.net/wiki/spaces/LG/pages/963742138/Estimated+Time+Arrival+ETA

 Error code along with ETA text.
 0 → Success
 1 → User not in whitelist
 2 → No ETA by using Kurir Toko
 */
public enum LogisticRatesEstimatedTimeArrivalStatus: Int, Decodable {
    case available = 0
    case notIncluded = 1
    case notAvailable = 2
}

public enum LogisticRatesServicePriceDescription: Equatable {
    case range(LogisticRatesServiceRangePriceResponse)
    case benefit(String)

    public var priceRange: LogisticRatesServiceRangePriceResponse? {
        switch self {
        case let .range(priceRange):
            return priceRange
        default:
            return nil
        }
    }
}

// MARK: - Extensions -

extension LogisticRatesServiceResponse: Decodable, Equatable {
    public enum JSONKeys: String, CodingKey {
        case serviceId = "service_id"
        case name = "service_name"
        case order = "service_order"
        case isPromo = "is_promo"
        case priceRange = "range_price"
        case orderPriority = "order_priority"
        case merchantVoucherCode = "mvc"
        case isHidden = "ui_rates_hidden"
        case autoSelectShipperProductId = "selected_shipper_product_id"
        case products, texts, cod, error, features
    }

    public enum TextsKeys: String, CodingKey {
        case note = "text_service_notes"
        case description = "text_service_desc"
        case etaDescription = "text_eta_summarize"
        case etaStatusCode = "error_code"
        case courierTickerText = "text_service_ticker"
    }

    public enum CODKeys: String, CodingKey {
        case isCod = "is_cod"
        case text = "cod_text"
    }

    public enum OrderPriortyKeys: String, CodingKey {
        case price
    }

    public enum FeaturesKeys: String, CodingKey {
        case dynamicPrice = "dynamic_price"
    }

    public enum DynamicPriceKeys: String, CodingKey {
        case text = "text_label"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONKeys.self)
        serviceId = try container.decode(Int.self, forKey: .serviceId)
        name = try container.decode(String.self, forKey: .name)
        order = try container.decode(Int.self, forKey: .order)
        isPromo = (try container.decode(Int.self, forKey: .isPromo)) == 1
        products = try container.decode([LogisticRatesServiceProductResponse].self, forKey: .products)
        priceDescription = .range(try container.decode(LogisticRatesServiceRangePriceResponse.self, forKey: .priceRange)) /// The reason why we set default priceDescription type to `.range` is because the `.benefit` case is only intended for LogisticRatesServiceResponses which being initialized from promoStackings response.
        isHidden = try container.decode(Bool.self, forKey: .isHidden)
        autoSelectShipperProductId = try container.decode(ShipmentProductID.self, forKey: .autoSelectShipperProductId)

        let error = try container.decode(LogisticRatesServiceErrorResponse.self, forKey: .error)
        self.error = nil

        let textsContainer = try container.nestedContainer(keyedBy: TextsKeys.self, forKey: .texts)
        note = try textsContainer.decode(String.self, forKey: .note)
        additionalDescription = nil
        courierTickerText = nil

        // eta
        let etaStatus = (try? textsContainer.decode(LogisticRatesEstimatedTimeArrivalStatus.self, forKey: .etaStatusCode)) ?? .notAvailable
        let etaDescription = try textsContainer.decode(String.self, forKey: .etaDescription) ?? ""
        eta = LogisticRatesEstimatedTimeArrivalResponse(status: etaStatus, description: etaDescription)

        let codContainer = try container.nestedContainer(keyedBy: CODKeys.self, forKey: .cod)
        let isCod = try codContainer.decode(Int.self, forKey: .isCod) == 1
        let codText = try codContainer.decode(String.self, forKey: .text)
        codDescription = isCod ? codText : nil
        imageURL = nil
        isEnabled = true
        isFreeShipment = false

        let orderPriorityContainer = try container.nestedContainer(keyedBy: OrderPriortyKeys.self, forKey: .orderPriority)
        orderPriorityPrice = try orderPriorityContainer.decode(Price.self, forKey: .price)

        merchantVoucherCoupon = try container.decode(LogisticRatesMerchantVoucherCoupon.self, forKey: .merchantVoucherCode)

        let featureContainer = try container.nestedContainer(keyedBy: FeaturesKeys.self, forKey: .features)
        let dynamicPriceContainer = try featureContainer.nestedContainer(keyedBy: DynamicPriceKeys.self, forKey: .dynamicPrice)
        dynamicPriceLabelText = try dynamicPriceContainer.decode(String.self, forKey: .text)
        tokonowBenefitDescription = nil
        isBebasOngkirExtra = false
        freeShippingMetadata = ""
        benefitDescription = ""
        boType = .none
        boQuotaText = nil
    }

    /**
     Help create `LogisticRatesServiceResponse` from promo stacking/bbo/free shipment, so it's much easy to handle on view or value calculation.
     Note that we will use Bebas Ongkir / BBO / BO terms interchangably in this project, with BO term being the newest.
     This BO shipment will only have 1 assigned product, so if user chooses this shipment, the courier will be automatically assigned.
     */
    public init?(
        from response: LogisticRatesPromoStackingResponse,
        services: [LogisticRatesServiceResponse]
    ) {
        // isPromo equals to false means that BBO service is unavailable
        guard response.isPromo else { return nil }

        // generate product, either find it on `services` or create one
        let bboProduct: LogisticRatesServiceProductResponse = {
            var selectedProduct: LogisticRatesServiceProductResponse?

            // Iterate through service.products to find a product which its shipperId and shipperProductId equals to the response's shipperId and shipperProductId value. The suitable product will then be assigned as the BO shipment's product.
            for service in services {
                for product in service.products where product.id == response.shipperProductId && product.shipperId == response.shipperId {
                    selectedProduct = product
                }
            }

            // Construct new product for BO shipment if the product isn't found in the services.products response.
            guard let _selectedProduct = selectedProduct else {
                var eta = LogisticRatesEstimatedTimeArrivalResponse(status: .notAvailable, description: "")

                if response.BOType == .tokoNow || response.BOType == .tokoNow15 {
                    eta = LogisticRatesEstimatedTimeArrivalResponse(status: .available, description: response.eta.description)
                }

                return LogisticRatesServiceProductResponse(
                    shipperId: response.shipperId,
                    id: response.shipperProductId,
                    name: response.name,
                    checksum: "",
                    keroUnixTime: "",
                    isRecommended: true,
                    estimation: "",
                    price: response.shipperRate,
                    insurance: LogisticRatesServiceProductInsuranceResponse(
                        price: 0,
                        type: .notSupported,
                        info: "",
                        usedType: false
                    ),
                    onTimeDeliveryGuarantee: .none,
                    merchantVoucherCoupon: LogisticRatesMerchantVoucherCoupon(
                        isMvc: .notEligable,
                        title: "",
                        logoUrl: nil,
                        errorMessage: nil
                    ),
                    cod: LogisticRatesServiceProductCODResponse(text: "", detailURL: nil, detailLabel: ""),
                    error: nil,
                    eta: eta,
                    promoCode: response.promoCode,
                    isHidden: true,
                    benefitAmount: response.totalBenefit,
                    freeShipmentDiscountedPrice: response.discountRate,
                    dynamicPriceLabelText: ""
                )
            }

            var newSelectedProduct = _selectedProduct
            newSelectedProduct.isRecommended = true
            newSelectedProduct.promoCode = response.promoCode
            newSelectedProduct.isHidden = true
            newSelectedProduct.eta = response.eta
            newSelectedProduct.cod = {
                guard response.cod.isAvailable else { return nil }
                return LogisticRatesServiceProductCODResponse(
                    text: response.cod.text,
                    detailURL: response.cod.detailURL,
                    detailLabel: response.cod.detailLabel
                )
            }()
            newSelectedProduct.benefitAmount = response.totalBenefit
            newSelectedProduct.freeShipmentDiscountedPrice = response.discountRate
            newSelectedProduct.price = response.shipperRate

            return newSelectedProduct
        }()

        serviceId = response.serviceId
        name = response.text.bottomSheet
        freeShipmentDisplayName = response.text.chosenCourier
        freeShipmentDescription = response.text.promoMessage
        order = 0
        isPromo = response.isPromo
        priceDescription = .benefit(response.text.bottomSheetDescription)
        products = [bboProduct]
        note = nil
        additionalDescription = nil
        eta = response.eta
        codDescription = {
            guard response.cod.isAvailable else { return nil }
            return response.cod.text
        }()
        error = .none
        orderPriorityPrice = 0
        merchantVoucherCoupon = LogisticRatesMerchantVoucherCoupon(
            isMvc: .notEligable,
            title: "",
            logoUrl: nil,
            errorMessage: nil
        )
        imageURL = response.imageURL
        isEnabled = !response.isDisabled
        isFreeShipment = true
        isHidden = false
        autoSelectShipperProductId = bboProduct.id
        dynamicPriceLabelText = ""
        tokonowBenefitDescription = {
            if response.BOType == .tokoNow || response.BOType == .tokoNow15 {
                return response.benefitDecription
            }
            return nil
        }()
        isBebasOngkirExtra = response.isBebasOngkirExtra
        freeShippingMetadata = ""
        benefitDescription = response.benefitDecription
        boType = response.BOType
        boQuotaText = response.quotaText
        courierTickerText = nil // set to nil because bebas ongkir service won't let user choose its own courier (courier picker entry point will be hidden in the UI)
    }
}

public struct LogisticRatesServiceProductResponse {
    public let shipperId: ShipmentID
    public let id: ShipmentProductID
    public let name: String
    public let checksum: String
    public let keroUnixTime: KeroUnixTimeID

    /**
     determining default selection
     */
    public var isRecommended: Bool
    public let estimation: String
    public var price: Price
    public let insurance: LogisticRatesServiceProductInsuranceResponse
    public var onTimeDeliveryGuarantee: LogisticRatesServiceOnTimeDelivery?
    public var merchantVoucherCoupon: LogisticRatesMerchantVoucherCoupon
    public var cod: LogisticRatesServiceProductCODResponse?
    public let error: LogisticRatesServiceErrorResponse?
    public var eta: LogisticRatesEstimatedTimeArrivalResponse

    /**
     Helper function when BBO product combined as one with this response, this value to help bring BBO promo code for calculation purpose
     */
    public var promoCode: String?
    /**
     Helper function when BBO product combined as one with this repsonse, this value will help hide it on view.
     indicate it to diffrenciate with normal product
     */
    public var isHidden: Bool
    /**
     Always zero if not a BBO(free shipment). this is the amount on tokopedia side to discount the shipment price.
     */
    public var benefitAmount: Price
    public var freeShipmentDiscountedPrice: Price

    /**
     Helper variable determine if current product is BBO or not
     */
    public var isFreeShipment: Bool {
        promoCode != nil && isHidden == true
    }

    public let dynamicPriceLabelText: String

    public var orderMessage: String?

    public init(
        shipperId: ShipmentID,
        id: ShipmentProductID,
        name: String,
        checksum: String,
        keroUnixTime: KeroUnixTimeID,
        isRecommended: Bool,
        estimation: String,
        price: Price,
        insurance: LogisticRatesServiceProductInsuranceResponse,
        onTimeDeliveryGuarantee: LogisticRatesServiceOnTimeDelivery? = nil,
        merchantVoucherCoupon: LogisticRatesMerchantVoucherCoupon,
        cod: LogisticRatesServiceProductCODResponse? = nil,
        error: LogisticRatesServiceErrorResponse?,
        eta: LogisticRatesEstimatedTimeArrivalResponse,
        promoCode: String? = nil,
        isHidden: Bool,
        benefitAmount: Price,
        freeShipmentDiscountedPrice: Price,
        dynamicPriceLabelText: String,
        orderMessage: String? = nil
    ) {
        self.shipperId = shipperId
        self.id = id
        self.name = name
        self.checksum = checksum
        self.keroUnixTime = keroUnixTime
        self.isRecommended = isRecommended
        self.estimation = estimation
        self.price = price
        self.insurance = insurance
        self.onTimeDeliveryGuarantee = onTimeDeliveryGuarantee
        self.merchantVoucherCoupon = merchantVoucherCoupon
        self.cod = cod
        self.error = error
        self.eta = eta
        self.promoCode = promoCode
        self.isHidden = isHidden
        self.benefitAmount = benefitAmount
        self.freeShipmentDiscountedPrice = freeShipmentDiscountedPrice
        self.dynamicPriceLabelText = dynamicPriceLabelText
        self.orderMessage = orderMessage
    }
}

public struct LogisticRatesServiceProductInsuranceResponse: Decodable, Equatable {
    public let price: Price
    public let type: LogisticRatesServiceProductInsuranceTypeResponse
    public let info: String
    public let usedType: Bool

    public enum JSONKeys: String, CodingKey {
        case price = "insurance_price"
        case type = "insurance_type"
        case usedType = "insurance_used_type"
        case info = "insurance_used_info"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONKeys.self)

        price = try container.decode(Price.self, forKey: .price)
        info = try container.decode(String.self, forKey: .info)

        let insuranceType = try container.decode(Int.self, forKey: .type)
        usedType = try container.decode(Int.self, forKey: .usedType) == 2

        if insuranceType == 3 {
            type = .required
        } else if insuranceType == 2 {
            type = .optional(isSelected: usedType)
        } else {
            type = .notSupported
        }
    }

    public init(
        price: Price,
        type: LogisticRatesServiceProductInsuranceTypeResponse,
        info: String,
        usedType: Bool
    ) {
        self.price = price
        self.type = type
        self.info = info
        self.usedType = usedType
    }
}

public enum LogisticRatesServiceProductInsuranceTypeResponse: Equatable {
    case optional(isSelected: Bool)
    case required
    case notSupported
}

public struct LogisticRatesServiceOnTimeDelivery: Decodable, Equatable {
    public let text: String
    public let urlText: String
    
    public var iconURL: URL?

    public var detailURL: URL?

    public let amount: Int

    public enum CodingKeys: String, CodingKey {
        case text = "text_label"
        case urlText = "url_text"
        case iconURL = "icon_url"
        case detailURL = "url_detail"
        case amount = "value"
    }

    public init(
        text: String,
        urlText: String,
        iconURL: URL?,
        detailURL: URL?,
        amount: Int
    ) {
        self.text = text
        self.urlText = urlText
        self.iconURL = iconURL
        self.detailURL = detailURL
        self.amount = amount
    }
}

public struct LogisticRatesServiceProductCODResponse: Decodable, Equatable {
    public let text: String

    public var detailURL: URL?
    public let detailLabel: String

    public enum CodingKeys: String, CodingKey {
        case text = "cod_text"
        case detailURL = "tnc_link"
        case detailLabel = "tnc_text"
    }

    public init(text: String, detailURL: URL?, detailLabel: String) {
        self.text = text
        self.detailURL = detailURL
        self.detailLabel = detailLabel
    }
}

public struct LogisticRatesServiceErrorResponse: Decodable, Equatable {
    public let id: String
    public let message: String

    public enum CodingKeys: String, CodingKey {
        case id = "error_id"
        case message = "error_message"
    }

    public init(id: String, message: String) {
        self.id = id
        self.message = message
    }
}

public struct LogisticRatesEstimatedTimeArrivalResponse: Equatable {
    public var status: LogisticRatesEstimatedTimeArrivalStatus
    public var description: String

    public init(status: LogisticRatesEstimatedTimeArrivalStatus, description: String) {
        self.status = status
        self.description = description
    }
}

public typealias KeroUnixTimeID = String

// MARK: - Extensions -

extension LogisticRatesServiceProductResponse: Decodable, Equatable {
    public enum JSONKeys: String, CodingKey {
        case shipperId = "shipper_id"
        case id = "shipper_product_id"
        case name = "shipper_name"
        case isRecommended = "recommend"
        case keroUnixTime = "ut"

        /**
         a flag from BE to hide product.
         currently for `Swift` shipment.

         it's valid as data, but not pickable shipment by user.
         on `Swift` case, the shipment will be used for free shipment
         */
        case hideProduct = "ui_rates_hidden"
        case texts, price, insurance, features, checksum, cod, error, eta
        case orderMessage = "order_message"
    }

    public enum PriceKeys: String, CodingKey {
        case price
    }

    public enum TextsKeys: String, CodingKey {
        case estimation = "text_etd"
        case formattedPrice = "text_price"
    }

    public enum FeaturesKeys: String, CodingKey {
        case onTimeDeliveryGuarantee = "ontime_delivery_guarantee"
        case merchantVoucherCoupon = "mvc"
        case dynamicPrice = "dynamic_price"
    }

    public enum OnTimeDeliveryKeys: String, CodingKey {
        case available
    }

    public enum CashOnDeliveryKeys: String, CodingKey {
        case available = "is_cod_available"
    }

    public enum DynamicPriceKeys: String, CodingKey {
        case text = "text_label"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONKeys.self)
        id = try container.decode(ShipmentProductID.self, forKey: .id)
        shipperId = try container.decode(ShipmentID.self, forKey: .shipperId)
        name = try container.decode(String.self, forKey: .name)
        checksum = try container.decode(String.self, forKey: .checksum)
        keroUnixTime = try container.decode(KeroUnixTimeID.self, forKey: .keroUnixTime)
        isRecommended = try container.decode(Bool.self, forKey: .isRecommended)
        insurance = try container.decode(LogisticRatesServiceProductInsuranceResponse.self, forKey: .insurance)
        eta = try container.decode(LogisticRatesEstimatedTimeArrivalResponse.self, forKey: .eta)
        orderMessage = try container.decodeIfPresent(String.self, forKey: .orderMessage)

        let textsContainer = try container.nestedContainer(keyedBy: TextsKeys.self, forKey: .texts)
        estimation = try textsContainer.decode(String.self, forKey: .estimation)

        let priceContainer = try container.nestedContainer(keyedBy: PriceKeys.self, forKey: .price)
        price = try priceContainer.decode(Price.self, forKey: .price)

        let featureContainer = try container.nestedContainer(keyedBy: FeaturesKeys.self, forKey: .features)
        let onTimeDeliveryContainer = try featureContainer.nestedContainer(keyedBy: OnTimeDeliveryKeys.self, forKey: .onTimeDeliveryGuarantee)
        let isOnTimeDeliveryAvailable = try onTimeDeliveryContainer.decode(Bool.self, forKey: .available)

        onTimeDeliveryGuarantee = isOnTimeDeliveryAvailable ?
            try featureContainer.decode(LogisticRatesServiceOnTimeDelivery.self, forKey: .onTimeDeliveryGuarantee)
            :
            nil

        merchantVoucherCoupon = try featureContainer.decode(LogisticRatesMerchantVoucherCoupon.self, forKey: .merchantVoucherCoupon)

        let dynamicPriceContainer = try featureContainer.nestedContainer(keyedBy: DynamicPriceKeys.self, forKey: .dynamicPrice)
        dynamicPriceLabelText = try dynamicPriceContainer.decode(String.self, forKey: .text)

        let codContainer = try container.nestedContainer(keyedBy: CashOnDeliveryKeys.self, forKey: .cod)
        let isCODAvailable = try codContainer.decode(Int.self, forKey: .available) == 1

        cod = isCODAvailable ?
            try container.decode(LogisticRatesServiceProductCODResponse.self, forKey: .cod)
            :
            nil

        let error = try container.decode(LogisticRatesServiceErrorResponse.self, forKey: .error)
        let errorValueValid = error.id
        self.error = nil

        promoCode = nil

        /**
         a flag from BE to hide product.
         currently for `Swift` shipment.

         it's valid as data, but not pickable by user.
         on `Swift` case, the shipment will be used for free shipment
         */
        isHidden = try container.decode(Bool.self, forKey: .hideProduct)
        benefitAmount = 0
        freeShipmentDiscountedPrice = 0
    }
}

extension LogisticRatesEstimatedTimeArrivalResponse: Decodable {
    public enum CodingKeys: String, CodingKey {
        case status = "error_code"
        case description = "text_eta"
    }
}

public struct LogisticRatesPromoStackingResponse: Decodable, Equatable {
    public struct COD: Decodable, Equatable {
        public var isAvailable: Bool
        public let text: String
        public let price: Price

        public var detailURL: URL?
        public let detailLabel: String

        public enum CodingKeys: String, CodingKey {
            case isAvailable = "is_cod_available"
            case text = "cod_text"
            case price = "cod_price"
            case detailURL = "tnc_link"
            case detailLabel = "tnc_text"
        }

        public init(isAvailable: Bool, text: String, price: Price, detailURL: URL?, detailLabel: String) {
            self.isAvailable = isAvailable
            self.text = text
            self.price = price
            self.detailURL = detailURL
            self.detailLabel = detailLabel
        }
    }

    public struct Text: Decodable, Equatable {
        public let bottomSheet: String
        public let chosenCourier: String
        public let bottomSheetDescription: String
        public let promoMessage: String

        public var titlePromoMessage: String?

        public var orderMessage: String?

        public enum CodingKeys: String, CodingKey {
            case bottomSheet = "bottom_sheet"
            case chosenCourier = "chosen_courier"
            case bottomSheetDescription = "bottom_sheet_description"
            case promoMessage = "promo_message"
            case titlePromoMessage = "title_promo_message"
            case orderMessage = "order_message"
        }

        public init(
            bottomSheet: String,
            chosenCourier: String,
            bottomSheetDescription: String,
            promoMessage: String,
            titlePromoMessage: String? = nil,
            orderMessage: String? = nil
        ) {
            self.bottomSheet = bottomSheet
            self.chosenCourier = chosenCourier
            self.bottomSheetDescription = bottomSheetDescription
            self.promoMessage = promoMessage
            self.titlePromoMessage = titlePromoMessage
            self.orderMessage = orderMessage
        }
    }

    public var serviceId: Int
    public let shipperId: ShipmentID
    public let shipperProductId: ShipmentProductID
    public let name: String
    public let isBebasOngkirExtra: Bool

    public var isPromo: Bool
    public var promoCode: String
    public let title: String
    public let shipperRate: Price
    public let discountRate: Price
    public let totalBenefit: Price
    public let benefitDecription: String
    public let isDisabled: Bool

    public var imageURL: URL?

    /*
     The image URL for the chosen BO courier.

     It will be use for checkout revamp experience to show BO logo in shipping widget
     note that the value of this field should be always available
     unlike imageURL that only available for the first BO.
     */
    public var chosenImageURL: URL?

    /*
     This field will be use to show BO (Bebas Ongkir) quota text beside free shipment logo
     */
    public var quotaText: String?

    public var eta: LogisticRatesEstimatedTimeArrivalResponse
    public var cod: COD
    public var text: Text
    public var BOType: BOType
    public var freeShippingMetadata: FreeShippingMetadata
    public var boCampaignId: Int

    public init(
        serviceId: Int,
        shipperId: ShipmentID,
        shipperProductId: ShipmentProductID,
        name: String,
        isBebasOngkirExtra: Bool,
        isPromo: Bool,
        promoCode: String,
        title: String,
        shipperRate: Price,
        discountRate: Price,
        totalBenefit: Price,
        benefitDecription: String,
        isDisabled: Bool,
        imageURL: URL?,
        chosenImageURL: URL?,
        quotaText: String,
        eta: LogisticRatesEstimatedTimeArrivalResponse,
        cod: LogisticRatesPromoStackingResponse.COD,
        text: LogisticRatesPromoStackingResponse.Text,
        BOType: BOType,
        freeShippingMetadata: FreeShippingMetadata,
        boCampaignId: Int
    ) {
        self.serviceId = serviceId
        self.shipperId = shipperId
        self.shipperProductId = shipperProductId
        self.name = name
        self.isBebasOngkirExtra = isBebasOngkirExtra
        self.isPromo = isPromo
        self.promoCode = promoCode
        self.title = title
        self.shipperRate = shipperRate
        self.discountRate = discountRate
        self.totalBenefit = totalBenefit
        self.benefitDecription = benefitDecription
        self.isDisabled = isDisabled
        self.imageURL = imageURL
        self.chosenImageURL = chosenImageURL
        self.quotaText = quotaText
        self.eta = eta
        self.cod = cod
        self.text = text
        self.BOType = BOType
        self.freeShippingMetadata = freeShippingMetadata
        self.boCampaignId = boCampaignId
    }
}

public enum BOType: Int, Decodable {
    /**
     BOType Glossary:
     - none: no bebas ongkir
     - bebasOngkir : normal bebas ongkir, non DT product
     - bebasOngkirExtra: normal bebas ongkir, DT product
     - bebasOngkirPlus: bebas ongkir, non DT product, and with PLUS subscription
     - bebasOngkirPlusFulfillment: bebas ongkir, DT product, and with PLUS subscription
     - tokoNow: bebas ongkir, NOW 2 hours service
     - tokoNow15: bebas ongkir, NOW 15mins service

     Both Fulfillment and TokoCabang (TC) terms were rebranded into DilayaniTokopedia (DT) term.
     */
    case none = 0
    case bebasOngkir = 1
    case bebasOngkirExtra = 2
    case tokoNow = 3
    case tokoNow15 = 4
    case bebasOngkirPlus = 5
    case bebasOngkirPlusFulfillment = 6

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let typeInt = try container.decode(Int.self)

        switch typeInt {
        case 1: self = .bebasOngkir
        case 2: self = .bebasOngkirExtra
        case 3: self = .tokoNow
        case 4: self = .tokoNow15
        case 5: self = .bebasOngkirPlus
        case 6: self = .bebasOngkirPlusFulfillment
        default: self = .none
        }
    }
}

public struct FreeShippingMetadata: Codable, Equatable {
    public let sentShipperPartner: Bool
    public let benefitClass: String
    public let shippingSubsidy: Int
    public let additionalData: String

    public enum CodingKeys: String, CodingKey {
        case sentShipperPartner = "sent_shipper_partner"
        case benefitClass = "benefit_class"
        case shippingSubsidy = "shipping_subsidy"
        case additionalData = "additional_data"
    }

    public init(sentShipperPartner: Bool, benefitClass: String, shippingSubsidy: Int, additionalData: String) {
        self.sentShipperPartner = sentShipperPartner
        self.benefitClass = benefitClass
        self.shippingSubsidy = shippingSubsidy
        self.additionalData = additionalData
    }
}

// MARK: - Extensions -

extension LogisticRatesPromoStackingResponse {
    public enum CodingKeys: String, CodingKey {
        case serviceId = "service_id"
        case shipperId = "shipper_id"
        case shipperProductId = "shipper_product_id"
        case name = "shipper_name"
        case isPromo = "is_promo"
        case promoCode = "promo_code"
        case title
        case shipperRate = "shipping_rate"
        case discountRate = "discounted_rate"
        case totalBenefit = "benefit_amount"
        case imageURL = "image_url"
        case chosenImageURL = "image_url_chosen"
        case quotaText = "quota_message"
        case isDisabled = "disabled"
        case benefitDecription = "benefit_desc"
        case eta, cod
        case text = "texts"
        case isBebasOngkirExtra = "is_bebas_ongkir_extra"
        case BOType = "bo_type"
        case freeShippingMetadata = "free_shipping_metadata"
        case boCampaignId = "bo_campaign_id"
    }
}

public struct LogisticRatesServiceRangePriceResponse: Decodable, Equatable {
    public let lowerValue: Price
    public let upperValue: Price

    public enum CodingKeys: String, CodingKey {
        case lowerValue = "min_price"
        case upperValue = "max_price"
    }

    public init(lowerValue: Price, upperValue: Price) {
        self.lowerValue = lowerValue
        self.upperValue = upperValue
    }
}

internal struct ShipmentAddressFormChosenAddressParams: Equatable {
    internal var mode: Int
    internal var addressId: Int?
    internal var districtId: Int?
    internal var postalCode: String
    internal var geolocation: String
    internal let tokonow: LocalizedAddress.TokoNow
}

extension ShipmentAddressFormChosenAddressParams: Encodable {
    internal enum CodingKeys: String, CodingKey {
        case mode
        case addressId = "address_id"
        case districtId = "district_id"
        case postalCode = "postal_code"
        case geolocation
        case tokonow
    }
}

public struct ShipmentAddressFormPromoAdditionalInfo {
    public struct ShipmentBenefit: Codable, Equatable {
        public let benefitAmount: Price
        public let shipmentProductId: ShipmentProductID

        public enum CodingKeys: String, CodingKey {
            case benefitAmount = "benefit_amount"
            case shipmentProductId = "sp_id"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            benefitAmount = try container.decode(Price.self, forKey: .benefitAmount)
            shipmentProductId = try container.decode(ShipmentProductID.self, forKey: .shipmentProductId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(benefitAmount, forKey: .benefitAmount)
            try container.encode(shipmentProductId, forKey: .shipmentProductId)
        }

        public init(benefitAmount: Price, shipmentProductId: ShipmentProductID) {
            self.benefitAmount = benefitAmount
            self.shipmentProductId = shipmentProductId
        }
    }

    public let promoShipments: [CartOrderID: [ShipmentAddressFormPromoAdditionalInfo.ShipmentBenefit]]
    public var messageInfo: ShipmentAddressFormPromoMessageInfo?
    public let usageSummaries: [ShipmentAddressFormPromoUsageSummaries]
    public let autoApplied: Bool
    public let isBOUnstackEnabled: Bool

    public init(
        promoShipments: [CartOrderID: [ShipmentBenefit]],
        messageInfo: ShipmentAddressFormPromoMessageInfo,
        usageSummaries: [ShipmentAddressFormPromoUsageSummaries],
        autoApplied: Bool,
        isBOUnstackEnabled: Bool
    ) {
        self.promoShipments = promoShipments
        self.messageInfo = messageInfo
        self.usageSummaries = usageSummaries
        self.autoApplied = autoApplied
        self.isBOUnstackEnabled = isBOUnstackEnabled
    }
}

public struct ShipmentAddressFormPromoMessageInfo: Decodable, Equatable {
    public var message: String

    public var detail: String?

    public enum CodingKeys: String, CodingKey {
        case message, detail
    }

    public init(message: String, detail: String? = nil) {
        self.message = message
        self.detail = detail
    }
}

public struct ShipmentAddressFormPromoUsageSummaries: Decodable, Equatable {
    public let description: String
    public let type: String
    public let amount: Price
    public let currencyDetailsString: String

    public enum CodingKeys: String, CodingKey {
        case description, type, amount
        case currencyDetailsString = "currency_details_str"
    }

    public init(
        description: String,
        type: String,
        amount: Price,
        currencyDetailsString: String
    ) {
        self.description = description
        self.type = type
        self.amount = amount
        self.currencyDetailsString = currencyDetailsString
    }
}

public struct BOMetadataWrapper: Codable, Equatable {
    public let BOMetadata: ShipmentAddressFormOrderBOMetadata

    public enum CodingKeys: String, CodingKey {
        case BOMetadata = "bo_metadata"
    }

    public init(BOMetadata: ShipmentAddressFormOrderBOMetadata) {
        self.BOMetadata = BOMetadata
    }
}

public struct ShipmentAddressFormOrderBOMetadata: Codable, Equatable {
    public struct BOEligibilities: Codable, Equatable {
        public let key: String
        public let value: String

        public enum CodingKeys: String, CodingKey {
            case key
            case value
        }

        public init(key: String, value: String) {
            self.key = key
            self.value = value
        }
    }

    public let type: Int
    public let eligibilities: [BOEligibilities]

    public enum CodingKeys: String, CodingKey {
        case type = "bo_type"
        case eligibilities = "bo_eligibilities"
    }

    public init(type: Int, eligibilities: [ShipmentAddressFormOrderBOMetadata.BOEligibilities]) {
        self.type = type
        self.eligibilities = eligibilities
    }
}

// MARK: - Extensions -

public struct LogisticRatesParams: Equatable {
    public enum LogisticRatesTradeInMode: Int {
        case notTradeIn = 0
        case tradeIn = 1
        case tradeInDropOff = 2
    }

    public var shipperProductIds: [ShipmentProductID]
    public var shopId: ShipmentShopID
    public var shopLocation: LogisticRatesLocationParams
    public var destinationLocation: LogisticRatesLocationParams

    public var totalWeight: Weight
    public var actualWeight: Weight
    public var keroToken: String
    public var keroUnixTime: String
    public var isAnyProductForceInsurance: Bool

    /**
     Total Qty * product price
     */
    public var orderValue: Price
    public var productCatId: [Int]
    public var addressId: AddressID
    public var isPreorder: Bool

    // also known as pslCode, bbo stands for bebas ongkir (free shipment)
    public var bboCodes: String

    public var products: [LogisticRatesProductParams]
    public var cartUniqueIndentifier: CartOrderID
    public var isTradeIn: LogisticRatesTradeInMode
    public var isVehicleLeasing: Bool

    public var preOrderDuration: Int
    public var isFulfillment: Bool

    /**
     number of cod (cash on delivery) count ?
     */
    public var userHistory: Int
    public var merchantVoucherCoupons: [ShipmentAddressFormPromoAdditionalInfo.ShipmentBenefit]
    public var shopTier: Int
    public var warehouseId: ShipmentWarehouseID

    // Free shipping metadata
    public var BOMetadata: ShipmentAddressFormOrderBOMetadata

    /// ShipperPicker page source. Current possible values are `Checkout` or `OCC`.
    public var shipperPickerSource: ShipperPickerSource

    public var groupType: GroupType

    public var groupMetadata: String

    public let groupingState: GroupingState?

    public init(
        shipperProductIds: [ShipmentProductID],
        shopId: ShipmentShopID,
        shopLocation: LogisticRatesLocationParams,
        destinationLocation: LogisticRatesLocationParams,
        totalWeight: Weight,
        actualWeight: Weight,
        keroToken: String,
        keroUnixTime: String,
        isAnyProductForceInsurance: Bool,
        orderValue: Price,
        productCatId: [Int],
        addressId: AddressID,
        isPreorder: Bool,
        bboCodes: String,
        products: [LogisticRatesProductParams],
        cartUniqueIndentifier: CartOrderID,
        isTradeIn: LogisticRatesParams.LogisticRatesTradeInMode,
        isVehicleLeasing: Bool,
        preOrderDuration: Int,
        isFulfillment: Bool,
        userHistory: Int,
        merchantVoucherCoupons: [ShipmentAddressFormPromoAdditionalInfo.ShipmentBenefit],
        shopTier: Int,
        warehouseId: ShipmentWarehouseID,
        BOMetadata: ShipmentAddressFormOrderBOMetadata,
        shipperPickerSource: ShipperPickerSource,
        groupType: GroupType,
        groupMetadata: String = "",
        groupingState: GroupingState? = .normal
    ) {
        self.shipperProductIds = shipperProductIds
        self.shopId = shopId
        self.shopLocation = shopLocation
        self.destinationLocation = destinationLocation
        self.totalWeight = totalWeight
        self.actualWeight = actualWeight
        self.keroToken = keroToken
        self.keroUnixTime = keroUnixTime
        self.isAnyProductForceInsurance = isAnyProductForceInsurance
        self.orderValue = orderValue
        self.productCatId = productCatId
        self.addressId = addressId
        self.isPreorder = isPreorder
        self.bboCodes = bboCodes
        self.products = products
        self.cartUniqueIndentifier = cartUniqueIndentifier
        self.isTradeIn = isTradeIn
        self.isVehicleLeasing = isVehicleLeasing
        self.preOrderDuration = preOrderDuration
        self.isFulfillment = isFulfillment
        self.userHistory = userHistory
        self.merchantVoucherCoupons = merchantVoucherCoupons
        self.shopTier = shopTier
        self.warehouseId = warehouseId
        self.BOMetadata = BOMetadata
        self.shipperPickerSource = shipperPickerSource
        self.groupType = groupType
        self.groupMetadata = groupMetadata
        self.groupingState = groupingState
    }
}

extension LogisticRatesParams: Encodable {
    public enum CodingKeys: String, CodingKey {
        case shipperProductIds = "spids"
        case shopId = "shop_id"
        case shopLocation = "origin"
        case destinationLocation = "destination"
        case totalWeight = "weight"
        case actualWeight = "actual_weight"
        case keroToken = "token"
        case keroUnixTime = "ut"
        case isproductInsurance = "product_insurance"
        case orderValue = "order_value"
        case productCatId = "cat_id"
        case addressId = "address_id"
        case isPreorder = "preorder"
        case products
        case bboCodes = "psl_code"
        case cartUniqueIndentifier = "unique_id"
        case insurance
        case from
        case type
        case blackbox = "is_blackbox"
        case os = "os_type"
        case isPdp = "pdp"
        case languange = "lang"
        case isTradeIn = "trade_in"
        case isVehicleLeasing = "vehicle_leasing"
        case preOrderDuration = "po_time"
        case isFulfillment = "is_fulfillment"
        case userHistory = "user_history"
        case isOneClickCheckout = "occ"
        case merchantVoucherCoupons = "mvc"
        case shopTier = "shop_tier"
        case warehouseId = "warehouse_id"
        case BOMetadata = "bo_metadata"
        case groupType = "group_type"
        case groupMetadata = "group_metadata"
        case groupingState = "grouping_state"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // hardcoded value
        try container.encode("client", forKey: .from)
        try container.encode("ios", forKey: .type)
        try container.encode("id", forKey: .languange)
        try container.encode(0, forKey: .blackbox)
        try container.encode("0", forKey: .isPdp)
        try container.encode("2", forKey: .os)
        try container.encode(shipperPickerSource.isOneClickCheckout ? "1" : "0", forKey: .isOneClickCheckout)
        /**
         Old value, default previous RN page is 1
         https://tokopedia.slack.com/archives/G013C736QL9/p1593434287017200?thread_ts=1593432482.016900&cid=G013C736QL9
         */
        try container.encode("1", forKey: .insurance)

        try container.encode(shipperProductIds.map(String.init).joined(separator: ","), forKey: .shipperProductIds)
        try container.encode(String(shopId), forKey: .shopId)
        try container.encode(shopLocation.formatted, forKey: .shopLocation)
        try container.encode(destinationLocation.formatted, forKey: .destinationLocation)
        try container.encode(String(1), forKey: .totalWeight)
        try container.encode(String(2), forKey: .actualWeight)
        try container.encode(keroToken, forKey: .keroToken)
        try container.encode(keroUnixTime, forKey: .keroUnixTime)
        try container.encode(isAnyProductForceInsurance ? "1" : "0", forKey: .isproductInsurance)
        try container.encode(String(orderValue), forKey: .orderValue)
        try container.encode(productCatId.map(String.init).joined(separator: ","), forKey: .productCatId)
        try container.encode(String(addressId), forKey: .addressId)
        try container.encode(isPreorder ? 1 : 0, forKey: .isPreorder)
        try container.encode("", forKey: .products)
        try container.encode(bboCodes, forKey: .bboCodes)
        try container.encode(cartUniqueIndentifier, forKey: .cartUniqueIndentifier)
        try container.encode(isTradeIn.rawValue, forKey: .isTradeIn)
        try container.encode(isVehicleLeasing ? 1 : 0, forKey: .isVehicleLeasing)
        try container.encode(preOrderDuration, forKey: .preOrderDuration)
        try container.encode(isFulfillment, forKey: .isFulfillment)
        try container.encode(userHistory, forKey: .userHistory)
        try container.encode(shopTier, forKey: .shopTier)
        try container.encode(String(warehouseId), forKey: .warehouseId)
        try container.encode(groupType.rawValue, forKey: .groupType)
        try container.encode(groupMetadata, forKey: .groupMetadata)
        try container.encode(groupingState?.rawValue ?? 0, forKey: .groupingState)

        json_merchant_voucher_coupons: do {
            let jsonData = try JSONEncoder().encode(merchantVoucherCoupons)
            let jsonString = String(data: jsonData, encoding: .utf8)

            if let jsonString = jsonString {
                try container.encode(jsonString, forKey: .merchantVoucherCoupons)
            }
        }

        json_bo_metadata: do {
            let data = BOMetadataWrapper(BOMetadata: BOMetadata)

            let jsonData = try JSONEncoder().encode(data)
            let jsonString = String(data: jsonData, encoding: .utf8)

            if let jsonString = jsonString {
                try container.encode(jsonString, forKey: .BOMetadata)
            }
        }
    }
}

extension ShipmentAddressFormPromoAdditionalInfo: Decodable, Equatable {
    public struct PromoShipment: Decodable, Equatable {
        public let uniqueId: CartOrderID
        public let shipmentBenefits: [ShipmentAddressFormPromoAdditionalInfo.ShipmentBenefit]

        public enum CodingKeys: String, CodingKey {
            case uniqueId = "unique_id"
            case shipmentBenefits = "mvc_shipping_benefits"
        }

        public init(uniqueId: CartOrderID, shipmentBenefits: [ShipmentAddressFormPromoAdditionalInfo.ShipmentBenefit]) {
            self.uniqueId = uniqueId
            self.shipmentBenefits = shipmentBenefits
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            uniqueId = try container.decode(CartOrderID.self, forKey: .uniqueId)
            shipmentBenefits = try container.decode([ShipmentAddressFormPromoAdditionalInfo.ShipmentBenefit].self, forKey: .shipmentBenefits)
        }
    }

    public enum CodingKeys: String, CodingKey {
        case promoShipments = "promo_sp_ids"
        case messageInfo = "message_info"
        case usageSummaries = "usage_summaries"
        case autoApplied = "poml_auto_applied"
        case boInfo = "bebas_ongkir_info"
    }

    public enum BOInfoCodingKeys: String, CodingKey {
        case isBOUnstackEnabled = "is_bo_unstack_enabled"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        messageInfo = try? container.decode(ShipmentAddressFormPromoMessageInfo.self, forKey: .messageInfo)
        usageSummaries = try container.decode([ShipmentAddressFormPromoUsageSummaries].self, forKey: .usageSummaries)

        var promoShipmentInDictionary = [CartOrderID: [ShipmentBenefit]]()
        try container.decode([PromoShipment].self, forKey: .promoShipments).forEach { promoShipment in
            promoShipmentInDictionary[promoShipment.uniqueId] = (promoShipmentInDictionary[promoShipment.uniqueId] ?? []) + promoShipment.shipmentBenefits
        }

        promoShipments = promoShipmentInDictionary
        autoApplied = try container.decode(Bool.self, forKey: .autoApplied)

        let boInfo = try container.nestedContainer(keyedBy: BOInfoCodingKeys.self, forKey: .boInfo)

        isBOUnstackEnabled = try boInfo.decode(Bool.self, forKey: .isBOUnstackEnabled)
    }
}

public struct RatesMetadata: Equatable {
    public let cartData: String

    public init(cartData: String) {
        self.cartData = cartData
    }

    public func toDictionary() -> [String: Any] {
        return ["cart_data": cartData]
    }
}

public struct LogisticRatesLocationParams: Encodable, Equatable {
    public let districtId: Int
    public let postalCode: String
    public var latitude: String
    public var longitude: String

    /**
     Format LogisticRatesLocationParams value to be used on fetching logistic rates
     https://tokopedia.atlassian.net/wiki/spaces/LG/pages/567279712/Rates+V3
     */
    public var formatted: String {
        "\(String(districtId))|\(String(postalCode))|\(latitude),\(longitude)"
    }

    public init(districtId: Int, postalCode: String, latitude: String, longitude: String) {
        self.districtId = districtId
        self.postalCode = postalCode
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct Weight: Equatable, Decodable {
    /**
     Raw value weight in grams
     */
    public private(set) var rawValue: Float

    /**
     value in gram
     */
    public init(gram: Float = 0) {
        rawValue = gram
    }

    /**
     Init weight from kilogram
     */
    public init(kilogram: Float = 0) {
        rawValue = kilogram * 1000
    }
}

public struct LogisticRatesProductParams: Encodable, Equatable {
    public let productId: ShipmentProductID
    public var isFreeShipping: Bool
    public let isFreeShippingTc: Bool

    public enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case isFreeShipping = "is_free_shipping"
        case isFreeShippingTc = "is_free_shipping_tc"
    }

    public init(productId: ShipmentProductID, isFreeShipping: Bool, isFreeShippingTc: Bool) {
        self.productId = productId
        self.isFreeShipping = isFreeShipping
        self.isFreeShippingTc = isFreeShippingTc
    }
}

public typealias ShipmentWarehouseID = Int
public enum ShipperPickerSource {
    case checkout
    case occ

    // Currently, Tokopedia app only has 2 page sources for opening the ShipperPicker bottom sheet, which are `Checkout` and `OCC` page.
    // If there are new page sources in the future, its highly advised that we change `source` value type from Bool to another type (ex: Int) to accomodate with the new page sources.
    public var isOneClickCheckout: Bool {
        return self == .occ
    }
}

public enum GroupType: Int, Codable {
    case `default` = 1
    case owoc = 2
    case ofocSingleShop = 3
    case ofocMultiShop = 4

    public init(from decoder: Decoder) throws {
        let groupTypeInt = try decoder.singleValueContainer().decode(Int.self)
        self = GroupType(rawValue: groupTypeInt) ?? .default
    }
}

public enum GroupingState: Int, Codable {
    case normal
    case merged
    case split
}
