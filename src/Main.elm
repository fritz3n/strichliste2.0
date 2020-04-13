port module Main exposing (Model(..), Msg(..), User, getUsers, init, main, subscriptions, update, userDecoder, userView, view)

import Browser
import Debug
import Design
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode exposing (Decoder, field, int, list, string, value)
import Time



-- Main


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- Model


type alias State =
    { users : List User
    , products : List Product
    , offline : Bool
    , persistance : Persistance
    }


type alias BuyState =
    { user : User
    , orders : List Order
    }


type alias User =
    { id : Int
    , name : String
    , avatar : String
    }


type alias Product =
    { id : Int
    , name : String
    , description : String
    , image : String
    }


type Model
    = Failure Persistance
    | AskForJwt Persistance
    | LoadingUsers Persistance
    | LoadingProducts Persistance (List User)
    | Loaded State
    | ProductView State BuyState


type alias Order =
    { product : Product
    , amount : Int
    }


type alias Persistance =
    -- Everything we want to be in LocalStorage
    { jwtToken : String
    , orders : List Order
    }


init : Persistance -> ( Model, Cmd Msg )
init persistance =
    if persistance.jwtToken == "" then
        ( AskForJwt persistance, Cmd.none )

    else
        ( LoadingUsers persistance, getUsers )



-- Update


type Msg
    = GotUsers (Result Http.Error (List User))
    | GotProducts (Result Http.Error (List Product))
    | ClickedUser State User
    | ClickedProduct State BuyState Order
    | GetUsers Persistance
    | ResetAmounts State BuyState
    | CommitOrder State BuyState
    | Tick Time.Posix
    | AskForJwtTextUpdate String
    | SetPersistance Persistance


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotUsers result ->
            case result of
                Ok users ->
                    case model of
                        LoadingUsers persistance ->
                            ( LoadingProducts persistance users, getProducts )

                        Loaded state ->
                            ( Loaded { state | offline = False, users = users }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Err _ ->
                    case model of
                        LoadingUsers persistance ->
                            ( Failure persistance, Cmd.none )

                        Loaded state ->
                            ( Loaded { state | offline = True }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

        GotProducts result ->
            case result of
                Err _ ->
                    case model of
                        Loaded state ->
                            ( Loaded { state | offline = True }, Cmd.none )

                        LoadingProducts persistance _ ->
                            ( Failure persistance, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Ok products ->
                    case model of
                        LoadingProducts persistance users ->
                            ( Loaded
                                { users = users
                                , products = products
                                , persistance = persistance
                                , offline = False
                                }
                            , Cmd.none
                            )

                        Loaded state ->
                            ( Loaded { state | offline = False }, Cmd.none )

                        ProductView state buyState ->
                            if areOrdersEmpty buyState.orders then
                                ( ProductView state
                                    { buyState | orders = List.map product2order products }
                                , Cmd.none
                                )

                            else
                                ( model, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

        GetUsers persistance ->
            ( LoadingUsers persistance, getUsers )

        ClickedUser state user ->
            case model of
                Loaded _ ->
                    ( ProductView state { user = user, orders = List.map product2order state.products }, Cmd.none )

                _ ->
                    ( Failure state.persistance, Cmd.none )

        ClickedProduct state buyState order ->
            let
                newOrders =
                    List.map
                        (\o ->
                            if o.product.id == order.product.id then
                                { o | amount = o.amount + 1 }

                            else
                                o
                        )
                        buyState.orders
            in
            ( ProductView state { buyState | orders = newOrders }, Cmd.none )

        ResetAmounts state buyState ->
            ( ProductView state { buyState | orders = List.map resetAmount buyState.orders }, Cmd.none )

        CommitOrder state buyState ->
            -- TODO: Send Order to Backend
            ( Loaded state, Cmd.none )

        Tick timestamp ->
            ( model, Cmd.batch [ getUsers, getProducts ] )

        AskForJwtTextUpdate text ->
            case model of
                AskForJwt persistance ->
                    ( AskForJwt { persistance | jwtToken = text }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetPersistance persistance ->
            ( LoadingUsers persistance, Cmd.batch [ setPersistance persistance, getUsers ] )



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Time.every 1000 Tick



-- View


view : Model -> Html Msg
view model =
    case model of
        AskForJwt persistance ->
            div []
                [ h2 [] [ text "Please Enter JWT. If you set up using init.py you will find some in secrets.json" ]
                , input [ onInput AskForJwtTextUpdate ] []
                , button [ onClick (SetPersistance persistance) ]
                    [ text "Save" ]
                ]

        Loaded state ->
            let
                title =
                    if state.offline then
                        "Strichliste *"

                    else
                        "Strichliste"
            in
            div [ style "margin" "10px 10px 10px 10px " ]
                [ h1 [] [ text title ]
                , Design.grid (List.map (userView state) state.users)
                ]

        Failure persistance ->
            div []
                [ h2 [] [ text "Something went wrong" ]
                , button [ onClick (GetUsers persistance) ] [ text "Try Again" ]
                ]

        LoadingUsers persistance ->
            div []
                [ h2 [] [ text "Loading Users" ] ]

        LoadingProducts persistance users ->
            div []
                [ h2 [] [ text "Loading Products" ] ]

        ProductView state buyState ->
            let
                confirmText =
                    if areOrdersEmpty buyState.orders then
                        "Zurück"

                    else
                        "Bestätigen"

                resetVisible =
                    if areOrdersEmpty buyState.orders then
                        "hidden"

                    else
                        "visible"
            in
            div []
                [ div
                    [ style "flex-direction" "row"
                    , style "display" "flex"
                    , style "align-items" "center"
                    , style "margin" "10px 10px 10px 10px "
                    ]
                    [ img
                        [ src buyState.user.avatar
                        , style "border-radius" "50%"
                        , style "width" "50px"
                        , style "height" "50px"
                        ]
                        []
                    , div [ style "width" "20px" ] []
                    , h1 [] [ text buyState.user.name ]
                    ]
                , Design.grid
                    (List.map (productView state buyState) buyState.orders
                        ++ [ button [ onClick (CommitOrder state buyState) ] [ text confirmText ] ]
                        ++ [ button [ onClick (ResetAmounts state buyState), style "visibility" resetVisible ] [ text "Zurücksetzen" ] ]
                    )
                ]


areOrdersEmpty : List Order -> Bool
areOrdersEmpty orders =
    List.sum (List.map (\o -> o.amount) orders) == 0


userView : State -> User -> Html Msg
userView state user =
    div
        [ onClick (ClickedUser state user)
        , style "margin" "10px"
        , style "text-align" "center"
        ]
        [ img
            [ style "border-radius" "50%"
            , style "width" "60px"
            , style "height" "60px"
            , style "align" "center"
            , src user.avatar
            ]
            []
        , p
            [ style "align" "center"
            ]
            [ text user.name ]
        , br [] []
        ]


productView : State -> BuyState -> Order -> Html Msg
productView state buyState order =
    let
        productText =
            if order.amount == 0 then
                order.product.name

            else
                order.product.name ++ " x" ++ String.fromInt order.amount
    in
    div
        [ onClick (ClickedProduct state buyState order)
        , style "margin" "10px"
        , style "text-align" "center"
        ]
        [ img
            [ src order.product.image
            , style "height" "200px"
            ]
            []
        , h4 [] [ text productText ]
        , p [] [ text order.product.description ]
        ]



-- HTTP


getUsers : Cmd Msg
getUsers =
    Http.get
        { url = "http://localhost:3000/users?active=eq.true&order=name.asc"
        , expect = Http.expectJson GotUsers (Json.Decode.list userDecoder)
        }


getProducts : Cmd Msg
getProducts =
    Http.get
        { url = "http://localhost:3000/products?order=price.asc"
        , expect = Http.expectJson GotProducts (Json.Decode.list productDecoder)
        }


userDecoder : Decoder User
userDecoder =
    Json.Decode.map3 User
        (field "id" int)
        (field "name" string)
        (field "avatar" string)


productDecoder : Decoder Product
productDecoder =
    Json.Decode.map4 Product
        (field "id" int)
        (field "name" string)
        (field "description" string)
        (field "image" string)


product2order product =
    Order product 0


resetAmount : Order -> Order
resetAmount order =
    { order | amount = 0 }


port setPersistance : Persistance -> Cmd msg
