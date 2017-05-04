module Message exposing (Msg(..), update, dummy)


import List as L
import Mouse exposing (Position)
import Task as Task
import Dom as Dom
import Focus exposing ((=>))
import Focus as Focus

import Model as M
import Config as Cfg


type Msg
    = DragStart M.Focus Position
      -- ^ Neither `DragAt` nor `DragEnd` have their focus. This is on purpose.
      -- Focus should be determined, in their case, on the basis of the drag in
      -- the underlying model. We do not support concurrent drags at the moment.
    | DragAt Position
    | DragEnd Position
    | Select M.Focus M.NodeId
    | Focus M.Focus
    | Resize Int -- ^ The height of the entire window
    | Increase Bool -- ^ Increase the size of the top window
    | Previous
    | Next
    | ChangeLabel M.NodeId M.Focus String
    | EditLabel
    | Delete -- ^ Delete the selected nodes in the focused window
    | Add -- ^ Delete the selected nodes in the focused window
    | Many (List Msg)


-- update : Msg -> M.Model -> ( M.Model, Cmd Msg )
-- update msg model =
--   ( updateHelp msg model, Cmd.none )


update : Msg -> M.Model -> ( M.Model, Cmd Msg )
update msg model =

 let idle x = (x, Cmd.none)

 in
  case msg of

    DragStart focus xy -> idle <|
      Focus.set
        (M.winLens focus => M.drag)
        (Just (M.Drag xy xy))
        model

    DragAt xy -> idle <|
      Focus.update
        (M.winLens (M.dragOn model) => M.drag)
        (Maybe.map (\{start} -> M.Drag start xy))
        model

    DragEnd _ -> idle
      <| Focus.update (M.winLens (M.dragOn model))
           (\win -> { win | drag = Nothing, pos = M.getPosition win})
      <| model

    Focus win -> idle <| {model | focus = win}

    Resize height -> idle <| {model | winHeight = height}

    Increase flag -> idle <|
      let
        newProp = trim <| model.winProp + change
        trim x = max 0 <| min 100 <| x
        change = case flag of
          True  -> Cfg.increaseSpeed
          False -> -Cfg.increaseSpeed
      in
        {model | winProp = newProp}

    Select win i -> idle <| M.selectNode win i model

    Next -> idle <| M.moveCursor True model

    Previous -> idle <| M.moveCursor False model

    ChangeLabel nodeId win newLabel -> idle <| M.setLabel nodeId win newLabel model

    EditLabel ->
      let target = case model.focus of
        M.Top -> Cfg.editLabelName True
        M.Bot -> Cfg.editLabelName False
      in
        ( model
        , Task.attempt
            (\_ -> dummy)
            (Dom.focus target)
        )

    Delete -> idle <| M.deleteSel model.focus model

    Add -> idle <| M.addSel model.focus model

    Many ms ->
      let f msg (mdl0, cmds) =
        let (mdl, cmd) = update msg mdl0
        in  (mdl, cmd :: cmds)
      in
        let (mdl, cmds) = L.foldl f (model, []) ms
        in  (mdl, Cmd.batch cmds)


-- | A dummy message.  Should avoid this...
dummy : Msg
dummy = Many []
