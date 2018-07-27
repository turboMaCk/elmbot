module Types exposing (..)


type alias Model =
    { running : Bool
    , outMsgQueue : List SlackMessage
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
