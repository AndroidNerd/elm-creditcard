module CreditCard
    exposing
        ( card
        , form
        , number
        , name
        , month
        , year
        , ccv
        , State
        , initialState
        , CardData
        , emptyCardData
        )

{-|
# View
@docs card, form, number, name, month, year, ccv

# Data
@docs CardData, emptyCardData

# Internal State
@docs State, initialState
-}

import CreditCard.Components.Card
import CreditCard.Config exposing (Config, FormConfig, Form)
import CreditCard.Internal
import CreditCard.Events exposing (onCCVFocus, onCCVBlur)
import Helpers.CardType
import Helpers.Misc
import Html exposing (Html, div, label, p, text, input)
import Html.Attributes exposing (class, type_, value, placeholder)
import Html.Events exposing (onInput)
import Input.BigNumber
import Input.Number
import String


{-| Internal State of the card view
-}
type alias State =
    CreditCard.Internal.State


{-| Initial state of the card view
-}
initialState : State
initialState =
    CreditCard.Internal.initialState


{-| Empty card data
-}
emptyCardData : CardData {}
emptyCardData =
    { number = Nothing
    , name = Nothing
    , month = Nothing
    , year = Nothing
    , ccv = Nothing
    , state = initialState
    }



-- VIEW


{-| Stores the card data such as number, name, etc.

This `CardData` can be embeded into your application's Model in various ways.
Here's 2 example of embedding this data into your model:
Example 1:

    -- Use CardData in your model directly
    type alias Model =
        { cardData : CreditCard.CardData {}
        ...
        }

    -- Initial the model
    init =
        { cardData = CardData.emptyCardData
        ...
        }

Example 2:

    -- Extends the CardData in your Model
    type alias Model =
        { number : Maybe String
        , name : Maybe String
        , month : Maybe String
        , year : Maybe String
        , ccv : Maybe String
        , state : CreditCard.State
        , shippingAddress : Maybe String
        ...
        }

    -- Initial the model
    init =
        let
            emptyCardData =
                CardData.emptyCardData
        in
            { emptyCardData |
            shippingAddress = Nothing
            ...
            }
-}
type alias CardData model =
    { model
        | number : Maybe String
        , name : Maybe String
        , month : Maybe String
        , year : Maybe String
        , ccv : Maybe String
        , state : State
    }


{-| Card view

Render the card view individually.
Example:

    view model =
        let
            config =
                CreditCard.Config.defaultConfig
        in
            CreditCard.card config model
-}
card : Config config -> CardData model -> Html msg
card config cardData =
    let
        cardInfo =
            Helpers.CardType.detect cardData
    in
        CreditCard.Components.Card.card config cardInfo cardData


{-| Form view

Render the card view with the full form fields.
Example:

    type Msg = UpdateCardData Model

    view model =
        let
            config =
                CreditCard.Config.defaultFormConfig UpdateCardData
        in
            CreditCard.card config model

-}
form : FormConfig model msg -> CardData model -> Html msg
form config cardData =
    div []
        [ card config cardData
        , number config cardData
        , name config cardData
        , month config cardData
        , year config cardData
        , ccv config cardData
        ]


{-| CCV form field

Render the CCV field individually.
Example:

    type Msg = UpdateCardData Model

    view model =
        let
            config =
                CreditCard.Config.defaultFormConfig UpdateCardData
        in
            form []
                [ CreditCard.card config model
                , CreditCard.ccv config model
                ...

-}
ccv : FormConfig model msg -> CardData model -> Html msg
ccv config cardData =
    let
        ccvConfig =
            let
                default =
                    Input.BigNumber.defaultOptions <| updateCCV config cardData
            in
                { default | maxLength = Just 4, hasFocus = Just focusHandler }

        focusHandler hasFocus =
            let
                updatedCardData =
                    CreditCard.Events.updateCCVFocus hasFocus cardData
            in
                config.onChange updatedCardData
    in
        field .ccv config <| Input.BigNumber.input ccvConfig [ placeholder config.placeholders.ccv ] <| Maybe.withDefault "" cardData.ccv


{-| Year form field

Render the year field individually.
Example:

    type Msg = UpdateCardData Model

    view model =
        let
            config =
                CreditCard.Config.defaultFormConfig UpdateCardData
        in
            form []
                [ CreditCard.card config model
                , CreditCard.year config model
                ...

-}
year : FormConfig model msg -> CardData model -> Html msg
year config cardData =
    let
        yearConfig =
            let
                default =
                    Input.Number.defaultOptions <| updateYear config cardData
            in
                { default | minValue = Just 1, maxValue = Just 9999 }
    in
        field .year config <| Input.Number.input yearConfig [ placeholder config.placeholders.year ] (cardData.year |> Maybe.andThen (String.toInt >> Result.toMaybe))


{-| Month form field

Render the month field individually.
Example:

    type Msg = UpdateCardData Model

    view model =
        let
            config =
                CreditCard.Config.defaultFormConfig UpdateCardData
        in
            form []
                [ CreditCard.card config model
                , CreditCard.month config model
                ...

-}
month : FormConfig model msg -> CardData model -> Html msg
month config cardData =
    let
        monthConfig =
            let
                default =
                    Input.Number.defaultStringOptions <| updateMonth config cardData
            in
                { default | maxLength = Just 2, maxValue = Just 12, minValue = Just 1 }
    in
        field .month config <| Input.Number.inputString monthConfig [ placeholder config.placeholders.month ] <| Maybe.withDefault "" cardData.month


{-| Name form field

Render the name field individually.
Example:

    type Msg = UpdateCardData Model

    view model =
        let
            config =
                CreditCard.Config.defaultFormConfig UpdateCardData
        in
            form []
                [ CreditCard.card config model
                , CreditCard.name config model
                ...

-}
name : FormConfig model msg -> CardData model -> Html msg
name config cardData =
    field .name config <| input [ type_ "text", value <| Maybe.withDefault "" cardData.name, onInput <| updateName config cardData, placeholder config.placeholders.name ] []


{-| Number form field

Render the number field individually.
Example:

    type Msg = UpdateCardData Model

    view model =
        let
            config =
                CreditCard.Config.defaultFormConfig UpdateCardData
        in
            form []
                [ CreditCard.card config model
                , CreditCard.number config model
                ...

-}
number : FormConfig model msg -> CardData model -> Html msg
number config cardData =
    let
        cardInfo =
            Helpers.CardType.detect cardData

        ( _, maxLength ) =
            Helpers.Misc.minMaxNumberLength cardInfo

        numberConfig =
            let
                default =
                    Input.BigNumber.defaultOptions <| updateNumber config cardData
            in
                { default | maxLength = Just maxLength }
    in
        field .number config <| Input.BigNumber.input numberConfig [ placeholder config.placeholders.number ] (Maybe.withDefault "" cardData.number)



-- HELPERS


field : (Form -> String) -> FormConfig model msg -> Html msg -> Html msg
field getter config inputElement =
    p [ class <| getter config.classes ]
        [ if config.showLabel then
            label [] [ text <| getter config.labels, inputElement ]
          else
            inputElement
        ]


updateCCV : Config (FormConfig model msg) -> CardData model -> (String -> msg)
updateCCV config cardData =
    let
        updatedCardData ccv =
            { cardData | ccv = Just ccv }
    in
        (\ccv -> config.onChange (updatedCardData ccv))


updateYear : Config (FormConfig model msg) -> CardData model -> (Maybe Int -> msg)
updateYear config cardData =
    let
        updatedCardData maybeInt =
            { cardData | year = Maybe.map toString maybeInt }
    in
        (\maybeInt -> config.onChange (updatedCardData maybeInt))


updateMonth : Config (FormConfig model msg) -> CardData model -> (String -> msg)
updateMonth config cardData =
    let
        updatedCardData month =
            { cardData | month = Just month }
    in
        (\month -> config.onChange (updatedCardData month))


updateNumber : Config (FormConfig model msg) -> CardData model -> (String -> msg)
updateNumber config cardData =
    let
        updatedCardData number =
            { cardData | number = Just number }
    in
        (\number -> config.onChange (updatedCardData number))


updateName : Config (FormConfig model msg) -> CardData model -> (String -> msg)
updateName config cardData =
    let
        updatedCardData name =
            { cardData | name = Just name }
    in
        (\name -> config.onChange (updatedCardData name))
