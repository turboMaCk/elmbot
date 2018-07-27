module Types exposing (..)


type alias ConfigFile =
    -- shape of the config file
    { apiToken : String
    , channel : SlackChannel
    }


type alias Model =
    { channel : SlackChannel
    , running : Bool
    , outMsgQueue : List SlackOutMessage
    }


type Msg
    = Running Bool
    | ReceiveMessage SlackMessage
    | SendOneMessage
    | GetSnippetResult SnippetResult
    | NoOp


type alias SlackMessage =
    { channel : String
    , text : String
    }


type alias SlackOutMessage =
    ( SlackText, SlackChannel )


type alias SlackText =
    String


type alias SlackChannel =
    String


type alias Snippet =
    { packages : List String
    , imports : List String
    , expressions : List String
    , channel : String
    }


type alias SnippetResult =
    { channel : String
    , type_ : SnippetResultType
    }


type SnippetResultType
    = ErrorInstallingPackage String
    | ErrorRunningCode String
    | ErrorNoExpressions
    | OtherError String
    | Result String
