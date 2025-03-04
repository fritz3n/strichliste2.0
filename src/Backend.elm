module Backend exposing (Model, Msg(..), View(..), main, update, view)

import Browser
import Common exposing (NewOrder, Order, Product, User, createProduct, createUser, getOrders, getProducts, getReports, getUsers, get_jwt_token, orderSetUndone, productDefaultLocation, updateProduct, updateUser)
import Dict
import File
import File.Select
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Parser


main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


type Msg
    = ShowUsers
    | ShowProducts
    | ShowOrders
    | ShowReports
    | PasswordChanged String
    | PasswordEnter
    | GotJwt (Result Http.Error String)
    | SelectAvatar
    | SelectedAvatar File.File
    | SelectProductImage
    | SelectedProductImage File.File
    | UpdateUser User
    | UpdatedUser (Result Http.Error ())
    | UpdateProduct Product
    | UpdatedProduct (Result Http.Error ())
    | GotUsers (Result Http.Error (List User))
    | GotProducts (Result Http.Error (List Product))
    | CreateNewUser
    | CreateNewProduct
    | NewUserCreated (Result Http.Error ())
    | NewUserNameChange String
    | NewProductCreated (Result Http.Error ())
    | NewProductNameChange String
    | NewProductPriceChange String
    | NewProductAlcoholChange String
    | NewProductVolumeChange String
    | NewProductDescriptionChange String
    | NewProductLocationChange String
    | GotOrders (Result Http.Error (List Order))
    | SetUndone Order Bool
    | UnDoneSet (Result Http.Error ())
    | GotReports (Result Http.Error (Dict.Dict String String))


type View
    = EditUsers
    | EditProducts
    | EditOrders
    | Failure
    | GetPassword
    | Reports


type alias Model =
    { jwtToken : String
    , password : String
    , view : View
    , users : List User
    , products : List Product
    , orders : List Order
    , new_user_name : String
    , new_user_avatar : Maybe File.File
    , new_product_name : String
    , new_product_description : String
    , new_product_price : String
    , new_product_volume : String
    , new_product_location : String
    , new_product_alcohol_content : String
    , new_product_image : Maybe File.File
    , reports : Dict.Dict String String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { jwtToken = ""
      , password = ""
      , view = GetPassword
      , products = []
      , users = []
      , orders = []
      , new_user_name = ""
      , new_user_avatar = Nothing
      , new_product_name = ""
      , new_product_description = ""
      , new_product_price = ""
      , new_product_alcohol_content = ""
      , new_product_volume = ""
      , new_product_image = Nothing
      , new_product_location = productDefaultLocation
      , reports = Dict.empty
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- General
        ShowUsers ->
            ( { model | view = EditUsers }, getUsers model.jwtToken GotUsers )

        ShowProducts ->
            ( { model | view = EditProducts }, getProducts model.jwtToken GotProducts )

        ShowOrders ->
            ( { model | view = EditOrders }, getOrders model.jwtToken GotOrders )

        ShowReports ->
            ( { model | view = Reports }, getReports model.jwtToken GotReports )

        PasswordChanged password ->
            ( { model | password = password }, Cmd.none )

        PasswordEnter ->
            ( model, get_jwt_token Common.XxxxUser model.password GotJwt )

        GotJwt result ->
            case result of
                Err _ ->
                    ( { model | password = "" }, Cmd.none )

                Ok jwt ->
                    { model | password = "", jwtToken = jwt } |> update ShowOrders

        GotUsers result ->
            case result of
                Err _ ->
                    ( { model | view = Failure }, Cmd.none )

                Ok users ->
                    ( { model | users = users }, Cmd.none )

        GotProducts result ->
            case result of
                Err _ ->
                    ( { model | view = Failure }, Cmd.none )

                Ok products ->
                    ( { model | products = products }, Cmd.none )

        -- User View
        UpdateUser user ->
            ( model, updateUser model.jwtToken user UpdatedUser )

        UpdatedUser (Err _) ->
            ( { model | view = Failure }, Cmd.none )

        UpdatedUser (Ok _) ->
            ( model, getUsers model.jwtToken GotUsers )

        NewUserCreated (Err _) ->
            ( { model | view = Failure }, Cmd.none )

        NewUserCreated (Ok _) ->
            ( model, getUsers model.jwtToken GotUsers )

        NewUserNameChange text ->
            ( { model | new_user_name = text }, Cmd.none )

        CreateNewUser ->
            case ( model.new_user_avatar, model.new_user_name ) of
                ( _, "" ) ->
                    ( model, Cmd.none )

                ( Nothing, _ ) ->
                    ( model, Cmd.none )

                ( Just avatar, name ) ->
                    ( { model | new_user_avatar = Nothing, new_user_name = "" }, createUser model.jwtToken model.new_user_name avatar NewUserCreated )

        -- Product View
        UpdateProduct product ->
            ( model, updateProduct model.jwtToken product UpdatedProduct )

        UpdatedProduct (Ok _) ->
            ( model, getProducts model.jwtToken GotProducts )

        UpdatedProduct (Err _) ->
            ( { model | view = Failure }, Cmd.none )

        CreateNewProduct ->
            let
                stripZero string =
                    -- Elm doesn't parse leading 0s in numbers
                    if String.startsWith "0" string && String.length string > 1 then
                        stripZero <| String.dropLeft 1 string

                    else
                        string

                price =
                    Parser.run Parser.float <| String.replace "," "." <| stripZero <| model.new_product_price

                alcohol_content =
                    Parser.run Parser.float <| String.replace "," "." <| stripZero <| model.new_product_alcohol_content

                volume_in_ml =
                    Parser.run Parser.float <| String.replace "," "." <| stripZero <| model.new_product_volume
            in
            case ( price, volume_in_ml, alcohol_content ) of
                ( Ok price_f, Ok volume_in_ml_f, Ok alcohol_content_f ) ->
                    case model.new_product_image of
                        Just image ->
                            ( { model
                                | new_product_name = ""
                                , new_product_description = ""
                                , new_product_price = ""
                                , new_product_volume = ""
                                , new_product_alcohol_content = ""
                                , new_product_location = productDefaultLocation
                              }
                            , createProduct model.jwtToken
                                { name = model.new_product_name
                                , description = model.new_product_description
                                , image = image
                                , price = price_f
                                , volume_in_ml = volume_in_ml_f
                                , alcohol_content = alcohol_content_f
                                , location = model.new_product_location
                                }
                                NewProductCreated
                            )

                        Nothing ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        NewProductCreated (Ok _) ->
            ( model, getProducts model.jwtToken GotProducts )

        NewProductCreated (Err _) ->
            ( { model | view = Failure }, Cmd.none )

        NewProductNameChange text ->
            ( { model | new_product_name = text }, Cmd.none )

        NewProductPriceChange text ->
            ( { model | new_product_price = text }, Cmd.none )

        NewProductAlcoholChange text ->
            ( { model | new_product_alcohol_content = text }, Cmd.none )

        NewProductVolumeChange text ->
            ( { model | new_product_volume = text }, Cmd.none )

        NewProductDescriptionChange text ->
            ( { model | new_product_description = text }, Cmd.none )

        NewProductLocationChange text ->
            ( { model | new_product_location = text }, Cmd.none )

        GotOrders (Err _) ->
            ( { model | view = Failure }, Cmd.none )

        GotOrders (Ok orders) ->
            ( { model | orders = orders }, Cmd.none )

        GotReports (Err _) ->
            ( { model | view = Failure }, Cmd.none )

        GotReports (Ok reports) ->
            ( { model | reports = reports }, Cmd.none )

        SetUndone order unDone ->
            ( model, orderSetUndone model.jwtToken order unDone UnDoneSet )

        UnDoneSet (Ok _) ->
            ( model, getOrders model.jwtToken GotOrders )

        UnDoneSet (Err _) ->
            ( { model | view = Failure }, Cmd.none )

        SelectAvatar ->
            ( model, File.Select.file [ "image/jpeg", "image/png" ] SelectedAvatar )

        SelectedAvatar file ->
            ( { model | new_user_avatar = Just file }, Cmd.none )

        SelectProductImage ->
            ( model, File.Select.file [ "image/jpeg", "image/png" ] SelectedProductImage )

        SelectedProductImage file ->
            ( { model | new_product_image = Just file }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    let
        title =
            case model.view of
                EditUsers ->
                    "Users"

                EditProducts ->
                    "Products"

                EditOrders ->
                    "Orders"

                Failure ->
                    "Failure"

                GetPassword ->
                    "Login"

                Reports ->
                    "Reports"

        navbar =
            if model.view /= GetPassword then
                [ button [ onClick ShowOrders ] [ text "Edit Orders" ]
                , button [ onClick ShowProducts ] [ text "Edit Products" ]
                , button [ onClick ShowUsers ] [ text "Edit Users" ]
                , button [ onClick ShowReports ] [ text "Reports" ]
                ]

            else
                []
    in
    div [ style "margin" "30px" ]
        (navbar
            ++ [ h1 [] [ text title ]
               , case model.view of
                    EditUsers ->
                        viewUsers model

                    EditProducts ->
                        viewProducts model

                    EditOrders ->
                        viewOrders model

                    Reports ->
                        viewReports model

                    Failure ->
                        p [] [ text "Something went wrong. Maybe you have forgotten to fill in the `jwtToken` field in the upper right?\n" ]

                    GetPassword ->
                        div []
                            [ h3 [] [ text "Please enter Password: " ]
                            , input [ type_ "password", value model.password, onInput PasswordChanged ] []
                            , button [ onClick PasswordEnter ] [ text "Enter" ]
                            ]
               ]
        )


viewReports : Model -> Html Msg
viewReports model =
    div []
        (List.map
            (\( name, hash ) ->
                div []
                    [ a [ href ("api/get_report?file=" ++ hash) ] [ text name ]
                    , br [] []
                    ]
            )
            (Dict.toList model.reports |> List.sortBy Tuple.first |> List.reverse)
        )


viewOrders model =
    div []
        [ table []
            ([ tr []
                [ th [] [ text "Time" ], th [] [ text "User" ], th [] [ text "Product" ], th [] [ text "Amount" ], th [] [ text "Location" ], th [] [ text "Undone" ], th [] [] ]
             ]
                ++ List.map orderRow model.orders
            )
        ]


orderRow : Order -> Html Msg
orderRow order =
    tr []
        [ td [] [ text <| String.left 19 <| order.creation_date ]
        , td [] [ text order.user.name ]
        , td [] [ text order.product.name ]
        , td [] [ text <| String.fromInt order.amount ]
        , td [] [ text order.location ]
        , td []
            [ text
                (if order.unDone then
                    "Yes"

                 else
                    "No"
                )
            ]
        , td []
            [ button [ onClick <| SetUndone order <| not order.unDone ]
                [ text
                    (if order.unDone then
                        "Redo"

                     else
                        "Undo"
                    )
                ]
            ]
        ]


viewUsers : Model -> Html Msg
viewUsers model =
    let
        avatar_button =
            case model.new_user_avatar of
                Just avatar ->
                    button [ onClick SelectAvatar ] [ text (File.name avatar) ]

                Nothing ->
                    button [ onClick SelectAvatar ] [ text "select" ]
    in
    div []
        [ table []
            ([ tr []
                [ th [] [ text "Name" ], th [] [ text "Avatar" ], th [] [ text "Active" ], th [] [] ]
             , tr [] []
             , td [] []
             , tr []
                [ td [] [ input [ placeholder "Name", value model.new_user_name, onInput NewUserNameChange ] [] ]
                , td [] [ avatar_button ]
                , td [] [ button [ onClick CreateNewUser ] [ text "Create new" ] ]
                ]

             --             , td [] [ button [ onClick CreateNewUser ] [ text "Create new" ] ]
             ]
                ++ List.map userRow (List.filter (\u -> u.active) model.users)
            )
        ]


userRow : User -> Html Msg
userRow user =
    tr []
        [ td [] [ text user.name ]
        , td [] [ text user.avatar ]
        , td []
            [ text
                (if user.active then
                    "Yes"

                 else
                    "No"
                )
            ]
        , td []
            [ button [ onClick <| UpdateUser { user | active = not user.active } ]
                [ text
                    (if user.active then
                        " Deactivate"

                     else
                        "Activate"
                    )
                ]
            ]
        ]


viewProducts : Model -> Html Msg
viewProducts model =
    let
        products_ordered =
            model.products
                |> List.sortBy .id
                |> List.sortBy .name
                |> List.sortBy .price
                |> List.sortBy
                    (\p ->
                        if p.active then
                            0

                        else
                            1
                    )

        select_button_text =
            case model.new_product_image of
                Nothing ->
                    "Select"

                Just f ->
                    File.name f
    in
    div []
        [ table []
            ([ tr []
                [ th [] [ text "Name" ], th [] [ text "Description" ], th [] [ text "Image" ], th [] [ text "Price" ], th [] [ text "Volume in Milliliters" ], th [] [ text "Alcohol Content" ], th [] [ text "Location" ] ]
             , tr []
                [ td [] [ input [ placeholder "Name", value model.new_product_name, onInput NewProductNameChange ] [] ]
                , td [] [ input [ placeholder "Description", value model.new_product_description, onInput NewProductDescriptionChange ] [] ]
                , td [] [ button [ onClick SelectProductImage ] [ text select_button_text ] ]
                , td [] [ input [ placeholder "Price", value model.new_product_price, onInput NewProductPriceChange ] [] ]
                , td [] [ input [ placeholder "Volume in Milliliters", value model.new_product_volume, onInput NewProductVolumeChange ] [] ]
                , td [] [ input [ placeholder "Alcohol Content", value model.new_product_alcohol_content, onInput NewProductAlcoholChange ] [] ]
                , td [] [ input [ placeholder "Location", value model.new_product_location, onInput NewProductLocationChange ] [] ]
                , td [] [ button [ onClick CreateNewProduct ] [ text "Create new" ] ]
                ]
             ]
                ++ List.map productRow products_ordered
            )
        ]


productRow : Product -> Html Msg
productRow product =
    tr []
        [ td [] [ text product.name ]
        , td [] [ text product.description ]
        , td [] [ text product.image ]
        , td [] [ text <| String.fromFloat <| product.price ]
        , td [] [ text <| String.fromFloat <| product.volume_in_ml ]
        , td [] [ text <| String.fromFloat <| product.alcohol_content ]
        , td [] [ text product.location ]
        , td []
            [ button [ onClick <| UpdateProduct { product | active = not product.active } ]
                [ text
                    (if product.active then
                        " Deactivate"

                     else
                        "Activate"
                    )
                ]
            ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- HTTP
