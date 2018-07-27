port module Main exposing (..)

import List.Extra
import Ports exposing (..)
import Time exposing (millisecond)
import Types exposing (..)


main : Program Never Model Msg
main =
    Platform.program
        { init = init
        , update = update
        , subscriptions = subscriptions
        }


init : ( Model, Cmd Msg )
init =
    ( initModel
    , initCmd
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Running isRunning ->
            running isRunning model
                |> logValue "Running" isRunning

        ReceiveMessage message ->
            receiveMessage message model

        SendOneMessage ->
            sendOneMessage model
                |> logValue "SendOneMessage" (List.head model.outMsgQueue)

        GetSnippetResult { type_, channel } ->
            ( model
                |> sendMsg
                    { channel = channel
                    , text = snippetResultToString type_
                    }
            , Cmd.none
            )
                |> logValue "GetSnippetResult" type_

        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ isRunning Running
        , incomingMessage ReceiveMessage
        , sendMsgIfQueueNotEmpty model
        , getResult GetSnippetResult
        ]



----------------------
-- subscriptions -----
----------------------


sendMsgIfQueueNotEmpty : Model -> Sub Msg
sendMsgIfQueueNotEmpty model =
    if List.isEmpty model.outMsgQueue || not model.running then
        Sub.none
    else
        Time.every (500 * millisecond) (\_ -> SendOneMessage)



----------------------
-- update cases
----------------------


running : Bool -> Model -> ( Model, Cmd Msg )
running isRunning model =
    ( { model | running = isRunning }
    , Cmd.none
    )


receiveMessage : SlackMessage -> Model -> ( Model, Cmd Msg )
receiveMessage message model =
    if String.startsWith "elmbot" message.text then
        respondToElmbotMsg message model
    else
        ( model, Cmd.none )


parseSnippet : String -> List String -> Snippet
parseSnippet channel lines =
    { packages = parsePackages lines
    , imports = parseImports lines
    , expressions = parseExpressions lines
    , channel = channel
    }


isInstallLine : String -> Bool
isInstallLine string =
    String.startsWith "--- install " string


isImportLine : String -> Bool
isImportLine string =
    String.startsWith "import " string


parseExpressions : List String -> List String
parseExpressions lines =
    lines
        |> List.filter (\string -> not (isInstallLine string || isImportLine string))
        |> String.join "\n"
        |> String.split "\n\n"
        |> List.map String.trim
        |> List.filter (not << String.isEmpty)


parseImports : List String -> List String
parseImports lines =
    lines
        |> List.filter isImportLine
        |> List.map (String.trim >> String.dropLeft 7 >> String.trim)


parsePackages : List String -> List String
parsePackages lines =
    lines
        |> List.filter isInstallLine
        |> List.map (String.dropLeft 11 >> String.trim)


codeDelimiter : String
codeDelimiter =
    "```"


findCode : String -> Maybe (List String)
findCode string =
    let
        insideCode : List String
        insideCode =
            string
                |> stringReplace codeDelimiter ("\n" ++ codeDelimiter ++ "\n")
                |> String.lines
                |> List.Extra.dropWhile (\string -> string /= codeDelimiter)
                |> List.drop 1
                |> List.Extra.takeWhile (\string -> string /= codeDelimiter)
    in
        if List.isEmpty insideCode then
            Nothing
        else
            Just insideCode


respondToElmbotMsg : SlackMessage -> Model -> ( Model, Cmd Msg )
respondToElmbotMsg message model =
    ( model
    , message.text
        |> findCode
        |> Maybe.map (parseSnippet message.channel)
        |> Maybe.map eval
        |> Maybe.withDefault Cmd.none
    )


sendOneMessage : Model -> ( Model, Cmd Msg )
sendOneMessage model =
    if model.running then
        case List.head model.outMsgQueue of
            Nothing ->
                ( model, Cmd.none )

            Just msg ->
                ( { model | outMsgQueue = List.drop 1 model.outMsgQueue }
                , sendMessage msg
                )
    else
        ( model, Cmd.none )


snippetResultToString : SnippetResultType -> String
snippetResultToString type_ =
    case type_ of
        ErrorInstallingPackage package ->
            "There was an error installing package `" ++ package ++ "` :slightly_frowning_face:"

        ErrorRunningCode error ->
            "There was an error running the code :slightly_frowning_face:\n```" ++ error ++ "```"

        ErrorNoExpressions ->
            "There were no expressions to run!"

        OtherError error ->
            "There was an error: " ++ error

        Result result ->
            "```\n" ++ result ++ "\n```"



----------------------
-- init
----------------------


initModel : Model
initModel =
    { running = False
    , outMsgQueue = []
    }


initCmd : Cmd Msg
initCmd =
    start ()



----------------------
-- helpers
----------------------


sendMsg : SlackMessage -> Model -> Model
sendMsg msg model =
    { model | outMsgQueue = model.outMsgQueue ++ [ msg ] }


logValue : String -> a -> b -> b
logValue msg value a =
    let
        _ =
            Debug.log
                ("Main" ++ "." ++ msg)
                value
    in
        a


stringReplace : String -> String -> String -> String
stringReplace before after string =
    string
        |> String.split before
        |> String.join after
