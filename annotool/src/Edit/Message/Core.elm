module Edit.Message.Core exposing
    ( Msg (..)
    , NodeAttr (..)
    , msgDecoder
    )


import Mouse exposing (Position)
import Window as Window

import Json.Decode as Decode
import Json.Encode as Encode

import Edit.Core as C
import Edit.Anno.Core as Anno
import Server.Core as Server
import Edit.Popup as Popup


type Msg
  = DragStart C.Focus Position
    -- ^ Neither `DragAt` nor `DragEnd` have their focus. This is on purpose.
    -- Focus should be determined, in their case, on the basis of the drag in
    -- the underlying model. We do not support concurrent drags at the moment.
  | DragAt Position
  | DragEnd Position
  | Select C.Focus C.NodeId
  | SelectTree C.Focus C.PartId
    -- ^ Select tree (or join if with CTRL);
  | SelectToken C.Focus C.PartId Int
    -- ^ Select token; the last argument represents the token ID.
  | FocusLink C.Link
  | SelectLink C.Link
  | Focus C.Focus
  | Resize Window.Size -- ^ The height and width of the entire window
  | Increase Bool Bool -- ^ Change the proportions of the window
  | Previous
  | Next
  | ChangeLabel C.NodeId C.Focus String
  | EditLabel
  | Delete -- ^ Delete the selected nodes in the focused window
  | DeleteTree
    -- ^ Delete the selected nodes in the focused window
    -- together with the corresponding subtrees
  | Add -- ^ Delete the selected nodes in the focused window
  -- | ChangeType -- ^ Change the type of the selected node
  | MkEntity String -- ^ Create entity of the given name
--   | MkSignal -- ^ Create signal
--   | MkEvent -- ^ Create event
--   | MkTimex -- ^ Create event
  | ParseRaw Bool  -- ^ Reparse from scratch the sentence in focus; the argument determines
                   -- wheter pre-processing should be used or not
  | ParseSent Server.ParserTyp  -- ^ Reparse the sentence in focus
--   | ParseSentPos Server.ParserTyp -- ^ Reparse the sentence in focus, preserve POList (String, String)S tags
  | ParseSentPos Server.ParserTyp -- ^ Reparse the selected sub-sentence(s) in focus, preserve the POS tags
  | ParseSentCons Server.ParserTyp  -- ^ Reparse the sentence in focus with the selected nodes as constraints
  | ApplyRules -- ^ Apply the (flattening) rules
  | CtrlDown
  | CtrlUp
  -- | Connect
  | MkRelation String -- ^ Create relation of the given name
  | Attach
  | Swap Bool
  | Files -- ^ Go back to files menu
  | SaveFile  -- ^ Save the current file
  | SplitTree  -- ^ Split the tree
  | Join  -- ^ Merge the two trees in view
  | ConcatWords  -- ^ Merge two (or more) words
  -- | Break -- ^ Break the given partition into its components
  | Undo
  | Redo
  | SideMenuEdit C.Focus
  | SideMenuContext C.Focus
  | ShowContext
  | SideMenuLog C.Focus
  -- * Modifying general node's attributes
  | SetNodeAttr C.NodeId C.Focus NodeAttr
  -- * Entity modification event
  | SetEntityType
    C.NodeId
    C.Focus
    String            -- ^ New type value
  | SetEntityAttr
    C.NodeId
    C.Focus
    String            -- ^ Attribute name
    (Maybe Anno.Attr) -- ^ Attribute value
  | SetEntityAnchor
    C.NodeId
    C.Focus
    String            -- ^ Anchor name

  -- * Relation modification event
  | SetRelationType
    C.Link
    String            -- ^ New type value
  | SetRelationAttr
    C.Link
    String            -- ^ Attribute name
    (Maybe Anno.Attr) -- ^ Attribute value
  | SetRelationAnchor
    C.Link
    C.Focus
    String            -- ^ Anchor name

  | CommandStart
  | CommandEnter
  | CommandEscape
  | CommandBackspace
  | CommandComplete
  | CommandChar Char
  | CommandString String
  | Quit
  | Popup              -- ^ Open a popup window
      Popup.Popup
      (Maybe String)   -- ^ The (optionl) HTML ID to focus on
  | QuitPopup
  | SplitBegin
  | SplitChange Int
  | SplitFinish Int
  | ChangeAnnoLevel
  | ChangeAnnoLevelTo C.AnnoLevel
  | SwapFile
  | SwapFileTo C.FileId
  | SwapWorkspaces
  | SwapFiles
  | Compare
  | Dummy
  -- -- | Goto C.Addr -- ^ Move to a given node in the focused window
  | Many (List Msg)
--     -- ^ Tests
--   | TestInput String
--   | TestGet String
--   | TestSend


-- | Changing a node attribute.
type NodeAttr
    = NodeLabelAttr String
    | NodeCommentAttr String


---------------------------------------------------
-- JSON Decoding
--
-- We need it so that commands can be referred to
-- on the backend side (via Dhall).
---------------------------------------------------



msgDecoder : Decode.Decoder Msg
msgDecoder =
    Decode.oneOf
        [
        -- The basic commands
          simple Delete "Delete"
        , simple DeleteTree "DeleteTree"
        , simple Add "Add"
        , simple SaveFile "SaveFile"
        , simple Quit "Quit"
        , simple (ParseRaw False) "ParseRaw"
        , simple (ParseRaw True) "ParseRawPreproc"
        , simple (ParseSent Server.Stanford) "ParseSentStanford"
        , simple (ParseSentPos Server.Stanford) "ParseSentPosStanford"
        , simple (ParseSent Server.DiscoDOP) "ParseSentPosDisco"
        , simple (ParseSentCons Server.DiscoDOP) "ParseSentConsDisco"
        , simple ApplyRules "ApplyRules"
        , simple SplitTree "SplitTree"
        , simple SplitBegin "SplitBegin"
        , simple Compare "Compare"
        , simple Join "Join"
        , simple ConcatWords "ConcatWords"
        , simple Dummy "Dummy"
        , simple SwapWorkspaces "SwapWorkspaces"
        , simple SwapFiles "SwapFiles"

        -- The annotation related commands
        , oneArg MkEntity "MkEntity"
        , oneArg MkRelation "MkRelation"
--         , simple (MkEntity "Signal") "MkSignal"
--         , simple (MkEntity "Timex") "MkTimex"
--         , simple (MkEntity "Event") "MkEvent"
--         , simple (MkRelation "SLink") "MkSLink"
--         , simple (MkRelation "TLink") "MkTLink"
--         , simple (MkRelation "ALink") "MkALink"
--         , simple (MkRelation "MLink") "MkMLink"

        , Decode.value |> Decode.andThen
            ( \val ->
                  let msg = "Unknown message: " ++ Encode.encode 0 val
                      info = Popup.Info msg
                  in  Decode.succeed <| Popup info Nothing
            )
        ]


---------------------------------------------------
-- JSON Utils
---------------------------------------------------


-- | A simple message decoder. The encoded message is represented as a string.
simple
    : Msg
    -- ^ The message
    -> String
    -- ^ Its encoding
    -> Decode.Decoder Msg
simple msg str =
  Decode.map2 (\_ _ -> msg)
    (Decode.field "tag" (isString "Simple"))
    (Decode.field "name" (isString str))


-- | A single-argument message decoder.
oneArg
    : (String -> Msg)
    -- ^ The string-parametrized message
    -> String
    -- ^ The name of the encoded data constructor; the encoded argument is free
    -> Decode.Decoder Msg
oneArg msg str =
  Decode.map3 (\_ _ arg -> msg arg)
    (Decode.field "tag" (isString "OneArg"))
    (Decode.field "name" (isString str))
    (Decode.field "arg" Decode.string)


-- | Tag field with a given value.
tag : String -> Decode.Decoder ()
tag x = Decode.field "tag" (isString x)


isString : String -> Decode.Decoder ()
isString str0
    =  Decode.string
    |> Decode.andThen
       (\str ->
            if str == str0
            then Decode.succeed ()
            else Decode.fail <| "The two strings differ: " ++ str0 ++ " /= " ++ str
       )
