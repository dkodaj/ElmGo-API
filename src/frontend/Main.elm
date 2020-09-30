module Main exposing (main)

import Browser
import Browser.Dom
import Browser.Events
import Html exposing (div, Html, text)
import Html.Attributes as Attr exposing (class)
import Html.Events as Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode exposing (Decoder)
import Task


main =
    Browser.document
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


type alias Model =
    { input : String
    , serverMsg : ServerMsg
    }


type Msg =
      Fetch
    | Incoming (Result Http.Error ServerMsg)
    | Input String
    | KeyDown String
    | NoOp


type ServerMsg =
      Data ApiData
    | HttpError String
    | Idle
    | RequestError String    


type alias ApiData =
    { id : Int
    , garble : String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { input = ""
      , serverMsg = Idle
      }
    , focus inputBoxId
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Browser.Events.onKeyDown decodeKey


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Fetch ->
            ( { model |
                  input = "" 
              }
            , Cmd.batch
                [ post model.input 
                , focus inputBoxId
                ]
            )


        Incoming (Ok x) ->
            ( { model | serverMsg = x }
            , Cmd.none 
            )


        Incoming (Err x) ->
            ( { model | serverMsg = HttpError (Debug.toString x) }
            , Cmd.none 
            )


        Input x ->
            ( { model | input = x }
            , Cmd.none 
            )


        KeyDown key ->            
            if key == "Enter" then
                update Fetch model
            else
                ( model, Cmd.none )


        NoOp ->
            ( model, Cmd.none )


view : Model -> Browser.Document Msg
view model =
    { title = "ElmGo API"
    , body = body model
    }


-- UX helper

focus : String -> Cmd Msg
focus id =
    Task.attempt (\_ -> NoOp) (Browser.Dom.focus id)


inputBoxId : String
inputBoxId =
    "InputBox"


-- GUI

body : Model -> List (Html Msg)
body model =
    [ div
        [ class "Container" ]
        ( inputBox model.input :: output model.serverMsg )
    ]


inputBox : String -> Html Msg
inputBox txt =
    div
        [ class "field has-addons" ]
        [ div
            [ class "control" ]
            [ Html.input
                [ class "input is-rounded" 
                , Attr.type_ "text"
                , Attr.placeholder "Enter ID"
                , Attr.id inputBoxId
                , Attr.value txt
                , onInput Input
                ] []
            ]

        , div
            [ class "control" ]
            [ Html.a
                [ class "button is-primary is-rounded" 
                , onClick Fetch
                ]
                [ text "Fetch" ]
            ]
        ]


output : ServerMsg -> List (Html Msg)
output msg =
    case msg of
        Data apiData ->
            [ div
                [ class "table" ]
                [ Html.thead
                    []
                    [ Html.tr
                        []
                        [ Html.th
                            []
                            [ text "Id" ]

                        , Html.th
                            []
                            [ text "Garble" ]
                        ]
                    ]

                , Html.tbody
                    []
                    [ Html.tr
                        []
                        [ Html.td
                            []
                            [ text (String.fromInt apiData.id) ]

                        , Html.td
                            []
                            [ text apiData.garble ]
                        ]
                    ]
                ]
            ]


        HttpError txt ->
            [ div
                [ class "has-text-danger has-text-weight-bold" 
                , Attr.style "margin" "0 30px 0 10px"
                ]
                [ text "HTTP error: " ]

            , div [] [text txt]
            ]


        Idle ->
            []


        RequestError txt ->
            [ div
                [ class "has-text-danger has-text-weight-bold" 
                , Attr.style "margin" "0 30px 0 10px"
                ]
                [ text "Server complains: " ]

            , div [] [text txt]
            ]


-- HTTP

post : String -> Cmd Msg
post input =
    let
        param =
            "id=" ++ input
    in
    Http.post
        { url = "/api"
        , body = Http.stringBody "application/x-www-form-urlencoded" param
        , expect = Http.expectJson Incoming decodeServerMsg
        }


-- DESERIALIZE

decodeApiData : Decoder ServerMsg
decodeApiData =
    Decode.map Data
    <| Decode.map2 ApiData
        (Decode.field "id" Decode.int)
        (Decode.field "garble" Decode.string)


decodeRequestError : Decoder ServerMsg
decodeRequestError =
    Decode.map RequestError (Decode.field "error" Decode.string)


decodeKey : Decoder Msg
decodeKey =
    Decode.map KeyDown (Decode.field "key" Decode.string)


decodeServerMsg  : Decoder ServerMsg
decodeServerMsg =
    Decode.oneOf
        [ decodeApiData
        , decodeRequestError
        ]