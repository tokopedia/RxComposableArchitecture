//
//  CheckoutViewController+Reducer.swift
//  Checkout
//
//  Created by Wendy Liga on 14/08/20.
//

import Foundation
import RxComposableArchitecture

internal enum OverlayMode: Equatable {
    case overlayLoading
    case dialog(DialogData)
    case prescriptionAttached(DialogData)
}

internal enum ViewMode: Equatable {
    case shimmerLoading
    case error(EmptyStateData)
    case normal(overlay: OverlayMode?)
}

/**
 Will show coach mark based on cases
 */
internal enum CoachMarkTarget: Equatable {
    case address
    case orderShipment(identifier: CartOrderID)
    case orderScheduledShipment(identifier: CartOrderID, userID: String)
    case attachPrescription(userId: String)
    case plusShipment(identifier: CartOrderID, userID: String, title: String, message: String)

    internal var title: String {
        switch self {
        case .address:
            return "Alamat Pengiriman"
        case .orderShipment:
            return "Pilih Durasi Pengiriman"
        case .orderScheduledShipment:
            return "Bisa atur kapan pesanan tiba sesuai kebutuhan 😄"
        case .attachPrescription:
            return "Pesanan obat kerasmu butuh resep"
        case let .plusShipment(_, _, title, _):
            return title
        }
    }

    internal var message: String {
        switch self {
        case .address:
            return "Pastikan alamat pengiriman sudah sesuai dengan yang kamu inginkan."
        case .orderShipment:
            return "Pilih jangka waktu pengiriman yang didukung oleh toko ini."
        case .orderScheduledShipment:
            return "Tersedia khusus pesanan Tokopedia NOW!"
        case .attachPrescription:
            return "Yuk, upload resepmu. Kalau belum punya, chat dokter buat dapetin resep digital juga bisa~"
        case let .plusShipment(_, _, _, message):
            return message
        }
    }
}

/**
 Target to scroll for get user attention and focus on
 */
internal enum FocusTarget: Equatable {
    case address
    case orderShipment(index: Int)
    case orderDropshipper(index: Int)
    case uploadPrescription
    case disabledProduct(orderIndex: Int, shopIndex: Int, productIndex: Int)
}

/**
 A value type to represent each shop group with its id with the result of their shipment id and shipmend product id logistic rates.

 after fetching SAF, every shop group that have preselected shipment, will fetch logistic rates, to fullfil and select the neccessary shipment.
 because the action will be done in concurrent, we need to give the identity of each request, so hence this value type.
 */
internal struct IdentifiedLogisticRatesResponse: Equatable {
    internal let id: CartOrderID
    internal let result: Result<LogisticRatesResponse, NetworkError>
}

internal struct DialogData: Equatable {
    internal let title: String
    internal let description: String
    internal let buttonTitle: String
    internal let secondaryButtonTitle: String?
    internal let callback: CheckoutAction
}

extension DialogData {
    internal init(from response: ShipmentAddressFormExpiredInfoResponse) {
        title = response.title
        description = response.description
        buttonTitle = response.buttonTitle
        secondaryButtonTitle = nil
        callback = .willExit(.campaignExpired)
    }
}

internal struct CampaignTimer: Equatable {
    internal var label: String
    internal var end: Date
    internal var expiredDialogData: DialogData
}

internal struct CashOnDelivery: Equatable {
    internal var isAvailable: Bool
    /**
         number of cash on delivery user have done
     */
    internal var count: Int
}

/**
    This struct is used to store free shipment data across all shop group on checkout page
 */
internal struct FreeShipmentCheckoutData: Equatable {
    internal var identifier: CartOrderID
    internal var code: String
}

extension CashOnDelivery {
    internal init(from response: ShipmentAddressFormResponse) {
        self.init(isAvailable: response.cod.isCod, count: response.cod.counter)
    }
}

internal enum WillExitFrom: Equatable {
    case backButton
    case campaignExpired
    case prompt(urlRedirection: String? = nil)
}

public typealias Price = Int64
internal struct AddonServiceSummaryData: Equatable {
    internal let title: String
    internal let price: Price
    internal let quantity: Int
    internal let type: Int

    internal init(
        title: String,
        price: Price,
        quantity: Int,
        type: Int
    ) {
        self.title = title
        self.price = price
        self.quantity = quantity
        self.type = type
    }
}

internal func chosenAddress(currentAddress: LocalizedAddress?) -> ShipmentAddressFormChosenAddressParams? {
    guard let chosenAddress = currentAddress else { return nil }

    let mode: Int = {
        switch chosenAddress {
        case .full:
            return 1
        case .district:
            return 2
        }
    }()

    let addressId: Int? = {
        if mode == 1 {
            guard let addressId = chosenAddress.addressId else { return nil }

            return addressId.rawValue
        } else {
            return nil
        }
    }()

    let districtId = chosenAddress.districtId.rawValue

    let geolocation: String = {
        guard let coordinate = chosenAddress.coordinate else { return "" }

        return String(coordinate.latitude) + "," + String(coordinate.longitude)
    }()

    return ShipmentAddressFormChosenAddressParams(
        mode: mode,
        addressId: addressId,
        districtId: districtId,
        postalCode: chosenAddress.postalCode ?? "",
        geolocation: geolocation,
        tokonow: chosenAddress.tokoNow
    )
}

/**
 Function used to update prescription widget in Mini Consultation
 */
internal func generateEpharmacyWidgetData(from data: [CheckoutPrescriptionData], title: String, subtitle: String? = nil) -> (title: String, subtitle: String?, approvedData: Int) {
    /// Prescriptions uploaded manually
    let prescriptionImages = data.flatMap { $0.prescriptionImages }

    /// Consultation data
    let consultationData = data.flatMap { $0.consultationData }

    /// Approved consultation prescriptions
    let approvedConsultationData = consultationData.filter { $0.consultationStatus == .approved }.flatMap { $0.shopConsultationId }

    /// Rejected consultation prescriptions
    let rejectedConsultationData = consultationData.filter { $0.consultationStatus == .rejected }

    /// Total all products that need prescriptions
    let totalData = prescriptionImages.count + consultationData.flatMap { $0.shopConsultationId }.count

    /// Total approved prescriptions
    let approvedData = prescriptionImages.count + (consultationData.isNotEmpty ? approvedConsultationData.count : 0)

    /// Set default value for widget's title & subtitle
    var newTitle = title
    var newSubtitle = subtitle

    /// If prescriptions approved
    ///     Update title with "Resep Terlampir"
    ///     Update subtitle with "Kamu punya (x) resep dokter"
    /// Else if all prescriptions rejected
    ///     Update title with "Resep Tidak Terlampir"
    ///     Update subtitle with "Dokter tidak memberi resep"
    if approvedData > 0 {
        newTitle = String.consultationPrescriptionTitle(true)
        newSubtitle = String.consultationPrescriptionSubtitle(approvedData)
    } else if rejectedConsultationData.isNotEmpty, rejectedConsultationData.count == totalData {
        newTitle = String.consultationPrescriptionTitle(false)
        newSubtitle = String.consultationPrescriptionSubtitle(approvedData)
    }

    return (title: newTitle, subtitle: newSubtitle, approvedData: approvedData)
}

/**
 Function used to update shop group state and product state in Mini Consultation
 */
internal func updateOrder(prescriptionData: [CheckoutPrescriptionData], order: [OrderState], rejectedTickerContent: String? = nil) -> (orderState: [OrderState], needPrescriptionCount: Int) {
    var productThatHasPrescriptionCount: Int = 0

    let orders = order.map { order -> OrderState in
        var newOrder = order

        prescriptionData.map { prescription in
            let epharmacyGroupId = prescription.epharmacyGroupId
            let products = prescription.productsInfo.flatMap { $0.products }
            let productIds = products.flatMap { $0.productId }

            let newOrderShopAndProductIds = newOrder.shops
                .flatMap { shop -> [(CartShopID, ShipmentProductID)] in
                    let ids = shop.products.map { (shop.id, $0.id) }
                    return ids
                }

            /// Check consultation status from the prescription data (only need to handle `.approved` & `.rejected` cases)
            let isPrescriptionAccepted = { (value: Bool) -> Bool in
                if let consultationData = prescription.consultationData {
                    if consultationData.consultationStatus == .approved {
                        return true
                    } else if consultationData.consultationStatus == .rejected {
                        return false
                    }
                }

                return value
            }

            /// Check if there is matching Product IDs from the prescription data and current shop group
            newOrderShopAndProductIds.map { shopId, id in
                for productId in productIds {
                    if id == productId {
                        /// Update product value, this property indicates that this is a Mini Consultation product
                        newOrder.shops[id: shopId]?.products[id: id]?.epharmacyGroupId = epharmacyGroupId

                        /// Update the state to enable/disable the product or shop group
                        newOrder.shops[id: shopId]?.products[id: id]?.isPrescriptionAccepted = isPrescriptionAccepted(true)

                        /// If user upload prescription manually, update current shop group's Prescription ID
                        if prescription.prescriptionImages.isNotEmpty {
                            productThatHasPrescriptionCount += 1
                            newOrder.prescriptionIds = prescription.prescriptionImages.flatMap { $0.prescriptionId }
                        }

                        /// If user attach prescription via consultation, update current shop group's Prescription ID & Consultation Metadata (to be sent as param for API `.checkout`)
                        if let consultationData = prescription.consultationData {
                            if consultationData.consultationStatus == .approved {
                                productThatHasPrescriptionCount += 1
                                newOrder.orderConsultationStatus = .approved
                                newOrder.prescriptionIds = consultationData.prescriptionIds
                                newOrder.consultationMetadata = consultationData.consultationMetadata
                            } else if consultationData.consultationStatus == .rejected {
                                newOrder.orderConsultationStatus = .rejected
                                newOrder.shops[id: shopId]?.products[id: id]?.consultationRejectedTickerContent = rejectedTickerContent
                            }
                        }

                        /// Update shipment for each shop group after receive prescription
                        newOrder.shipment?.shipperId = .invalid
                        newOrder.shipment?.shipperProductId = .invalid
                        newOrder.shipment?.selectedShipmentData = nil
                        newOrder.shipment?.mode = .empty
                        newOrder.shipment?.revalidateMode()
                    }

                    /// Update the state to display/hide error ticker in product level
                    ///     If all products are disabled, then hide the error ticker in product and show the error ticker in shop group level instead
                    ///     Otherwise, display/hide based on consultation status from the prescription data
                    let allProductsDisabled = newOrder.shops.allSatisfy { $0.allProductIsDisabled }
                    newOrder.shops[id: shopId]?.products[id: productId]?.shouldDisplayProductErrorTicker = allProductsDisabled ? false : !isPrescriptionAccepted(true)
                }
            }
        }

        return newOrder
    }

    let productNeedPrescriptionCount = orders.filter { $0.isEnabled }.map { order -> Int in
        order.shops.map { shop -> Int in
            shop.productNeedPrescriptionCount
        }.reduce(0, +)
    }.reduce(0, +)

    if productNeedPrescriptionCount == productThatHasPrescriptionCount {
        return (orderState: orders, needPrescriptionCount: 0)
    } else {
        return (orderState: orders, needPrescriptionCount: productNeedPrescriptionCount - productThatHasPrescriptionCount)
    }
}

struct AddressState: Equatable {}

/**
 `CheckoutViewController` State
 */
internal struct CheckoutState: Equatable {
    /**
     some value used to pass when request checkout, kero is name for checkout BE service
     */
    internal var keroToken: String
    /**
     some value used to pass when request checkout, kero is name for checkout BE service
     */
    internal var keroUnixTime: String
    /**
     some value used to pass when request checkout.
     cod itself stands for cash on delivery
     */
    internal var cod: CashOnDelivery

    internal var mode: CheckoutMode
    internal var viewMode: ViewMode

    /**
     list of disabled feature, controlled by backend
     */
    internal var disabledFeatures: Set<DisabledFeature>

    /**
     Set where user will focus on, if value set, checkout should scroll to target
     */
    internal var focusTarget: FocusTarget?

    /**
     Set coachmark
     */
    internal var coachMarkTarget: [CoachMarkTarget] = []

    /**
     Flag for Mini Consultation
     */
    internal var productNeedConsultation: Bool

    /**
     data that will trigger payment webview and passing neccessary data to payment with this value
     */
    internal var transactionCart: TransactionCartPayment?

    /**
     Will trigger popViewController

     This property uses `@NeverEqual` so we don't need to set the value manually everytime the value changed
     */
    @NeverEqual
    internal var exit: Bool

    /**
     timer countdown if current checkout mode is campaign
     */
    internal var campaignTimer: CampaignTimer?
    internal var tickers: [Ticker]

    internal var address: AddressState
    internal var orders: [OrderState]
    internal var cartData: String
    internal var donation: DonationCheckboxViewData?
    internal var egold: EgoldCheckboxViewData?
    internal var promo: PromoState
    internal var addOnBottomsheetData: AddOnSelectionRequestParams?
    internal var addOnDisabledBottomsheetData: AddOnDisableInfoData?
//    internal var selectedAddOnBottomsheet: SelectedAddOnBottomsheet?

    /**
     Data for platform fee per basket size
     - `paymentFeeParams`: Contains data to be used as request params when hit `getPaymentFeeCheckout` API
     - `paymentFeeErrorMesssage`: Contains message to be displayed in ticker when failed hit `getPaymentFeeCheckout` API
     - `paymentFeeData`: Contains data to be passed to `SummaryState`
     */
    internal var paymentFeeParams: CheckoutPaymentFeeParameter?
    internal var paymentFeeErrorMesssage: String?
    internal var paymentFeeData: PaymentFeeViewData

    /**
     Value representing summary section on checkout

     this value needs update when:
     - finish fetch checkout response
     - user change shipment
     - user tap untap insurance
     - user apply promo
     */
    /// TODO JEFF
//    internal var summary: SummaryState {
//        SummaryState(
//            with: orders,
//            egold: egold,
//            donation: donation,
//            promo: promo,
//            productNeedConsultation: productNeedConsultation,
//            allConsultationProductsRejected: allConsultationProductsRejected,
//            hasPaymentLevelError: hasPaymentLevelError,
//            isUploadPrescriptionValid: isUploadPrescriptionValid,
//            plusData: gotoPlusWidgetDataV2,
//            paymentFeeData: paymentFeeData,
//            safAddOnServiceSummary: safAddOnServiceSummary,
//            expandPaymentDetails: expandPaymentDetails
//        )
//    }

    /**
     Free shipment can now be applied on multiple shop group across the checkout page,
     this variable stores the free shipment data from all shop groups that currently using free shipment
     */

    internal var freeShipmentCheckoutData: [FreeShipmentCheckoutData] {
        let freeShipmentOrders = orders.filter { $0.shipment?.selectedShipmentData?.isFreeShipment == true }
        let scheduledFreeShipmentOrders = orders.filter { $0.scheduledDelivery?.selectedShipment?.promoCode?.isNotEmpty ?? false }

        guard freeShipmentOrders.isNotEmpty || scheduledFreeShipmentOrders.isNotEmpty else { return [] }

        var freeShipmentCheckoutData: [FreeShipmentCheckoutData] = []

        let freeShipmentOrderData = freeShipmentOrders.compactMap { order -> FreeShipmentCheckoutData? in
            guard let selectedShipment = order.shipment?.selectedShipmentData,
                let freeShipmentPromoCode = selectedShipment.freeShipmentPromoCode
            else { return nil }

            return FreeShipmentCheckoutData(identifier: order.cartUniqueIdentifier, code: freeShipmentPromoCode)
        }

        let scheduledFreeShipmentOrderData = scheduledFreeShipmentOrders.compactMap { order -> FreeShipmentCheckoutData? in
            guard let promoCode = order.scheduledDelivery?.selectedShipment?.promoCode,
                promoCode.isNotEmpty
            else { return nil }

            return FreeShipmentCheckoutData(identifier: order.cartUniqueIdentifier, code: promoCode)
        }

        freeShipmentCheckoutData.append(contentsOf: freeShipmentOrderData)
        freeShipmentCheckoutData.append(contentsOf: scheduledFreeShipmentOrderData)

        return freeShipmentCheckoutData
    }

    /**
     return true if promo.globalCodes or merchantCodes on shop group did exist
     */
    internal var applyAnyPromo: Bool {
        promo.globalCode != nil || orders.contains { $0.hasMerchantCode || $0.logisticCode != nil }
    }

    /**
     trade in drop off only if mode is set to trade in and address currently on trade in drop off true
     */
    internal var isTradeInDropOff: Bool {
        mode.isTradeIn && address.viewMode == .tradeIn(dropOff: true)
    }

    internal var isAnyTokonow: Bool {
        orders.contains(where: {
            $0.shops.contains(where: { $0.isTokonow == true })
        })
    }

    internal var shopTier: Int

    /**
     Payment level error ticker, it's positioned on top of the page if the value is provided
     */
    internal var errorTicker: [TickerContent]

    /**
     Flag indicating whether the page has payment level error or not.
     If yes,  the whole page is disabled and the only action that can be done by the user is back to cart page.
     */
    internal var hasPaymentLevelError: Bool

    internal var popUp: PopUp?
    internal var addOnWording: AddOnWording?

    /**
     All properties that handle epharmacy feature on checkout scope
     */
    internal var uploadPrescriptionState: UploadPrescriptionState?

    internal var prescriptionIDs = [PrescriptionID]()

    internal var isApprovedPrescriptionExists: Bool { orders.flatMap { $0.prescriptionIds }.isNotEmpty || orders.contains { $0.orderConsultationStatus == .approved } }

    internal var isRejectedConsultationPrescriptionExist: Bool { orders.contains { $0.orderConsultationStatus == .rejected } }

    internal var allConsultationProductsRejected: Bool {
        !orders.flatMap { $0.shops.flatMap { $0.products } }.contains { $0.isPrescriptionAccepted }
    }

    internal var epharmApprovedDataCount: Int = 0

    internal var productStillNeedPrescriptionMessage: String = ""

    /**
     To be sent to product level when prescription is rejected
     */
    internal var rejectedTickerContent: String?

    internal var isUploadPrescriptionValid: Bool {
        let enableValidation: Bool = uploadPrescriptionState?.mode.content?.isEnableUploadPrescriptionValidation == true
        let hasEthicalDrug: Bool = uploadPrescriptionState?.mode.content?.hasEthicalDrug == true
        let hasCheckoutApprovedByEpharmacy = uploadPrescriptionState?.mode.content?.isCheckoutFlowApprovedByPPG ?? true

        /**
         We validate if back-end enable upload prescription mandatory flow from `enableValidation` and we have ethical drug product on the product list.
         Validate by checking if user already upload prescriptions before tap button checkout.
         Default value will be `true`, so we don't block checkout flow if we don't need upload prescription mandatory flow.
         */

        guard hasCheckoutApprovedByEpharmacy else { return false }

        guard enableValidation, hasEthicalDrug else { return true }

        if productStillNeedPrescriptionMessage.isNotEmpty {
            return false
        }

        /**
         Check prescription validity for Mini Consultation
         */
        var isNeedConsultationValid: Bool = isApprovedPrescriptionExists

        /**
         If there is a rejected product, we need to check:
         If all products in Checkout needs consultation and rejected, then return `false`
         Otherwise, return `true`
         */
        if orders.flatMap { $0.shops.flatMap { $0.products } }.contains { !$0.isPrescriptionAccepted } {
            isNeedConsultationValid = !allConsultationProductsRejected
        }

        return productNeedConsultation ? isNeedConsultationValid : prescriptionIDs.isNotEmpty
    }

    /**
     Data for goto plus widget
     */
    internal var gotoPlusWidgetDataV2: GotoPlusWidgetDataV2?

    internal var isPlusWidgetSelected: Bool = false
    internal var plusWebviewURL: String?

    /**
     Data for dynamic data passing
     */
    internal var isDdp: Bool = false
    internal var dynamicData: String = ""
    internal var dynamicDataParams: [DynamicDataParam] = []

    /**
     Data for `add-ons as a service`
     */
    internal var safAddOnServiceSummary: [ShipmentAddressFormAddonServiceSummary] = []

    /**
     Data for SAF request param, used for OFOC order
     */
    internal var shipmentActionType: ShipmentActionType = .merge

    /**
     Data for `shipping widget`
     This field was introduced in checkout revamp to act as a central control
     to enable/disable new shipping widget experience in checkout.

     2 possible value:
     - default (old experience)
     - checkout revamp(new experience)
     */
    // TODO: Notes for Son: please update this field to follow checkout revamp rollence, We will pass `.checkoutRevamp` for enabled state and `default` for disabled state
    internal var shippingWidgetExperience: ShippingWidgetExperience = .checkoutRevamp

    internal var expandPaymentDetails: Bool = false

    internal let isUsingNewPromoWidget: Bool

    // MARK: Helper func

    /**
     This helper is helping us get SAF Params for hitting our SAF Params
     Previously we use computed property, but as for now we need to mock the one value using environment
     so we need to make it as helper not as a computed var state anymore
     */

    internal func getShipmentAddressFormParams(
        currentAddress: LocalizedAddress?
    ) -> ShipmentAddressFormParams {
        return ShipmentAddressFormParams(
            vehicleLeasingId: mode.getLeasingId(),
            isOCS: mode.isOneClickShipment,
            isTradeIn: mode.isTradeIn,
            deviceId: mode.getDeviceId(),
            chosenAddress: chosenAddress(currentAddress: currentAddress),
            isPlusWidgetSelected: isPlusWidgetSelected,
            shipmentActionType: shipmentActionType
        )
    }

    /**
     This helper is used to generate `CouponListParamData`
     */
    internal func generateCouponListParam(freeShipmentData: FreeShipmentData? = nil) -> CouponListParamData {
        CouponListParamData(
            mode: mode,
            promoState: promo,
            orders: orders,
            isTradeInDropOff: isTradeInDropOff,
            tryFreeShipment: freeShipmentData
        )
    }

    /**
     Function used to update `getPromoListRecomParam` property in promo widget
     */
    internal func updatePromoWidgetDefaultData(from promoWidgetViewData: PromoWidgetViewData) -> CheckoutPromoWidgetData {
        var newPromoWidgetViewData = promoWidgetViewData
        newPromoWidgetViewData.getPromoListRecomParam = generateCouponListParam()

        return CheckoutPromoWidgetData(
            view: .default(newPromoWidgetViewData),
            viewData: newPromoWidgetViewData
        )
    }

    /**
     This helper is used to reset promo
     */
//    internal mutating func resetPromo(newTitle: String = "", shouldResetShipment: Bool, environment: PromoEnvironment) -> Effect<PromoAction> {
//        // reset promo
//        promo = PromoState(
//            trackingDetails: [],
//            widgetView: {
//                let promoWidgetViewData: PromoWidgetViewData = PromoWidgetViewData(
//                    titles: [newTitle],
//                    subtitle: nil,
//                    promoExists: false,
//                    benefitAmount: 0,
//                    leftIconUrl: PromoWidgetImages.coupon.url,
//                    useLeftIcon: false,
//                    promoSummaries: [],
//                    getPromoListRecomParam: nil
//                )
//
//                return CheckoutPromoWidgetData(
//                    view: .loadingContent,
//                    viewData: promoWidgetViewData
//                )
//            }(),
//            promoWidgetMandatoryData: promo.promoWidgetMandatoryData,
//            globalCode: nil,
//            discountAmount: 0,
//            cashbackAmount: 0,
//            shippingDiscountAmount: 0,
//            openPromoPickerWithParams: nil,
//            isEnabled: true,
//            isAutoApplied: false
//        )
//
//        orders = orders.map { order in
//            var newOrder = order
//
//            newOrder.shops = newOrder.shops.map { shop in
//                var newShop = shop
//                newShop.merchantCodes = []
//                return newShop
//            }
//
//            if shouldResetShipment {
//                // shop group has BO applied
//
//                if newOrder.shipment?.selectedShipmentData?.isFreeShipment == true {
//                    newOrder.logisticCode = nil
//                    // reset shipment
//                    newOrder.shipment?.shipperId = .invalid
//                    newOrder.shipment?.shipperProductId = .invalid
//                    newOrder.shipment?.selectedShipmentData = nil
//                    newOrder.shipment?.mode = .empty
//                }
//            }
//
//            return newOrder
//        }
//
//        // check if any free shipment is applied
//        if freeShipmentCheckoutData.isNotEmpty {
//            let params = generateCouponListParam()
//
//            let localizedAddress: LocalizedAddress? = environment.getChosenAddressData()
//
//            let additionalParam = generateCheckoutPromoAdditionalParam(localizedAddress)
//
//            return environment
//                .validateUseResponse(
//                    params,
//                    additionalParam
//                )
//                .map { result -> PromoAction in
//                    .validateCouponResponse(result, source: .others)
//                }
//                .eraseToEffect()
//        } else {
//            if let promoWidgetViewData = promo.widgetView.viewData {
//                promo.widgetView = updatePromoWidgetDefaultData(from: promoWidgetViewData)
//            }
//
//            return .none
//        }
//    }
//
//    /**
//     This helper is used to generate Mini Consultation analytics data
//     */
//    internal func generateEpharmacyConsultationAnalyticsData() -> CheckoutEpharmacyConsultationAnalyticsData {
//        let partnerName = orders
//            .flatMap { $0.identity.epharmacyPartnerName }
//            .joined(separator: ",")
//
//        let epharmacyConsultationShopId = orders
//            .flatMap { order -> [String] in
//                order.shops
//                    .filter { $0.anyProductUseEpharmConsul }
//                    .map { String($0.shopId.rawValue) }
//            }
//            .joined(separator: ",")
//
//        let epharmacyConsultationCartId = orders
//            .flatMap { order -> [ProductState] in
//                order.shops.flatMap { $0.products }
//            }
//            .compactMap { product -> String? in
//                guard product.epharmacyGroupId != nil else { return nil }
//                return String(product.cartId)
//            }
//            .joined(separator: ",")
//
//        let epharmacyGroupId = orders
//            .flatMap { order -> [ProductState] in
//                order.shops.flatMap { $0.products }
//            }
//            .compactMap { product -> String? in
//                guard let id = product.epharmacyGroupId else { return nil }
//                return id.rawValue
//            }
//            .joined(separator: ",")
//
//        var ecommerce: [ECommerce.Promo] = []
//        orders.enumerated().map { index, order in
//            let epharmacyGroupId = order.shops
//                .map { $0.allProductEpharmGroupId }
//                .joined(separator: ",")
//
//            ecommerce.append(
//                ECommerce.Promo(
//                    id: epharmacyGroupId,
//                    name: "epharmacy checkout page",
//                    creative: order.identity.epharmacyPartnerName,
//                    position: "\(index + 1)"
//                )
//            )
//        }
//
//        return CheckoutEpharmacyConsultationAnalyticsData(
//            epharmacyGroupId: epharmacyGroupId,
//            partnerName: partnerName,
//            epharmacyConsultationShopId: epharmacyConsultationShopId,
//            epharmacyConsultationCartId: epharmacyConsultationCartId,
//            ecommerce: ecommerce
//        )
//    }

    /**
      This helper is used to generate effects when user swipe back or tap back button
     */
    internal func generateBackButtonTapEffects(environment: CheckoutEnvironment) -> [Effect<CheckoutAction>] {
        var effects: [Effect<CheckoutAction>] = []

        /// only release booking if ocs and campaign is available
        if mode == .oneClickShipment(.default), campaignTimer != nil {
            let productIds = orders.flatMap { order -> [ShipmentProductID] in
                order.shops.flatMap { shop -> [ShipmentProductID] in
                    shop.products.map { $0.id }
                }
            }

            // release stock
            effects.append(
                environment
                    .releaseStockBookingResponse(productIds)
                    .flatMapLatest { _ -> Effect<CheckoutAction> in .none }
                    .eraseToEffect()
            )
        }

        if let plusData = gotoPlusWidgetDataV2, plusData.isSelected {
            effects.append(Effect(value: .clearPlusFreeShipping))
        }

        return effects
    }

    /**
      This helper is used to handle OFOC action; split or merge
     */
    internal mutating func mergeOrSplitOrder(_ action: ShipmentActionType) -> Effect<CheckoutAction> {
        guard shipmentActionType != action else {
            return .none
        }

        shipmentActionType = action

        return Effect(value: .didLoad)
    }

    /**
     This helper is used to construct `save_add_ons` param
     */
    internal func constructSaveAddOnsParam() -> SaveAddOnRequestParams? {
        // Product that supports `add-ons as a service` must exists, otherwise don't construct the param
        guard orders.contains(where: { $0.enabledValidProducts.contains { $0.addOnPickerData != nil } })
        else { return nil }

        return SaveAddOnRequestParams(
            addOnDetailData: orders.generateOrderSaveAddOnDetailData(),
            source: mode.isOneClickShipment ? "ocs" : "normal"
        )
    }
}

extension CheckoutState {
    /// convenience init with mode
    internal init(mode: CheckoutMode = .default(source: "cart"), isUsingNewPromoWidget: Bool) {
        self.init(
            keroToken: "",
            keroUnixTime: "",
            cod: CashOnDelivery(isAvailable: false, count: 0),
            mode: mode,
            viewMode: .normal(overlay: nil),
            disabledFeatures: [],
            focusTarget: nil,
            productNeedConsultation: false,
            transactionCart: nil,
            exit: false,
            campaignTimer: nil,
            tickers: [],
            address: AddressState(),
            orders: [],
            cartData: "",
            donation: nil,
            egold: nil,
            promo: PromoState(),
            paymentFeeData: PaymentFeeViewData(viewMode: .normal),
            shopTier: 0,
            errorTicker: [],
            hasPaymentLevelError: false,
            isUsingNewPromoWidget: isUsingNewPromoWidget
        )
    }
}

/**
 `CheckoutViewController` possible action to store.
 */
internal enum CheckoutAction: Equatable {
    case didLoad

    /**
     When user view coachmark v2 for Mini Consultation
     */
    case viewEpharmacyConsultationCoachMark

    /**
     Clear `focusTarget`.
     `focusTarget` is state binding where screen should be focus on, this including scroll to respective UI component
     */
    case clearFocusTarget

    /**
     Clear `coachMarkTarget`.
     `coachMarkTarget` is state binding where coachmark will focus on
     */
    case clearCoachMarkTarget

    /**
     Clear `transactionCartData` state binding
     */
    case clearTransactionCartData
    case willExit(WillExitFrom)

    /**
     Triggered when campaign timer is expire
     */
    case campaignExpired

    /**
     SAF (Shipping Address Form)

     most data on checkout will be filled inside here

     more:
     [[GraphQL] Shipment Address Form v2](https://tokopedia.atlassian.net/wiki/spaces/TTD/pages/639632492/%5BGraphQL%5D+Shipment+Address+Form+v2)
     */
    case checkoutResponse(Result<ShipmentAddressFormResponse, NetworkError>)

    /**
     Logistic rates

     the data will be used to populate shipping data, based on `CheckoutShipmentID` and `CheckoutShipmentProductID`

     more:
     RatesV3 https://tokopedia.atlassian.net/wiki/spaces/LG/pages/567279712/Rates+V3
     */
    case logisticRatesResponse([IdentifiedLogisticRatesResponse])

    /**
     Action to update `DonationNode` is selected value
     */
    case tapDonation

    /**
     Action to update `EgoldNode` is selected value
     */
    case tapEGold

    /**
     Action to update to navigate to terms and conditions webview
     */
    case tapEGoldTermsAndConditions

    /**
     Action when back button tapped on DialogBox
     */
    case tapBackOnDialogBox

    /**
     Action to clear prescription dialog data
     */
    case clearPrescriptionAttachmentDialogData

//    case updateDynamicDataResponse(Result<UpdateDynamicDataResponse, TPError<UpdateDynamicDataError>>)

    // MARK: - Sub Action from scoping store

    /**
     Action from scope store on `AddressNode`
     */
    case address(AddressAction)

    /**
     Action from scope store on `OrderNode`
     */
    case orders(identifier: CartOrderID, action: OrderAction)

    /**
     Action from scope store on `UploadPrescriptionNode`
     */
    case checkUploadedPrescription(epharmacyWidgetData: EpharmacyImageUploadResponse)
//    case receiveUploadedPrescription(epharmacyData: Result<EpharmacyCheckoutDetailData, NetworkError>, epharmacyWidgetData: EpharmacyImageUploadResponse)
//    case uploadPrescription(UploadPrescriptionAction)
    case receivePrescriptionID(prescriptionIDs: [PrescriptionID])

    /**
     Action from scope store on `UploadPrescriptionNode` for Mini Consultation
     */
    case receiveConsultationPrescription(epharmacyConsultationData: Result<CheckoutEpharmacyPPGData, NetworkError>, epharmacyConsultationWidgetData: EpharmacyImageUploadResponse)
    case receiveConsultationPrescriptionListData(prescriptionData: [CheckoutPrescriptionData])
    case resetPromoMiniConsultation

    /**
     Action to update `PromoNode` state
     */
    case promo(PromoAction)
    case summary(SummaryAction)

    case userSeeDonationView
    case userSeeMissingShipperTicker
    case userSeeTickerView
    case resetAddOnBottomsheetData
    case resetAddOnDisabledBottomsheetData
    case receiveGiftingBottomsheetCompletion([AddOn])

    case plusWidget(CheckoutPlusWidgetAction)
    case plusStateFromWebview(Bool)
    case clearPlusLink
    case clearPlusFreeShipping

    /**
     Action when receive response from `getPaymentFeeCheckout`
     */
//    case receivePaymentFeeResponse(Result<CheckoutPaymentFeeResponse, TPError<CheckoutPaymentFeeError>>)

    /**
     Analytics for `add-ons as a service`
     */
    case viewAddOnPicker
}

/**
 This is reducer that done reducing logic for `CheckoutViewController` Action
 */
internal let checkoutDefaultReducer = Reducer<CheckoutState, CheckoutAction, CheckoutEnvironment> { (state, action, environment) -> Effect<CheckoutAction> in
    switch action {
    case .didLoad:
        state.viewMode = .shimmerLoading

        var effects: [Effect<CheckoutAction>] = {
            var elements: [Effect<CheckoutAction>] = []
            elements.append(
//                environment
//                    .sendAnalytics(.checkoutHomeScreen(isTradeIn: state.mode.isTradeIn, isTradeInDropOff: state.isTradeInDropOff))
//                    .fireAndForget()
            )

            // need to get SAF Params before we hit SAF API
            let currentSelectedAddress: LocalizedAddress? = environment.getChosenAddressData()
            let shipmentAddressFormParams: ShipmentAddressFormParams = state.getShipmentAddressFormParams(
                currentAddress: currentSelectedAddress
            )

            elements.append(
                environment
                    .shipmentAddressFormResponse(shipmentAddressFormParams)
                    .map { response in
                        CheckoutAction.checkoutResponse(response)
                    }
                    .eraseToEffect()
            )

            return elements
        }()

        return .merge(effects)
    case .viewEpharmacyConsultationCoachMark:
        let analyticsData = state.generateEpharmacyConsultationAnalyticsData()

        return environment
            .sendAnalytics(.viewEpharmacyConsultationCoachmark(analyticsData: analyticsData,
                                                               userId: environment.getLocalUserId())
            ).fireAndForget()
    case .clearFocusTarget:
        state.focusTarget = nil

        return .none
    case .clearTransactionCartData:
        state.transactionCart = nil

        return .none
    case .clearCoachMarkTarget:
        state.coachMarkTarget = []

        return .none
    case .userSeeDonationView:
        guard state.donation?.defaultIsSelectedFromServer == true else {
            return .none
        }

        return environment
            .sendAnalytics(.viewAutoCheckDonationStatus())
            .fireAndForget()

    case .userSeeTickerView:
        let effects = state.tickers.filter { $0.id != .invalid }.map { ticker -> Effect<CheckoutAction> in
            environment
                .sendAnalytics(.viewTickerOnTopCheckout(tickerId: ticker.id.rawValue))
                .fireAndForget()
        }

        return .merge(effects)

    case .userSeeMissingShipperTicker:
        guard !state.orders.allOrderHaveChosenShipment else {
            return .none
        }

        return environment
            .sendAnalytics(.viewNotCompletedCourierTickerOnSummary())
            .fireAndForget()

    case let .willExit(type):
        /**
          Flag to display `DialogBox` for Mini Consultation. It should be displayed when:
          - Checkout page supports Mini Consultation flow
          - Shop group contains approved or manually uploaded prescriptions
         */
        let shouldDisplayPrescriptionAttachedDialog = state.productNeedConsultation && state.isApprovedPrescriptionExists

        switch type {
        case .campaignExpired:
            // only exit programatically if not `backButton`
            // back button, should not trigger pop vc
            state.exit = true
        case let .prompt(urlRedirection):
            guard urlRedirection == nil else { break }
            // means we trigger back automatically once prompt button action is clicked
            // and the url is empty or nil
            // we handle on other lines when the url is not nil
            state.exit = true
        case .backButton:
            guard !shouldDisplayPrescriptionAttachedDialog else {
                let dialogData = DialogData(
                    title: "Yakin mau keluar dari halaman ini?",
                    description: "Resep digital akan tersedia 1x24 jam selama kamu tidak mengubah jumlah obat kerasnya.",
                    buttonTitle: "Lanjut Bayar",
                    secondaryButtonTitle: "Keluar",
                    callback: .clearPrescriptionAttachmentDialogData
                )
                state.viewMode = .normal(overlay: .prescriptionAttached(dialogData))
                break
            }
            state.exit = true
        }

        var effects: [Effect<CheckoutAction>] = {
            var elements = [Effect<CheckoutAction>]()

            switch type {
            case .backButton:
                elements.append(
                    environment
                        .sendAnalytics(.tapBackArrowEvent(isTradeIn: state.mode.isTradeIn, isTradeInDropOff: state.isTradeInDropOff))
                        .fireAndForget()
                )

                if shouldDisplayPrescriptionAttachedDialog {
                    elements.append(
                        environment
                            .sendAnalytics(.viewEpharmacyConsultationDialogBox(isLoggedIn: environment.getLocalUserId() != nil && environment.getLocalUserId() != "0",
                                                                               epharmacyGroupId: state.generateEpharmacyConsultationAnalyticsData().epharmacyGroupId,
                                                                               isPrescriptionAccepted: state.isApprovedPrescriptionExists,
                                                                               userId: environment.getLocalUserId())
                            ).fireAndForget()
                    )
                } else {
                    elements.append(contentsOf: state.generateBackButtonTapEffects(environment: environment))
                }

            case .campaignExpired:
                /// campaign always only 1 product
                if let productId = state.orders.first?.shops.first?.products.first?.id {
                    elements.append(
                        environment
                            .sendAnalytics(.tapContinueOnCampaignExpiredDialogBox(productId: productId.rawValue))
                            .fireAndForget()
                    )
                }

                // release stock
                let productIds = state.orders.flatMap { order -> [ShipmentProductID] in
                    order.shops.flatMap { $0.products.map { $0.id } }
                }

                elements.append(
                    environment
                        .releaseStockBookingResponse(productIds)
                        .flatMapLatest { _ -> Effect<CheckoutAction> in
                            .none
                        }
                        .eraseToEffect()
                )

            case let .prompt(urlRedirection):
                if let newUrl = urlRedirection {
                    elements.append(
                        environment
                            .routeWithUrl(newUrl)
                            .fireAndForget()
                    )
                }
            }

            guard let addressId = { () -> AddressID? in
                if state.isTradeInDropOff {
                    return state.address.dropOffAddress?.id
                } else {
                    return state.address.address?.id
                }
            }() else { return elements }

            elements.append(
//                environment
//                    .saveShipment(SaveShipmentParams(with: state, addressId: addressId))
//                    .fireAndForget()
            )

            return elements
        }()

        return .merge(effects)
    case .campaignExpired:
        // make sure campaign countdown exist in the first place else
        guard let campaignTimer = state.campaignTimer else { return .none }
        state.viewMode = .normal(overlay: .dialog(campaignTimer.expiredDialogData))

        var effects: [Effect<CheckoutAction>] = {
            var elements: [Effect<CheckoutAction>] = []
            if let productId = state.orders.first?.shops.first?.products.first?.id {
                elements.append(
                    environment
                        .sendAnalytics(.campaignExpired(productId: productId.rawValue))
                        .fireAndForget()
                )
            }

            return elements
        }()

        return .merge(effects)
    case let .checkoutResponse(result):
        /**
         Reset payment fee data in state when receive SAF response
         */
        state.paymentFeeData = PaymentFeeViewData(viewMode: .normal)

        switch result {
        case let .success(response):
            var effects: [Effect<CheckoutAction>] = []

            if response.errorCode == .updateLocalAddress, response.address == nil {
                state.exit = true
                return environment.refreshCart().fireAndForget()
            }

            effects.append(environment.refreshCart().fireAndForget())

            state.campaignTimer = {
                if response.campaignTimer.showTimer,
                    let startTime = response.campaignTimer.time.deductTime,
                    let serverTime = response.campaignTimer.time.serverTime,
                    let expiredTime = response.campaignTimer.time.expiredTime {
                    guard
                        startTime <= serverTime,
                        serverTime < expiredTime
                    else {
                        state.viewMode = .normal(overlay: .dialog(DialogData(from: response.campaignTimer.expiredInfo)))
                        return .none
                    }

                    return CampaignTimer(
                        label: response.campaignTimer.title,
                        end: expiredTime,
                        expiredDialogData: DialogData(from: response.campaignTimer.expiredInfo)
                    )
                } else {
                    return nil
                }
            }()
            state.disabledFeatures = response.disabledFeatures
            state.keroToken = response.keroToken
            state.keroUnixTime = response.keroUnixTime
            state.cod = CashOnDelivery(from: response)
            state.address = addressState(from: response, isTradeIn: state.mode.isTradeIn, previousAddressState: state.address)
            state.errorTicker = response.errorTicker.isEmpty ? [] : [TickerContent(type: .error, htmlContent: response.errorTicker)]
            state.hasPaymentLevelError = response.errorTicker.isNotEmpty
            state.tickers = response.tickers.compactMap { ticker -> Ticker? in
                guard ticker.message.isNotEmpty else { return .none }

                return Ticker(
                    id: ticker.id,
                    content: TickerContent(
                        type: .announcement,
                        htmlContent: ticker.message
                    )
                )
            }
            state.orders = {
                let shouldShowIndexLabel = response.order.count > 1 || (response.order.first?.groupInformation.description.isNotEmpty ?? false)

                return zip(response.order.indices, response.order).map { offset, order in
                    let orderState = orderState(
                        from: order,
                        promoResponse: response.promo,
                        checkoutMode: state.mode,
                        disabledFeatures: state.disabledFeatures,
                        shipmentViewMode: state.isTradeInDropOff ? .tradeInDropOff : .default,
                        at: shouldShowIndexLabel ? offset : nil,
                        hasPaymentLevelError: response.errorTicker.isNotEmpty,
                        address: response.address
                    )

                    orderState.shops.forEach { shop in
                        shop.cartDetailState
                            .filter { $0.giftState.isNotEmpty }
                            .forEach {
                                effects.append(
                                    environment
                                        .sendAnalytics(AnalyticsEvent.gwpImpression(
                                            offerId: $0.cartDetails.cartDetailInfo.cartDetailType.offerID.intValue,
                                            productQty: $0.validProducts.reduce(0) { $0 + $1.quantity },
                                            giftQty: $0.giftValidProducts.reduce(0) { $0 + $1.quantity },
                                            shopID: shop.shopId.rawValue,
                                            userID: environment.getLocalUserId()
                                        ))
                                        .fireAndForget()
                                )
                            }
                    }

                    return orderState
                }
            }()

            state.cartData = response.cartData
            state.isDdp = response.dynamicDataPassing.isDdp
            state.dynamicData = response.dynamicDataPassing.dynamicData

            if let platformFeeData = response.platformFeeData {
                state.paymentFeeParams = CheckoutPaymentFeeParameter(
                    profileCode: platformFeeData.profileCode,
                    paymentAmount: Float(state.summary.totalCheckout.rawValue),
                    additionalData: platformFeeData.additionalData
                )
                state.paymentFeeErrorMesssage = platformFeeData.errorMessage
            }

            if response.addOnServiceSummary.isNotEmpty {
                state.safAddOnServiceSummary = response.addOnServiceSummary
                effects.append(
                    Effect(value: .viewAddOnPicker)
                )
            }

            state.donation = {
                guard !state.disabledFeatures.contains(.donation) else { return nil }
                return donationCheckboxViewData(from: response.donation, isEnabled: response.errorTicker.isEmpty)
            }()
            state.egold = {
                guard !state.disabledFeatures.contains(.egold) else { return nil }
                // reuse summaryNode view data init logic to generate subtotal
                let totalPrice = SummaryState(
                    from: response,
                    checkoutMode: state.mode,
                    disabledFeatures: state.disabledFeatures,
                    isUploadPrescriptionValid: state.isUploadPrescriptionValid,
                    paymentFeeData: state.paymentFeeData,
                    safAddOnServiceSummary: state.safAddOnServiceSummary,
                    getPromoListRecomParam: state.generateCouponListParam(),
                    isUsingNewPromoWidget: state.isUsingNewPromoWidget
                ).totalCheckoutWithoutPaymentFee
                return egoldCheckboxViewData(from: response.egold, totalPrice: totalPrice, isEnabled: response.errorTicker.isEmpty)
            }()

            if state.egold != nil {
                let productIds = state.orders
                    .map { $0.productIds }
                    .joined(separator: ",")

                effects.append(
                    environment
                        .sendAnalytics(AnalyticsEvent.sendImpressionEGold(productIds: productIds, userId: environment.getLocalUserId()))
                        .fireAndForget()
                )
            }

            state.promo = promoState(from: response, isUsingNewPromoWidget: state.isUsingNewPromoWidget)

            state.coachMarkTarget = {
                var target: [CoachMarkTarget] = []

                if response.showOnboarding {
                    target.append(.address)
                    if let identifier = state.orders.first?.cartUniqueIdentifier {
                        target.append(.orderShipment(identifier: identifier))
                    }
                } else if let coachmarkData = response.plusCoachmarkData,
                    let content = coachmarkData.content,
                    // Get the first plus shop group ( bo type = 5 )
                    let identifier = state.orders.first(where: { $0.boType == 5 })?.cartUniqueIdentifier {
                    target.append(
                        .plusShipment(
                            identifier: identifier,
                            userID: environment.getLocalUserId(),
                            title: coachmarkData.title,
                            message: content
                        )
                    )
                }

                return target
            }()
            state.addOnWording = response.addOnWording

            if let imageUpload = response.epharmacyImageUpload {
                state.productNeedConsultation = imageUpload.consultationFlow
                state.rejectedTickerContent = imageUpload.rejectedWording
                state.uploadPrescriptionState = UploadPrescriptionState(mode: .loading)

                if imageUpload.consultationFlow {
                    state.coachMarkTarget.append(.attachPrescription(userId: environment.getLocalUserId()))
                }

                effects.append(
                    Effect(value: .checkUploadedPrescription(epharmacyWidgetData: imageUpload))
                )
            } else {
                state.productNeedConsultation = false
                state.uploadPrescriptionState = nil
            }

            if response.popUp.eligibleToShow {
                state.popUp = response.popUp
            }

            state.gotoPlusWidgetDataV2 = response.gotoPlusWidgetDataV2
            state.isPlusWidgetSelected = response.gotoPlusWidgetDataV2?.isSelected ?? false

            if let plusData = state.gotoPlusWidgetDataV2 {
                let viewGotoPlusEvent: Effect<CheckoutAction>

                if plusData.isSelected {
                    viewGotoPlusEvent = environment
                        .sendAnalytics(AnalyticsEvent.viewGotoplusCrossSellCancel())
                        .fireAndForget()
                } else {
                    viewGotoPlusEvent = environment
                        .sendAnalytics(AnalyticsEvent.viewGotoplusCrossSell())
                        .fireAndForget()
                }

                effects.append(viewGotoPlusEvent)
            }

            if response.toaster.isNotEmpty {
//                let showToast: Effect<CheckoutAction> = environment
//                    .showToast(ToastData(type: .normal, message: response.toaster))
//                    .fireAndForget()
//
//                effects.append(showToast)
            }

            // if shop group data empty, means user cart data on BE is empty.
            guard response.order.isNotEmpty else {
                state.viewMode = .error(.emptyCart)

                return .none
            }

            let checkoutEventData = generateCheckoutEventData(checkoutState: state, step: .pageLoaded)

            let sendDidCheckoutPageLoadEvent: Effect<CheckoutAction> = environment
                .sendAnalytics(AnalyticsEvent.checkoutEvent(data: checkoutEventData))
                .fireAndForget()

            effects.append(sendDidCheckoutPageLoadEvent)

            response.order.forEach { order in
                let shouldViewGotoPlusLogo = order.shopShipmentInformation.freeShippingData.shouldViewGotoPlusLogo

                if shouldViewGotoPlusLogo {
                    let viewGotoPlusLogoEvent: Effect<CheckoutAction> = environment
                        .sendAnalytics(AnalyticsEvent.viewGotoplusLogo())
                        .fireAndForget()

                    effects.append(viewGotoPlusLogoEvent)
                }
            }

            if response.errorTicker.isNotEmpty {
                let shopIds = response.order
                    .map { order -> String in
                        order.shopGroup
                            .map { $0.id.description }
                            .joined(separator: ", ")
                    }
                    .joined(separator: ", ")

                // Ex: 12, 34, 56 - (error message)
                let label = shopIds + " - " + response.errorTicker

                // Send analytic when there is payment level error (red ticker at the top of the page)
                let viewPaymentTickerEvent: Effect<CheckoutAction> = environment
                    .sendAnalytics(AnalyticsEvent.viewPaymentLevelErrorTicker(label: label))
                    .fireAndForget()

                effects.append(viewPaymentTickerEvent)
            }

            guard let address = getAddress(isTradeInDropOff: state.isTradeInDropOff, addressState: state.address)
            else {
                state.viewMode = .normal(overlay: nil)

                /**
                 send analytics checkout page did load
                 */
                return sendDidCheckoutPageLoadEvent
            }

            // Setup the request param for rates and scheduled delivery
            for order in state.orders where order.shippingComponent.hasScheduled {
                let logisticRatesParams = LogisticRatesParams(
                    orderState: order,
                    mode: state.mode,
                    isDropOff: state.isTradeInDropOff,
                    userAddress: address,
                    safResponse: response,
                    freeShipmentCode: state.freeShipmentCheckoutData.findCode(order.cartUniqueIdentifier) ?? "",
                    merchantVoucherCoupons: state.promo.merchantVoucerCoupon[order.cartUniqueIdentifier] ?? [],
                    shipperPickerSource: .checkout
                )

                let scheduledDeliveryParams = ScheduledDeliveryRatesRequest(
                    logisticRatesParams: logisticRatesParams,
                    orderState: order,
                    cartData: response.cartData
                )

                let scheduledParam = ScheduledDeliveryParams(
                    scheduledDeliveryParams: scheduledDeliveryParams,
                    logisticRatesParams: logisticRatesParams,
                    ratesMetadata: RatesMetadata(cartData: state.cartData)
                )

                let requestType: ShipmentRequestType = {
                    if state.orders[id: order.id]?.shippingComponent == .scheduled {
                        return .scheduledDelivery(scheduledDeliveryParams)
                    } else {
                        return .scheduledDeliveryWithRates(scheduledParam)
                    }
                }()

                state.orders[id: order.id]?.scheduledDelivery = ScheduledDeliveryShipperState(
                    requestParams: requestType,
                    widgetExperience: state.shippingWidgetExperience,
                    orderShipperId: order.safScheduledDeliveryData.shipperId,
                    orderShipperProductId: order.safScheduledDeliveryData.shipperProductId,
                    validationMetadata: order.safScheduledDeliveryData.validationMetadata,
                    isUsingShopGroupInsurance: order.isInsurance,
                    isRecommend: order.safScheduledDeliveryData.isRecommended
                )
            }

            if state.orders.contains(where: { $0.shippingComponent.hasScheduled }) {
                effects.append(
                    environment
                        .sendAnalytics(AnalyticsEvent.viewScheduledDeliveryWidget())
                        .fireAndForget()
                )
            }

            let orderWithPreSelectedShipper = state.orders
                .filter { order -> Bool in
                    /**
                     If has scheduled delivery, we will use scheduled delivery shipper and the rates will be fetched in there
                     */
                    if order.shippingComponent.hasScheduled {
                        return false
                    }

                    /**
                     If it's tokonow and address is not pin pointed no need to fetch rates
                     */
                    if !order.isTokoNowPinPointed {
                        return false
                    }

                    /** If it has courierError for example there is no shipper provided for the item
                     then there is no need to fetch rates
                     */
                    if order.hasCourierError {
                        return false
                    }

                    /** check current shop group spId and shipping id
                     if any shop group have non 0 value, means we need to fetch rates and populate shipper info
                     but if isTradeIn, will always fetch, even invalid or 0 */

                    /** Also if it is autoCourierSelection, it will fetch rates and select the first shipper info
                     even if the shipperId is invalid */

                    /** If shop group has pre applied bo code, will fetch rates and populate shipper with matching code */

                    return (order.shipment?.shipperId != .invalid && order.shipment?.shipperProductId != .invalid) || state.mode.isTradeIn || order.autoCourierSelection || order.boCode.isNotEmpty
                }

            var promoWidgetViewData: PromoWidgetViewData = {
                let promoDescriptions = response.promo.additionalInfo.usageSummaries.map { PromoDescriptionViewData(with: $0) }

                let viewData: PromoWidgetViewData = PromoWidgetViewData(
                    titles: [response.promo.additionalInfo.messageInfo?.message ?? ""],
                    subtitle: response.promo.additionalInfo.messageInfo?.detail,
                    promoExists: promoDescriptions.isNotEmpty,
                    benefitAmount: response.promo.summaryInfo.benefitAmount,
                    leftIconUrl: promoDescriptions.isNotEmpty ? PromoWidgetImages.checklist.url : PromoWidgetImages.coupon.url,
                    useLeftIcon: promoDescriptions.isNotEmpty,
                    promoSummaries: promoDescriptions,
                    getPromoListRecomParam: nil
                )

                return viewData
            }()

            /// if no shop group have pre selected shipper, then all process finish
            /// or if showOnboarding true, will not fetch shipment
            guard orderWithPreSelectedShipper.isNotEmpty, !response.showOnboarding else {
                // remove loading after receiving response
                state.viewMode = .normal(overlay: nil)

                /**
                 Update promo widget's view data
                 */
                state.promo.widgetView = state.updatePromoWidgetDefaultData(from: promoWidgetViewData)

                /**
                 send analytics checkout page did load
                 */
                return .merge(effects)
            }

            state.promo.widgetView = CheckoutPromoWidgetData(
                view: .loadingContent,
                viewData: promoWidgetViewData
            )

            // set shipper node on selected shipper one to loading
            orderWithPreSelectedShipper.forEach {
                state.orders[id: $0.cartUniqueIdentifier]?.shipment?.mode = .loading
            }

            let params: [LogisticRatesParams] = orderWithPreSelectedShipper.map {
                LogisticRatesParams(
                    orderState: $0,
                    mode: state.mode,
                    isDropOff: state.isTradeInDropOff,
                    userAddress: address,
                    safResponse: response,
                    freeShipmentCode: state.freeShipmentCheckoutData.findCode($0.cartUniqueIdentifier) ?? "",
                    merchantVoucherCoupons: state.promo.merchantVoucerCoupon[$0.cartUniqueIdentifier] ?? [],
                    shipperPickerSource: .checkout
                )
            }

            let ratesResponses = params.map { element in
                environment.logisticRatesResponse(element, state.isTradeInDropOff, RatesMetadata(cartData: state.cartData))
                    .map {
                        IdentifiedLogisticRatesResponse(
                            id: element.cartUniqueIndentifier,
                            result: $0
                        )
                    }
            }

            effects.append(
                Observable.zip(ratesResponses)
                    .map { results -> CheckoutAction in
                        .logisticRatesResponse(results)
                    }
                    .eraseToEffect()
            )

            state.viewMode = .normal(overlay: .none)

            return .merge(effects)
        case let .failure(networkError):
            let callback = EmptyStateCallBack(
                ctaTitle: "Coba Lagi",
                ctaActions: [
                    .didLoad
                ]
            )

            let emptyStateData = EmptyStateData(
                from: networkError,
                callback: [callback]
            )

            state.viewMode = .error(emptyStateData)

            return .none
        }
    case let .logisticRatesResponse(results):
        /**
         All side effect from shops and will be executed by merge
         */
        var actions: [Effect<CheckoutAction>] = []

        results.forEach { result in
            switch result.result {
            case let .success(response):
                guard let selectedOrder = state.orders[id: result.id],
                    let selectedOrderShipment = selectedOrder.shipment
                else {
                    if let promoWidgetViewData = state.promo.widgetView.viewData {
                        state.promo.widgetView = state.updatePromoWidgetDefaultData(from: promoWidgetViewData)
                    }

                    return
                }

                // check if selected product is free shipment, to find selected one, use init from `SelectedShipper` that has the logic to find the selected shipment based on id
                var maybeSelectedShipper: SelectedShipmentData?

                /**
                 check selected BO promo from SAF response, when user open checkout page with pre-applied BO coupon,
                 and check selected BO promo from validate use after user apply BO coupon in promo page
                 */

                let orderBOCode = selectedOrder.logisticCode?.code ?? selectedOrder.boCode
                let selectedBOCoupon = response.promoStackings.first(where: { $0.promoCode == orderBOCode })

                /**
                 if shop group / order has BO code, but there is no matching code from rates promo stackings, clear BO cache
                 */

                if let boCode = orderBOCode, selectedBOCoupon == nil {
                    let orders = selectedOrder.shops.map { shop -> PromoOrderData in
                        PromoOrderData(
                            uniqueID: shop.id,
                            orderCartString: selectedOrder.cartUniqueIdentifier,
                            boType: selectedOrder.boType,
                            codes: [boCode],
                            shopID: shop.shopId.rawValue,
                            isPO: selectedOrder.isPreorder,
                            duration: String(shop.products.first?.preOrderDurationDays ?? 0),
                            warehouseID: selectedOrder.warehouseId.rawValue
                        )
                    }

                    let orderData = ClearCacheOrderParamData(
                        /// empty, we only clear logistic code
                        codes: [],
                        orders: orders
                    )

                    /// reset logistic code so it won't be used in next validate use
                    state.orders[id: selectedOrder.cartUniqueIdentifier]?.logisticCode = nil

                    actions.append(
                        environment
                            .resetFreeShipmentOnServer(orderData)
                            .map { (result) -> CheckoutAction in
                                .orders(identifier: selectedOrder.cartUniqueIdentifier,
                                        action: .receiveResetFreeShipment(result, forSelectedOption: nil, forSelectedScheduled: nil))
                            }
                            .eraseToEffect()
                    )
                }

                /**
                 autoCourierSelection value will be true when SAF return spId and shippingId = 0
                 This is used in tokonow case since in tokonow user won't be able to change courier.
                 Thus we will need to pick the courier for them by picking the first courier available.
                 Note that in this case the response from backend should only return 1 courier. So using .first is actually expected.
                 */
                if selectedOrder.autoCourierSelection,
                    let shipperId = response.services.first?.products.first?.shipperId,
                    let shipperProductId = response.services.first?.products.first?.id {
                    maybeSelectedShipper = selectedShipmentData(
                        from: response,
                        shipperId: shipperId,
                        shipperProductId: shipperProductId,
                        freeShipmentPriority: true,
                        checkoutMode: state.mode,
                        isChangeCourierEnabled: selectedOrder.isChangeCourierEnabled
                    )
                } else if let selectedBOCoupon = selectedBOCoupon,
                    let shipper = selectedShipmentData(
                        from: response,
                        shipperId: selectedBOCoupon.shipperId,
                        shipperProductId: selectedBOCoupon.shipperProductId,
                        freeShipmentPriority: true,
                        checkoutMode: state.mode,
                        isChangeCourierEnabled: selectedOrder.isChangeCourierEnabled
                    ) {
                    maybeSelectedShipper = shipper
                } else if let shipper = selectedShipmentData(
                    from: response,
                    shipperId: selectedOrderShipment.shipperId,
                    shipperProductId: selectedOrderShipment.shipperProductId,
                    freeShipmentPriority: true,
                    checkoutMode: state.mode,
                    isChangeCourierEnabled: selectedOrder.isChangeCourierEnabled
                ) {
                    maybeSelectedShipper = shipper
                } else {
                    state.orders[id: result.id]?.shipment?.mode = .empty

                    if let promoWidgetViewData = state.promo.widgetView.viewData {
                        state.promo.widgetView = state.updatePromoWidgetDefaultData(from: promoWidgetViewData)
                    }

                    return
                }

                if let tokonowBenefit = maybeSelectedShipper?.tokoNowBenefitDescription {
                    let viewBenefitTracker: Effect<CheckoutAction> = environment
                        .sendAnalytics(AnalyticsEvent.viewTokonowBenefitDesc(label: tokonowBenefit))
                        .fireAndForget()

                    actions.append(viewBenefitTracker)
                }

                var selectedService: LogisticRatesServiceResponse?
                var selectedProduct: LogisticRatesServiceProductResponse?

                /// Apply shipper from BO coupon
                if let selectedBOCoupon = selectedBOCoupon, let (ratesId, selectedDuration, selectedCourier) = SelectedShipmentData.selectedResponse(
                    from: response,
                    shipperId: selectedBOCoupon.shipperId,
                    shipperProductId: selectedBOCoupon.shipperProductId,
                    freeShipmentPriority: true,
                    checkoutMode: state.mode
                ),
                    selectedDuration.error == nil,
                    selectedCourier.error == nil {
                    selectedService = selectedDuration
                    selectedProduct = selectedCourier
                } else if
                    /// if there is no BO coupon, we select shipment based from `saved shipment` shippingId and spId from SAF
                    /// apply BO when shipper picker is disabled (tokonow) or when unstack toggling is off
                    let (ratesId, selectedDuration, selectedCourier) = SelectedShipmentData.selectedResponse(
                        from: response,
                        shipperId: selectedOrder.shipment?.shipperId ?? .invalid,
                        shipperProductId: selectedOrder.shipment?.shipperProductId ?? .invalid,
                        freeShipmentPriority: selectedOrder.shipment?.enableShipmentPickerInteraction == false || state.promo.isBOUnstackEnabled == false,
                        checkoutMode: state.mode
                    ),
                    /**
                        make sure selected duration and courier is not error
                        */
                    selectedDuration.error == nil,
                    selectedCourier.error == nil {
                    selectedService = selectedDuration
                    selectedProduct = selectedCourier
                } else {
                    // reset shipment
                    state.orders[id: result.id]?.shipment?.shipperId = .invalid
                    state.orders[id: result.id]?.shipment?.shipperProductId = .invalid
                    state.orders[id: result.id]?.shipment?.selectedShipmentData = nil
                    state.orders[id: result.id]?.shipment?.mode = .empty

                    if let promoWidgetViewData = state.promo.widgetView.viewData {
                        state.promo.widgetView = state.updatePromoWidgetDefaultData(from: promoWidgetViewData)
                    }

                    return
                }

                guard let selectedService = selectedService, let selectedProduct = selectedProduct else {
                    if let promoWidgetViewData = state.promo.widgetView.viewData {
                        state.promo.widgetView = state.updatePromoWidgetDefaultData(from: promoWidgetViewData)
                    }

                    return
                }

                /**
                 stimulate like user tap the shipper picker, because it share the same input and output to state.
                 */

                // selected BO from ratesv3 promo stackings
                let promoStacking = response.promoStackings.first(where: { $0.promoCode == selectedProduct.promoCode })

                let selectedOption = SelectedShipper(
                    previousShipperId: 0, // previous value, used only on shipper picker,
                    previousShipperProductId: 0, // previous value, used only on shipper picker,
                    previousIsFreeShipment: true, // default set true on did load, because there're no flag to determine current shipment is free shipment or not from backend. and this value also only being used on real picker as way to separate free shipment result.
                    mode: .courier,
                    option: ShipperPickerSelectedOption(
                        ratesId: response.ratesId,
                        selectedDuration: selectedService,
                        selectedCourier: selectedProduct,
                        promoStacking: promoStacking
                    )
                )

                /**
                 reuse action on shop group to populate shipment section on shop group.
                 the things done to the state is all the same, so reuse the function is the better way to solve it.

                 and it also more consistent.
                 */

                /**
                 When applying shipment to multiple orders at the same time, such as when:
                 - load checkout with multiple saved shipment
                 - load checkout when multiple BO are pre-applied (from cart)
                 - apply multiple BO from promo page in checkout page

                 we send the `receiveShipperPickerResult` action asynchronously.
                 This can cause problems when multiple BO are applied, as each order needs to hit validateUse to apply the BO.

                 For example:

                 Order 1
                 - receiveShipperPickerResult -> validateUse BO code for order 1
                 Order 2
                 - receiveShipperPickerResult -> validateUse  BO code for order 2

                 Because these actions run asynchronously, it causes issues in the promo backend as the system is unsure which promo to save.

                 To temporarily fix this issue, we need to add a delay when applying shipping to each order. A complete fix would require changing the entire flow of shipment and promo in the checkout page.
                 */

                let action = Effect<CheckoutAction>(
                    value: .orders(
                        identifier: selectedOrder.cartUniqueIdentifier,
                        action: .shipper(.receiveShipperPickerResult(selectedOption))
                    )
                )
                .delay(.milliseconds(150), scheduler: environment.mainScheduler())
                .eraseToEffect()

                actions.append(action)

            case .failure:
                if state.orders[id: result.id]?.shipment?.enableShipmentPickerInteraction == false {
                    if let promoWidgetViewData = state.promo.widgetView.viewData {
                        state.promo.widgetView = state.updatePromoWidgetDefaultData(from: promoWidgetViewData)
                    }

                    state.orders[id: result.id]?.shipment?.mode = ShipperMode.setTokoNowRatesErrorView(errorMessage: .nowErrorSubtitle)
                } else {
                    /// If auto apply BO then fail to hit rates, clear BO cache

                    if let order = state.orders[id: result.id], let boCode = order.logisticCode?.code ?? order.boCode {
                        let orders = order.shops.map { shop -> PromoOrderData in
                            PromoOrderData(
                                uniqueID: shop.id,
                                orderCartString: order.cartUniqueIdentifier,
                                boType: order.boType,
                                codes: [boCode],
                                shopID: shop.shopId.rawValue,
                                isPO: order.isPreorder,
                                duration: String(shop.products.first?.preOrderDurationDays ?? 0),
                                warehouseID: order.warehouseId.rawValue
                            )
                        }

                        let orderData = ClearCacheOrderParamData(
                            /// empty, we only clear logistic code
                            codes: [],
                            orders: orders
                        )

                        /// reset logistic code so it won't be used in next validate use
                        state.orders[id: order.cartUniqueIdentifier]?.logisticCode = nil

                        actions.append(
                            environment
                                .resetFreeShipmentOnServer(orderData)
                                .map { (result) -> CheckoutAction in
                                    .orders(identifier: order.cartUniqueIdentifier,
                                            action: .receiveResetFreeShipment(result, forSelectedOption: nil, forSelectedScheduled: nil))
                                }
                                .eraseToEffect()
                        )
                    } else if let promoWidgetViewData = state.promo.widgetView.viewData {
                        state.promo.widgetView = state.updatePromoWidgetDefaultData(from: promoWidgetViewData)
                    }

                    state.orders[id: result.id]?.shipment?.mode = .empty
                }
            }
        }

        return .concatenate(actions)
    case .tapBackOnDialogBox:
        guard state.productNeedConsultation else { return .none }

        state.exit = true

        var effects: [Effect<CheckoutAction>] = []
        effects.append(contentsOf: state.generateBackButtonTapEffects(environment: environment))

        let epharmacyGroupId = state.generateEpharmacyConsultationAnalyticsData().epharmacyGroupId
        effects.append(
            environment
                .sendAnalytics(.tapExitEpharmacyConsultationDialogBox(epharmacyGroupId: epharmacyGroupId,
                                                                      isPrescriptionAccepted: state.isApprovedPrescriptionExists)
                ).fireAndForget()
        )

        return .merge(effects)
    case .clearPrescriptionAttachmentDialogData:
        state.viewMode = .normal(overlay: nil)

        let epharmacyGroupId = state.generateEpharmacyConsultationAnalyticsData().epharmacyGroupId

        return environment
            .sendAnalytics(.tapContinuePaymentEpharmacyConsultationDialogBox(epharmacyGroupId: epharmacyGroupId,
                                                                             isPrescriptionAccepted: state.isApprovedPrescriptionExists)
            ).fireAndForget()
    case .tapDonation:
        guard !state.disabledFeatures.contains(.donation) else { return .none }

        state.donation?.checkboxViewData.isSelected.toggle()

        var effects: [Effect<CheckoutAction>] = [
            environment
                .sendAnalytics(.tapDonation(isSelected: state.donation?.checkboxViewData.isSelected ?? false,
                                            isTradeIn: state.mode.isTradeIn,
                                            isTradeInDropOff: state.isTradeInDropOff))
                .fireAndForget()
        ]

        if state.isDdp {
            if let index = state.dynamicDataParams.firstIndex(where: { $0.attribute == .donation }) {
                state.dynamicDataParams[index].donation = state.donation?.checkboxViewData.isSelected
            } else {
                let donationParam = DynamicDataParam(
                    level: .payment,
                    parentUniqueId: "",
                    uniqueId: "",
                    attribute: .donation,
                    donation: state.donation?.checkboxViewData.isSelected,
                    addon: nil
                )

                state.dynamicDataParams.append(donationParam)
            }

            let param = UpdateDynamicDataParams(data: state.dynamicDataParams)

            effects.append(
                environment
                    .updateDynamicDataResponse(param)
                    .map { CheckoutAction.updateDynamicDataResponse($0) }
                    .eraseToEffect()
            )
        }

        return .merge(effects)

    case let .updateDynamicDataResponse(result):
        if case let .success(response) = result {
            state.dynamicData = response.dynamicData
        }

        return .none

    case let .orders(identifier, action: .shipper(.refreshRates)):
        var effects: [Effect<CheckoutAction>] = [environment.sendAnalytics(AnalyticsEvent.tapRefreshRatesButton()).fireAndForget()]

        guard let orderState = state.orders.first(where: { $0.id == identifier })
        else { return .none }

        guard let address = getAddress(isTradeInDropOff: state.isTradeInDropOff, addressState: state.address)
        else { return .none }

        // set shipper node on selected shipper one to loading
        state.orders[id: identifier]?.shipment?.mode = .loading

        let param: LogisticRatesParams = LogisticRatesParams(
            orderState: orderState,
            mode: state.mode,
            userAddress: address,
            token: state.keroToken,
            unixTime: state.keroUnixTime,
            codCount: state.cod.count,
            freeShipmentCode: state.freeShipmentCheckoutData.findCode(orderState.cartUniqueIdentifier) ?? "",
            isTradeIn: {
                if state.mode.isTradeIn {
                    if state.isTradeInDropOff {
                        return .tradeInDropOff
                    } else {
                        return .tradeIn
                    }
                } else {
                    return .notTradeIn
                }
            }(),
            merchantVoucherCoupons: state.promo.merchantVoucerCoupon[orderState.cartUniqueIdentifier] ?? [],
            shipperPickerSource: .checkout
        )

        let ratesResponse = environment
            .logisticRatesResponse(param, state.isTradeInDropOff, RatesMetadata(cartData: state.cartData))
            .map {
                IdentifiedLogisticRatesResponse(
                    id: param.cartUniqueIndentifier,
                    result: $0
                )
            }

        effects.append(
            Observable.zip([ratesResponse])
                .map { results -> CheckoutAction in
                    .logisticRatesResponse(results)
                }
                .eraseToEffect()
        )

        return .merge(effects)
    case let .orders(identifier, action: .shipper(.refreshSaf)):
        return Effect(value: .didLoad)

    case let .orders(identifier, action: .shop(shopIdentifier, action: .product(productIdentifier, action: .addOnAction(.didLoad)))):
        guard
            let order = state.orders[id: identifier],
            let shopState = order.shops[id: shopIdentifier],
            let productState = shopState.products[id: productIdentifier]
        else {
            return .none
        }

        return environment
            .sendAnalytics(.impressionAddOnWidget(productId: String(productState.id.rawValue)))
            .fireAndForget()

    case let .orders(identifier, action: .shop(shopIdentifier, action: .cartDetails(detailIdentifier, action: .product(productIdentifier, action: .addOnAction(.didLoad))))):
        guard
            let order = state.orders[id: identifier],
            let shopState = order.shops[id: shopIdentifier],
            let cartDetailState = shopState.cartDetailState[id: detailIdentifier],
            let productState = cartDetailState.productState[id: productIdentifier]
        else {
            return .none
        }

        return environment
            .sendAnalytics(.impressionAddOnWidget(productId: String(productState.id.rawValue)))
            .fireAndForget()

    case let .orders(identifier, action: OrderAction.addOnAction(.didLoad)):
        guard let order = state.orders[id: identifier] else { return .none }

        return environment
            .sendAnalytics(.impressionAddOnWidget(productId: order.productIds))
            .fireAndForget()

    case let .orders(identifier, action: .shop(shopIdentifier, action: .product(productIdentifier, action: .addOnAction(.userTapAddonCard)))):
        // User tap on add on widget, product level
        guard
            let order = state.orders[id: identifier],
            let shopState = order.shops[id: shopIdentifier],
            let productState = shopState.products[id: productIdentifier]
        else {
            return .none
        }

        let addon = productState.addOnState.addOn

        if addon.addOnButtonData.isEnabledAction, let isAddOnEnabled = addon.isEnabledButton {
            guard isAddOnEnabled else {
                state.addOnDisabledBottomsheetData = addon.addOnDisableInfoData()
                return .none
            }

            state.selectedAddOnBottomsheet = .product(orderIdentifier: identifier, shopIdentifier: shopIdentifier, productIdentifier: productIdentifier)
            state.addOnBottomsheetData = addon.addOnSelectionRequestParams(
                products: [productState],
                warehouseId: String(order.warehouseId.rawValue),
                order: order,
                addOnWording: state.addOnWording,
                recipentName: state.address.address?.getReceiverNameIfActiveAddress ?? "",
                mode: state.mode
            )

            return environment
                .sendAnalytics(.clickAddOnWidget(productId: String(productState.id.rawValue)))
                .fireAndForget()
        } else { return .none }

    case let .orders(identifier, action: .shop(shopIdentifier, action: .cartDetails(detailIdentifier, action: .product(productIdentifier, action: .addOnAction(.userTapAddonCard))))):
        guard
            let order = state.orders[id: identifier],
            let shopState = order.shops[id: shopIdentifier],
            let cartDetailState = shopState.cartDetailState[id: detailIdentifier],
            let productState = cartDetailState.productState[id: productIdentifier]
        else {
            return .none
        }

        let addon = productState.addOnState.addOn

        if addon.addOnButtonData.isEnabledAction, let isAddOnEnabled = addon.isEnabledButton {
            guard isAddOnEnabled else {
                state.addOnDisabledBottomsheetData = addon.addOnDisableInfoData()
                return .none
            }

            state.selectedAddOnBottomsheet = .cartDetail(orderIdentifier: identifier, shopIdentifier: shopIdentifier, cartDetailIdentifier: detailIdentifier, productIdentifier: productIdentifier)
            state.addOnBottomsheetData = addon.addOnSelectionRequestParams(
                products: [productState],
                warehouseId: String(order.warehouseId.rawValue),
                order: order,
                addOnWording: state.addOnWording,
                recipentName: state.address.address?.getReceiverNameIfActiveAddress ?? "",
                mode: state.mode
            )

            return environment
                .sendAnalytics(.clickAddOnWidget(productId: String(productState.id.rawValue)))
                .fireAndForget()
        } else { return .none }

    case let .orders(identifier, action: OrderAction.addOnAction(.userTapAddonCard)):
        // User tap on add on widget, shop group level

        guard let order = state.orders[id: identifier] else { return .none }

        let addon = order.addOnState.addOn

        if addon.addOnButtonData.isEnabledAction, let isAddOnEnabled = addon.isEnabledButton {
            guard isAddOnEnabled else {
                state.addOnDisabledBottomsheetData = addon.addOnDisableInfoData()
                return .none
            }

            var products: [ProductState] = []
            order.shops.forEach { shop in
                // append normal products in order
                products.append(contentsOf: shop.products)

                shop.cartDetailState.forEach { cartDetail in
                    // append bundle products in order
                    products.append(contentsOf: cartDetail.productState)
                }
            }

            state.selectedAddOnBottomsheet = .order(orderIdentifier: identifier)
            state.addOnBottomsheetData = addon.addOnSelectionRequestParams(
                products: products,
                warehouseId: String(order.warehouseId.rawValue),
                order: order,
                addOnWording: state.addOnWording,
                recipentName: state.address.address?.getReceiverNameIfActiveAddress ?? "",
                mode: state.mode
            )

            return environment
                .sendAnalytics(.clickAddOnWidget(productId: order.productIds))
                .fireAndForget()
        } else { return .none }

    case let .orders(identifier, action: .shop(shopIdentifier, action: .product(productIdentifier, action: .addOnAction(.userTapAddOnDetail(addOnType))))):
        return environment
            .sendAnalytics(.sendClicksInfoButtonOfAddons("\(addOnType)"))
            .fireAndForget()

    case .orders(_, action: OrderAction.scheduledDelivery(.showScheduledDeliveryCoachmark)):
        state.coachMarkTarget = {
            guard let order = state.orders.first(where: { $0.shippingComponent.hasScheduled }) else { return [] }
            return [.orderScheduledShipment(identifier: order.cartUniqueIdentifier, userID: environment.getLocalUserId())]
        }()

        return .none

    case .resetAddOnBottomsheetData:
        state.addOnBottomsheetData = nil
        return .none

    case .resetAddOnDisabledBottomsheetData:
        state.addOnDisabledBottomsheetData = nil
        return .none

    case let .receiveGiftingBottomsheetCompletion(addOns):
        var effects: [Effect<CheckoutAction>] = []

        if let addOn = addOns.first { // Bottomsheet return array of addOn, but currently we only support 1
            switch state.selectedAddOnBottomsheet {
            case let .order(orderIdentifier):
                state.orders[id: orderIdentifier]?.addOnState.addOn = addOn

            case let .product(orderIdentifier, shopIdentifier, productIdentifier):
                state.orders[id: orderIdentifier]?.shops[id: shopIdentifier]?.products[id: productIdentifier]?.addOnState.addOn = addOn

            case let .cartDetail(orderIdentifier, shopIdentifier, cartDetailIdentifier, productIdentifier):
                state.orders[id: orderIdentifier]?.shops[id: shopIdentifier]?.cartDetailState[id: cartDetailIdentifier]?.productState[id: productIdentifier]?.addOnState.addOn = addOn

            case nil:
                break
            }
        }

        if state.isDdp, let addOn = addOns.first, let addOnBottomSheet = state.selectedAddOnBottomsheet {
            var level = DynamicDataParamLevel.payment
            var parentUniqueId = ""
            var uniqueId = ""

            switch addOnBottomSheet {
            case let .order(orderIdentifier):
                level = .order
                uniqueId = orderIdentifier.rawValue

            case let .product(orderIdentifier, shopIdentifier, productIdentifier):
                level = .product
                parentUniqueId = orderIdentifier.rawValue
                uniqueId = "\(state.orders[id: orderIdentifier]?.shops[id: shopIdentifier]?.products[id: productIdentifier]?.cartId ?? 0)"

            // DDP is no longer used, will remove it later. Thus, this part doesn't need to be implemented
            case let .cartDetail(orderIdentifier, shopIdentifier, detailIdentifier, productIdentifier):
                break
            }

            let addOnData = addOn.addOnDetailData.map { addOnDetail -> DynamicDataSaveAddOn in
                DynamicDataSaveAddOn(
                    addOnId: addOnDetail.addOnId.intValue,
                    addOnQty: addOnDetail.addOnQty,
                    addOnMetadata: DynamicDataSaveAddOnMetadata(
                        addOnNote: DynamicDataSaveAddOnNote(
                            isCustomNote: addOnDetail.addOnMetaData.addOnNote.isCustom,
                            to: addOnDetail.addOnMetaData.addOnNote.recipientName,
                            from: addOnDetail.addOnMetaData.addOnNote.senderName,
                            notes: addOnDetail.addOnMetaData.addOnNote.notes
                        )
                    )
                )
            }

            let source = {
                switch state.mode {
                case .default: return "normal"
                case .oneClickShipment: return "ocs"
                }
            }()

            let dynamicDataParam = DynamicDataParam(
                level: level,
                parentUniqueId: parentUniqueId,
                uniqueId: uniqueId,
                attribute: .addOn,
                donation: nil,
                addon: DynamicDataAddOn(
                    addOnData: addOnData,
                    source: source
                )
            )

            state.dynamicDataParams.removeAll(where: { $0.attribute == .addOn && $0.parentUniqueId == parentUniqueId && $0.uniqueId == uniqueId })
            state.dynamicDataParams.append(dynamicDataParam)

            let param = UpdateDynamicDataParams(data: state.dynamicDataParams)
            effects.append(
                environment
                    .updateDynamicDataResponse(param)
                    .map { CheckoutAction.updateDynamicDataResponse($0) }
                    .eraseToEffect()
            )
        }

        state.selectedAddOnBottomsheet = nil

        return .merge(effects)

    case .plusWidget(.buttonTap):
        guard let plusWidgetData = state.gotoPlusWidgetDataV2
        else { return .none }

        var effects: [Effect<CheckoutAction>] = []

        if plusWidgetData.isSelected {
            // Cancel subscription
            state.isPlusWidgetSelected = false

            effects.append(
                environment
                    .sendAnalytics(AnalyticsEvent.tapGotoplusCrossSellCancel())
                    .fireAndForget()
            )

            effects.append(Effect(value: .clearPlusFreeShipping))
            effects.append(Effect(value: .didLoad))
        } else {
            guard plusWidgetData.applink.isNotEmpty else { return .none }
            // Open PLUS webview
            state.plusWebviewURL = plusWidgetData.applink

            effects.append(
                environment
                    .sendAnalytics(AnalyticsEvent.tapGotoplusCrossSell())
                    .fireAndForget()
            )
        }

        return .merge(effects)

    case let .plusStateFromWebview(isPlusSelected):
        state.isPlusWidgetSelected = isPlusSelected

        var effects: [Effect<CheckoutAction>] = []

        if !isPlusSelected {
            effects.append(Effect(value: .clearPlusFreeShipping))
        }

        effects.append(Effect(value: .didLoad))

        return .merge(effects)

    case .clearPlusLink:
        state.plusWebviewURL = nil
        return .none

    case .clearPlusFreeShipping:
        /* Clear free shipping when
         - User opt out of PLUS subscription
         - User back to cart
         - User change address
         */
        guard let order = state.orders.first(where: { $0.shipment?.selectedShipmentData?.isFreeShipment == true }),
            let freeShipmentPromoCode = order.shipment?.selectedShipmentData?.freeShipmentPromoCode
        else { return .none }

        let orders = order.shops.map { shop -> PromoOrderData in
            PromoOrderData(
                uniqueID: shop.id,
                orderCartString: order.cartUniqueIdentifier,
                boType: order.boType,
                codes: [freeShipmentPromoCode],
                shopID: shop.shopId.rawValue,
                isPO: order.isPreorder,
                duration: String(shop.products.first?.preOrderDurationDays ?? 0),
                warehouseID: order.warehouseId.rawValue
            )
        }

        let orderData = ClearCacheOrderParamData(
            codes: [],
            orders: orders
        )

        return environment
            .resetFreeShipmentOnServer(orderData)
            .fireAndForget()

    case let .checkUploadedPrescription(epharmacyWidgetData):
        if let checkoutID = epharmacyWidgetData.checkoutID {
            if state.productNeedConsultation {
                return environment
                    .checkUploadedConsultationData()
                    .map {
                        CheckoutAction.receiveConsultationPrescription(
                            epharmacyConsultationData: $0,
                            epharmacyConsultationWidgetData: epharmacyWidgetData
                        )
                    }
                    .eraseToEffect()
            }

            return environment
                .checkUploadedPrescriptionID(checkoutID, .checkout)
                .map {
                    CheckoutAction.receiveUploadedPrescription(
                        epharmacyData: $0,
                        epharmacyWidgetData: epharmacyWidgetData
                    )
                }
                .eraseToEffect()
        } else {
            /// Show upload button
            state.uploadPrescriptionState = UploadPrescriptionState(
                mode: .content(UploadPrescriptionRootState(data: epharmacyWidgetData))
            )
            return .none
        }

    case let .receiveUploadedPrescription(epharmacyData, epharmacyWidgetData):
        switch epharmacyData {
        case let .success(data):
            state.prescriptionIDs = data.prescriptionImages.map { PrescriptionID(rawValue: $0.prescriptionId) }

            /// Show upload buttonpres
            state.uploadPrescriptionState = UploadPrescriptionState(
                mode: .content(
                    UploadPrescriptionRootState(
                        data: epharmacyWidgetData,
                        subtitle: String.uploadedPrescriptionSubtitle(state.prescriptionIDs.count)
                    )
                )
            )

            state.productStillNeedPrescriptionMessage = state.prescriptionIDs.isEmpty ? String.userNotYetUploadPrescription : ""

        case .failure:
            /// Show upload button
            state.uploadPrescriptionState = UploadPrescriptionState(
                mode: .content(UploadPrescriptionRootState(data: epharmacyWidgetData))
            )
        }

        return .none

    case .uploadPrescription(.root(.uploadButtonDidTapped)):
        guard let root = state.uploadPrescriptionState?.mode,
            let checkoutID = extract(case: UploadPrescriptionState.ViewMode.content, from: root)?.checkoutID else { return .none }

        let cartID = state.orders
            .flatMap { $0.shops.flatMap { $0.products } }
            .compactMap { product -> String? in
                guard product.ethicalDrug != nil else { return nil }
                return String(product.cartId)
            }
            .joined(separator: ",")

        guard state.productNeedConsultation else {
            return .merge(
                environment
                    .openUploadPrescriptionPage(checkoutID, .checkout)
                    .map(CheckoutAction.receivePrescriptionID)
                    .eraseToEffect(),
                environment
                    .sendAnalytics(.sendClickUploadPrescriptionWidget(cartId: cartID))
                    .fireAndForget()
            )
        }

        /// Mini Consultation analytics
        var consultationPrescriptionState: String = "empty"

        if state.isApprovedPrescriptionExists {
            consultationPrescriptionState = "success"
        } else if state.allConsultationProductsRejected {
            consultationPrescriptionState = "failed"
        }

        let analyticsData = state.generateEpharmacyConsultationAnalyticsData()

        return .merge(
            environment
                .openPrescriptionAttachmentPage()
                .map(CheckoutAction.receiveConsultationPrescriptionListData)
                .eraseToEffect(),
            environment
                .sendAnalytics(.tapEpharmacyConsultationWidget(widgetState: consultationPrescriptionState,
                                                               analyticsData: analyticsData)
                ).fireAndForget()
        )

    case let .receivePrescriptionID(prescriptionIDs):
        /// Update upload button subtitle
        state.uploadPrescriptionState?.mode.content?.subtitle = String.uploadedPrescriptionSubtitle(prescriptionIDs.count)
        state.uploadPrescriptionState?.mode.content?.isHighlighted = prescriptionIDs.isEmpty
        state.prescriptionIDs = prescriptionIDs
        state.productStillNeedPrescriptionMessage = state.prescriptionIDs.isEmpty ? String.userNotYetUploadPrescription : ""
        return .none

    case let .receiveConsultationPrescription(epharmacyConsultationData, epharmacyConsultationWidgetData):
        switch epharmacyConsultationData {
        case let .success(data):
            let prescriptionImages = data.checkoutPrescriptionData.flatMap { $0.prescriptionImages }
            let consultationData = data.checkoutPrescriptionData.flatMap { $0.consultationData }.filter { $0.consultationStatus == .approved && $0.prescriptionIds.isNotEmpty }
            let widgetData = generateEpharmacyWidgetData(
                from: data.checkoutPrescriptionData,
                title: epharmacyConsultationWidgetData.text
            )

            var newWidgetData = epharmacyConsultationWidgetData
            newWidgetData.text = widgetData.title

            /// Update shop group state
            let updatedOrderData = updateOrder(prescriptionData: data.checkoutPrescriptionData, order: state.orders, rejectedTickerContent: state.rejectedTickerContent)

            state.orders = updatedOrderData.orderState

            if updatedOrderData.needPrescriptionCount > 0 {
                state.productStillNeedPrescriptionMessage = String.someProductStillNeedPrescription(updatedOrderData.needPrescriptionCount) ?? ""
            } else {
                state.productStillNeedPrescriptionMessage = ""
            }

            /// Update upload button contents
            state.uploadPrescriptionState = UploadPrescriptionState(
                mode: .content(
                    UploadPrescriptionRootState(
                        data: newWidgetData,
                        subtitle: widgetData.subtitle
                    )
                )
            )

            /* Update upload prescription state based on PPG response containing checkoutError if user has manipulated the quanity in cart which is not in range of doctor's recommended quantity */
            if let checkoutError = data.checkoutError {
                state.uploadPrescriptionState?.mode.content?.isHighlighted = true
                state.uploadPrescriptionState?.mode.content?.isCheckoutFlowApprovedByPPG = false
                state.uploadPrescriptionState?.mode.content?.subtitle = checkoutError
            }

            state.epharmApprovedDataCount = widgetData.approvedData

        case .failure:
            /// Show upload button
            state.uploadPrescriptionState = UploadPrescriptionState(
                mode: .content(UploadPrescriptionRootState(data: epharmacyConsultationWidgetData))
            )
        }

        return (state.isRejectedConsultationPrescriptionExist || state.isApprovedPrescriptionExists) ? Effect(value: CheckoutAction.resetPromoMiniConsultation) : .none

    case let .receiveConsultationPrescriptionListData(prescriptionData):
        let prescriptionImages = prescriptionData.flatMap { $0.prescriptionImages }
        let consultationData = prescriptionData.flatMap { $0.consultationData }.filter { $0.consultationStatus == .approved && $0.prescriptionIds.isNotEmpty }
        let widgetData = generateEpharmacyWidgetData(
            from: prescriptionData,
            title: state.uploadPrescriptionState?.mode.content?.title ?? String.consultationPrescriptionTitle(true)
        )

        /// Update shop group state
        let updatedOrderData = updateOrder(prescriptionData: prescriptionData, order: state.orders, rejectedTickerContent: state.rejectedTickerContent)

        state.orders = updatedOrderData.orderState

        if updatedOrderData.needPrescriptionCount > 0 {
            state.productStillNeedPrescriptionMessage = String.someProductStillNeedPrescription(updatedOrderData.needPrescriptionCount) ?? ""
        } else {
            state.productStillNeedPrescriptionMessage = ""
        }

        /// Update upload button contents
        state.uploadPrescriptionState?.mode.content?.title = widgetData.title
        state.uploadPrescriptionState?.mode.content?.subtitle = widgetData.subtitle
        state.uploadPrescriptionState?.mode.content?.isHighlighted = false

        state.epharmApprovedDataCount = widgetData.approvedData

        return (state.isRejectedConsultationPrescriptionExist || state.isApprovedPrescriptionExists) ? Effect(value: CheckoutAction.resetPromoMiniConsultation) : .none

    case .resetPromoMiniConsultation:
        var effects: [Effect<CheckoutAction>] = []

        var orderData = ClearCacheOrderParamData(
            codes: [],
            orders: []
        )

        state.orders = state.orders
            .map { order -> OrderState in
                var newOrder = order

                var logisticCode: [String] = []
                if let orderLogisticCode = newOrder.logisticCode?.code {
                    logisticCode = [orderLogisticCode]
                }

                if (newOrder.orderConsultationStatus == .rejected) || newOrder.prescriptionIds.isNotEmpty {
                    let orders = newOrder.shops.map { shop -> PromoOrderData in
                        let merchantCode: [String] = shop.merchantCodes.map { $0.code }

                        return PromoOrderData(
                            uniqueID: shop.id,
                            orderCartString: newOrder.cartUniqueIdentifier,
                            boType: newOrder.boType,
                            codes: logisticCode + merchantCode,
                            shopID: shop.shopId.rawValue,
                            isPO: newOrder.isPreorder,
                            duration: String(shop.products.first?.preOrderDurationDays ?? 0),
                            warehouseID: newOrder.warehouseId.rawValue
                        )
                    }

                    orderData.orders.append(contentsOf: orders)

                    newOrder.logisticCode = nil

                    newOrder.shops = newOrder.shops
                        .map { shop in
                            var newShop = shop
                            newShop.merchantCodes = []
                            return newShop
                        }
                }

                return newOrder
            }

        effects.append(environment.resetFreeShipmentOnServer(orderData).fireAndForget())

        effects.append(
            state.resetPromo(
                shouldResetShipment: false,
                environment: environment.promoEnvironment
            )
            .flatMap { _ in Effect.none }
        )

        return .merge(effects)

    case .uploadPrescription(.root(.stopUploadPrescriptionWiggle)):
        state.uploadPrescriptionState?.mode.content?.wiggling = false
        return .none

    case .summary(.refetchPaymentFee):
        guard var paymentFeeParams = state.paymentFeeParams else { return .none }

        /**
         Hide platform fee ticker when triggered
         */
        state.paymentFeeData.paymentFeeTickerMessage = nil

        paymentFeeParams.paymentAmount = Float(state.summary.totalCheckoutWithoutPaymentFee.rawValue)

        return environment.paymentFeeResponse(paymentFeeParams)
            .map(CheckoutAction.receivePaymentFeeResponse)
            .eraseToEffect()

    case .summary(.tapTooltipButton):
        guard let fee = state.paymentFeeData.feeData?.fee.rawValue else { return .none }

        let analyticsData = CheckoutPaymentFeeAnalyticsData(fee: Int(fee), userId: environment.getLocalUserId())

        return environment
            .sendAnalytics(.tapPaymentFeeInfoIcon(data: analyticsData)).fireAndForget()

    case .summary(.tapChevron):
        state.expandPaymentDetails.toggle()
        return .none

    case .summary(.tapEGoldCheckbox):
        return Effect(value: .tapEGold)

    case .summary(.tapEGoldTermsAndConditions):
        return Effect(value: .tapEGoldTermsAndConditions)

    case .summary(.tapTermsAndConditions):
        return environment
            .sendAnalytics(.sendClickSnkAsuransiDanProteksi())
            .fireAndForget()

    case let .receivePaymentFeeResponse(result):
        switch result {
        case let .success(response):
            /**
             Do the following when success get platform fee data:
             - Update current platform fee data
             - Currently data provided on `getPaymentFeeCheckout` is only 1 data, which is used for platform fee
             - Update data in SummaryState from loading to normal state
             - Update current total price to latest total price
             - Hide ticker for error message
             */
            state.paymentFeeData.feeData = response.data
            state.paymentFeeData.viewMode = .normal
            state.paymentFeeData.currentTotalPrice = state.summary.totalCheckout
            state.paymentFeeData.paymentFeeTickerMessage = nil

            guard let fee = state.paymentFeeData.feeData?.fee.rawValue else { return .none }

            let analyticsData = CheckoutPaymentFeeAnalyticsData(fee: Int(fee), userId: environment.getLocalUserId())

            return environment
                .sendAnalytics(.viewPaymentFee(data: analyticsData)).fireAndForget()
        case let .failure:
            /**
             Do the following when failed get platform fee data:
             - Update data in SummaryState from loading to normal state
             - Hide platform fee data from UI
             - Update current error message on ticker
             */
            state.paymentFeeData.viewMode = .normal
            state.paymentFeeData.feeData = nil
            state.paymentFeeData.paymentFeeTickerMessage = state.paymentFeeErrorMesssage
            return .none
        }

    case .viewAddOnPicker:
        guard state.orders.contains(where: { $0.enabledValidProducts.contains { $0.addOnPickerData != nil } }) else { return .none }

        var effects: [Effect<CheckoutAction>] = []

        state.safAddOnServiceSummary.forEach { summary in
            let productId = state.orders
                .flatMap { $0.enabledValidProducts }
                .filter { product -> Bool in
                    guard let addOnPickerData = product.addOnPickerData else { return false }
                    return addOnPickerData.details.contains(where: { $0.type == summary.type })
                }
                .map { String($0.id.rawValue) }
                .joined(separator: ",")

            guard let productId = productId else { return }

            let viewAddOnPickerEvent: Effect<CheckoutAction> = environment
                .sendAnalytics(.viewAddOnPicker(addOnType: "\(summary.type)", productId: productId))
                .fireAndForget()
            effects.append(viewAddOnPickerEvent)
        }

        return .merge(effects)

    default:
        return .none
    }
}

internal let egoldReducer = Reducer<CheckoutState, CheckoutAction, CheckoutEnvironment> { state, action, environment in
    switch action {
    case .tapEGold:
        guard !state.disabledFeatures.contains(.egold) else { return .none }

        state.egold?.checkboxViewData.isSelected.toggle()

        var effects: [Effect<CheckoutAction>] = [
            environment
                .sendAnalytics(.tapEGold(isSelected: state.egold?.checkboxViewData.isSelected ?? false,
                                         isTradeIn: state.mode.isTradeIn,
                                         isTradeInDropOff: state.isTradeInDropOff))
                .fireAndForget()
        ]

        let productCategoryIds = state.orders
            .map { $0.productCategoryIds }
            .joined(separator: ",")

        if state.egold?.checkboxViewData.isSelected == true {
            effects.append(
                environment
                    .sendAnalytics(.checkEGold(productCategoryIds: productCategoryIds, userId: environment.getLocalUserId()))
                    .fireAndForget()
            )
        } else if state.egold?.checkboxViewData.isSelected == false {
            effects.append(
                environment
                    .sendAnalytics(.uncheckEGold(productCategoryIds: productCategoryIds, userId: environment.getLocalUserId()))
                    .fireAndForget()
            )
        }

        return .merge(effects)
    case .tapEGoldTermsAndConditions:
        guard let urlString = state.egold?.checkboxViewData.hyperlinkText?.url else { return .none }

        return environment
            .routeWithUrl(urlString)
            .fireAndForget()
    case .tapDonation,
         .promo(.validateCouponResponse),
         .promo(.resetPromo),
         .orders(_, action: .shipper(.receiveShipperPickerResult)),
         .orders(_, action: .shop(_, action: .product(_, action: .userTapPurchaseProtectionCheckbox))),
         .orders(_, action: .shop(_, action: .cartDetails(_, action: .product(_, action: .userTapPurchaseProtectionCheckbox)))),
         .orders(_, action: .shipper(.insurance(.didTap))),
         .orders(_, action: .scheduledDelivery(.insurance(.didTap))),
         .orders(_, action: .shop(_, action: .product(_, action: .receiveAddonPickerCallback))),
         .orders(_, action: .shop(_, action: .cartDetails(_, action: .product(_, action: .receiveAddonPickerCallback)))):
        guard !state.disabledFeatures.contains(.egold) else { return .none }

        let totalCheckoutWithoutPreviousEgold = state.summary.totalCheckoutWithoutPaymentFee - (state.summary.totalEgold ?? 0)
        state.egold?.recalculateAmount(with: totalCheckoutWithoutPreviousEgold)

        return .none

    /// Apply or unapply BO coupon after user select / unselect coupon from promo page
    case .promo(.setBOCoupon):

        var effects: [Effect<CheckoutAction>] = []

        /// Get shop groups with valid BO Coupon to apply BO shipment
        let orderWithValidBOCoupon = state.orders.filter { $0.logisticCode != nil && $0.logisticCode?.isValid == true }

        /// Get shop groups with removed BO coupon to unapply BO shipment
        let orderWithBOCouponRemoved = state.orders.filter { $0.logisticCode == nil && $0.shipment?.selectedShipmentData?.isFreeShipment == true }

        guard let address = getAddress(isTradeInDropOff: state.isTradeInDropOff, addressState: state.address) else { return .none }

        if orderWithValidBOCoupon.isNotEmpty {
            /** If shop groups have valid BO coupon, shop group hit rates
             from rates response we will find BO shipment by matching the bo promo code with promo stacking response
             */

            orderWithValidBOCoupon.forEach {
                state.orders[id: $0.cartUniqueIdentifier]?.shipment?.mode = .loading
            }

            let params = orderWithValidBOCoupon.map {
                LogisticRatesParams(
                    orderState: $0,
                    mode: state.mode,
                    userAddress: address,
                    token: state.keroToken,
                    unixTime: state.keroUnixTime,
                    codCount: state.cod.count,
                    freeShipmentCode: $0.logisticCode?.code ?? "",
                    isTradeIn: {
                        if state.mode.isTradeIn {
                            if state.isTradeInDropOff {
                                return .tradeInDropOff
                            } else {
                                return .tradeIn
                            }
                        } else {
                            return .notTradeIn
                        }
                    }(),
                    merchantVoucherCoupons: state.promo.merchantVoucerCoupon[$0.cartUniqueIdentifier] ?? [],
                    shipperPickerSource: .checkout
                )
            }

            let ratesResponses = params.map { element in
                environment.logisticRatesResponse(element, state.isTradeInDropOff, RatesMetadata(cartData: state.cartData))
                    .map {
                        IdentifiedLogisticRatesResponse(
                            id: element.cartUniqueIndentifier,
                            result: $0
                        )
                    }
            }

            effects.append(
                Observable.zip(ratesResponses)
                    .map { results -> CheckoutAction in
                        .logisticRatesResponse(results)
                    }
                    .eraseToEffect()
            )
        }

        if orderWithBOCouponRemoved.isNotEmpty {
            /// If shop groups have removed bo coupon from promo page (clasing or unselected)
            orderWithBOCouponRemoved.forEach {
                /// Clear Cache BO after unapply

                if let order = state.orders[id: $0.cartUniqueIdentifier], let boCode = order.shipment?.selectedShipmentData?.freeShipmentPromoCode {
                    let orders = order.shops.map { shop -> PromoOrderData in
                        PromoOrderData(
                            uniqueID: shop.id,
                            orderCartString: order.cartUniqueIdentifier,
                            boType: order.boType,
                            codes: [boCode],
                            shopID: shop.shopId.rawValue,
                            isPO: order.isPreorder,
                            duration: String(shop.products.first?.preOrderDurationDays ?? 0),
                            warehouseID: order.warehouseId.rawValue
                        )
                    }

                    let orderData = ClearCacheOrderParamData(
                        /// empty, we only clear logistic code
                        codes: [],
                        orders: orders
                    )

                    effects.append(environment.resetFreeShipmentOnServer(orderData)
                        .fireAndForget())
                }

                /// reset shipment
                state.orders[id: $0.cartUniqueIdentifier]?.shipment?.shipperId = .invalid
                state.orders[id: $0.cartUniqueIdentifier]?.shipment?.shipperProductId = .invalid
                state.orders[id: $0.cartUniqueIdentifier]?.shipment?.selectedShipmentData = nil
                state.orders[id: $0.cartUniqueIdentifier]?.shipment?.mode = .empty

                /// reset logistic code so it won't be used in next validate use
                state.orders[id: $0.cartUniqueIdentifier]?.logisticCode = nil

                if let index = state.orders.firstIndex(where: { $0.id == $0.cartUniqueIdentifier }) {
                    /// shipment picker micro interaction
                    state.orders[id: $0.cartUniqueIdentifier]?.shipment?.isHighlighted = true
                    state.orders[id: $0.cartUniqueIdentifier]?.shipment?.wiggling = true
                }
            }

            /// Since it's possible to remove BO on multiple order, we only set the focus target on the first shop group

            if let firstOrder = orderWithBOCouponRemoved.first, let index = state.orders.firstIndex(where: { $0.id == firstOrder.cartUniqueIdentifier }) {
                state.focusTarget = .orderShipment(index: index)
            }

            /// Since it's possible to remove BO on multiple order, we only show the toaster once

            let showToast: Effect<CheckoutAction> = environment
                .showToast(ToastData(type: .normal, message: "Pengiriman disesuaikan karena ada perubahan di promo yang kamu pilih."))
                .fireAndForget()

            effects.append(showToast)
        }

        return .merge(effects)

    default:
        return .none
    }
}

/**
 Reducer specialize to handle action delegation from `AddressNode`
 */
/**
 `CheckoutViewController` reducer that consist of all sub reducer from its components

 We add the chaining method `.calculatePaymentFee()` so we can calculate platform fee without defining all actions that triggers the calculation
 */
internal let checkoutReducer = Reducer<CheckoutState, CheckoutAction, CheckoutEnvironment>.combine(
    addressReducer.pullback(state: \CheckoutState.self, action: /CheckoutAction.self, environment: { $0.addressEnvironment }),
    orderReducer.pullback(state: \CheckoutState.self, action: /CheckoutAction.self, environment: { $0.orderEnvironment }),
    promoReducer.pullback(state: \CheckoutState.self, action: /CheckoutAction.promo, environment: { $0.promoEnvironment }),
    summaryReducer.pullback(state: \CheckoutState.self, action: /CheckoutAction.self, environment: { $0.summaryEnvironment }),
    checkoutDefaultReducer,
    egoldReducer
).calculatePaymentFee()
