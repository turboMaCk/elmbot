port module Ports exposing (..)

import Json.Decode as JD exposing (Decoder)
import Types exposing (..)


-- slack


port start : () -> Cmd msg


port sendMessage : SlackMessage -> Cmd msg


port incomingMessageRaw : (JD.Value -> msg) -> Sub msg


incomingMessage : (SlackMessage -> Msg) -> Sub Msg
incomingMessage msgTagger =
    incomingMessageRaw
        (\value ->
            JD.decodeValue slackMessageDecoder value
                |> Result.map msgTagger
                |> Result.mapError (Debug.log "Error decoding incoming Slack message")
                |> Result.withDefault NoOp
        )


slackMessageDecoder : JD.Decoder SlackMessage
slackMessageDecoder =
    JD.map2 SlackMessage
        (JD.field "channel" JD.string)
        (JD.field "text" JD.string)


port isRunning : (Bool -> msg) -> Sub msg



-- elmbot


port eval : Snippet -> Cmd msg


port getResultRaw : (JD.Value -> msg) -> Sub msg


getResult : (SnippetResult -> Msg) -> Sub Msg
getResult msgTagger =
    getResultRaw
        (\value ->
            JD.decodeValue snippetResultDecoder value
                |> Result.map msgTagger
                |> Result.mapError (Debug.log "Error decoding Elm snippet result")
                |> Result.withDefault NoOp
        )


snippetResultDecoder : Decoder SnippetResult
snippetResultDecoder =
    JD.map2 SnippetResult
        (JD.field "channel" JD.string)
        snippetResultTypeDecoder


snippetResultTypeDecoder : Decoder SnippetResultType
snippetResultTypeDecoder =
    JD.field "type" JD.string
        |> JD.andThen
            (\type_ ->
                case type_ of
                    "error_installing_package" ->
                        JD.field "error" JD.string
                            |> JD.map ErrorInstallingPackage

                    "error_running_code" ->
                        JD.field "error" JD.string
                            |> JD.map ErrorRunningCode

                    "error_no_expressions" ->
                        JD.succeed ErrorNoExpressions

                    "other_error" ->
                        JD.field "error" JD.string
                            |> JD.map OtherError

                    "result" ->
                        JD.field "result" JD.string
                            |> JD.map Result

                    _ ->
                        JD.fail "Unknown type"
            )
