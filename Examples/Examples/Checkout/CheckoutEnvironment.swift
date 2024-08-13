//
//  CheckoutEnvironment.swift
//  Examples
//
//  Created by jefferson.setiawan on 21/03/24.
//

import RxComposableArchitecture

internal struct CheckoutEnvironment {
    /**
     Side effect to get SAF response.
     */
//    internal var shipmentAddressFormResponse: (ShipmentAddressFormParams) -> Effect<Result<ShipmentAddressFormResponse, NetworkError>>
//
//    /**
//     Side effect to change address when user change or add new address
//     */
//    internal var changeShipmentAddressResponse: (ChangeShipmentAddressParams) -> Effect<Result<ChangeShipmentAddressResponse, NetworkError>>
//
//    /**
//     Side effect hit and forget to save shipment to backend
//     */
//    internal var saveShipment: (SaveShipmentParams) -> Effect<Never>
//
//    /**
//     Response to validating current coupon
//     */
//    internal var validateUseResponse: (CouponListParamData, [String: JSONValue]) -> Effect<Result<ValidateCouponResponseData, NetworkError>>
//
//    /**
//     Response to reset unused free shipment on checkout
//
//     - Parameters:
//        - String -> promo code
//     */
//    internal var resetFreeShipmentOnServer: (_ orderData: ClearCacheOrderParamData) -> Effect<Result<ResetLastApplyCouponResponseData, NetworkError>>
//
//    /**
//     Response fetching rates for shipment
//     - Parameters:
//        - Bool -> is TradeIn dropoff ?
//     */
//    internal var logisticRatesResponse: (_ params: LogisticRatesParams, _ isTradeInDropOff: Bool, _ metadata: RatesMetadata) -> Effect<Result<LogisticRatesResponse, NetworkError>>
//
//    /**
//     Response fetching rates for shipment, but only mvc field,
//     this will be used to check current shipment mvc status
//
//     - Parameters:
//        - Bool -> is TradeIn dropoff ?
//     */
//    internal var logisticRatesMVCOnlyResponse: (_ params: LogisticRatesParams, _ isTradeInDropOff: Bool) -> Effect<Result<LogisticRatesMVCOnlyResponse, NetworkError>>
//
//    /**
//      Side effect to fetch transaction cart to continue to payment
//     */
//    internal var checkoutResponse: (RequestCheckoutParams) -> Effect<Result<RequestCheckoutResponse, NetworkError>>
//
//    /**
//      Side effect to update dynamic data to BE
//     */
//    internal var updateDynamicDataResponse: (UpdateDynamicDataParams) -> Effect<Result<UpdateDynamicDataResponse, TPError<UpdateDynamicDataError>>>
//
//    /**
//     Response releasing stock booking on OCS mode
//     */
//    internal var releaseStockBookingResponse: ([ShipmentProductID]) -> Effect<Never>
//
//    /**
//     Show insurance bottom sheet
//     */
//    internal var showInsuranceDetailBottomSheet: (String) -> Effect<Never>
//
//    /**
//     Side effect send analytics
//     */
//    internal var sendAnalytics: (AnalyticsEvent) -> Effect<Never>
//
//    /**
//     Side effect to show Toast
//     */
//    internal var showToast: (ToastData) -> Effect<Never>
//
//    /**
//     Side effect to refresh cart page
//     */
//    internal var refreshCart: () -> Effect<Never>
//
//    /** x
//     Return LocalizedAddress from the services
//     */
//    internal var getChosenAddressData: () -> LocalizedAddress?
//
//    /** x
//     Return local User ID
//     */
//    internal var getLocalUserId: () -> String
//
//    /** x
//     Open Offer Bottom Sheet
//     */
//    internal var openOfferBottomSheet: (Offer, [ProductState]) -> Effect<Never>
//
//    /** x
//     Routing with our Atlas
//     */
//    internal var routeWithUrl: (String) -> Effect<Never>
//
//    /**
//     Side effect fetch value from user default
//     */
//    internal var didShowedOnboarding: () -> Bool
//
//    /**
//     Side effect to set onboarding to true
//     */
//    internal var setOnboardingToTrue: () -> Effect<Never>
//
//    /**
//     Open epharmacy upload prescription page
//     */
//    internal var openUploadPrescriptionPage: (PrescriptionCheckoutID, EpharmacyPageSource) -> Effect<[PrescriptionID]>
//
//    /**
//     Check epharmacy uploaded prescription cache
//     */
//    internal var checkUploadedPrescriptionID: (PrescriptionCheckoutID, EpharmacyPageSource) -> Effect<Result<EpharmacyCheckoutDetailData, NetworkError>>
//
//    /**
//     Open epharmacy prescription attachment page
//     */
//    internal var openPrescriptionAttachmentPage: () -> Effect<[CheckoutPrescriptionData]>
//
//    /**
//     Check epharmacy uploaded consultation cache
//     */
//    internal var checkUploadedConsultationData: () -> Effect<Result<CheckoutEpharmacyPPGData, NetworkError>>
//
//    /**
//     Platform fee per basket size on Checkout
//     */
//    internal var paymentFeeResponse: (CheckoutPaymentFeeParameter) -> Effect<Result<CheckoutPaymentFeeResponse, TPError<CheckoutPaymentFeeError>>>
//
//    /**
//     Main scheduler
//     */
//    internal var mainScheduler: () -> SchedulerType
//
//    /**
//     Save add-ons for `add-ons as a service`
//
//     We reuse value from add-on bottom sheet's environment
//     */
//    internal var saveAddOns: (SaveAddOnRequestParams) -> Effect<Result<SaveAddonResponse, TPError<AddonBottomSheetErrorState>>>
//
//    /**
//     Return the google analytics client id
//     */
    internal var googleAnalyticsClientId: () -> String
}
