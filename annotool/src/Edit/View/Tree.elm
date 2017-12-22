module Edit.View.Tree exposing
  (
  -- * Viewing
    viewTree
  , viewLine

  -- * Positioning
  , nodePos
  , positionTree

  -- * Configuration
  , stdWidth
  , defLineCfg
  )


import Char
import List as L
import Set as S
import Dict as D
import Focus as Lens
import Tuple exposing (first, second)
import Mouse exposing (Position)
import Html as Html
import Html.Attributes as Atts
import Html.Events as Events
import Svg as Svg
import Svg.Attributes as Svg

import Rose as R
import Util as Util
import Config as Cfg

import Edit.Core as C
import Edit.Model as M
import Edit.Message.Core exposing (Msg(..))
import Edit.View.Circle as Circle


---------------------------------------------------
-- Drawing trees
---------------------------------------------------


-- | View tree in the specified workspace.
viewTree : C.Focus -> M.Model -> Html.Html Msg
viewTree focus model =

  let

    win = M.selectWin focus model
    treeId = M.getReprId focus win.tree model
    tree = M.getTree focus treeId model
    file = Lens.get (M.fileLens focus) model

    inTree treeId0 (treeId1, nodeId) =
      if treeId0 == treeId1
      then Just nodeId
      else Nothing
    getLinkNodes select =
      S.fromList <|
      L.filterMap (inTree treeId) <|
      L.map select <|
      D.keys file.linkSet

    config =
      { focus = focus
      , selMain = win.selMain
      , selAux = win.selAux
      , linkIn = getLinkNodes second
      , linkOut = getLinkNodes first
      }

  in

    drawTree config
      <| markMisplaced first
      <| positionTree (M.getPosition focus model)
      <| R.withWidth stdWidth Cfg.stdMargin tree


---------------------------------------------------
-- Drawing trees
---------------------------------------------------


type alias TreeCfg =
  { focus : C.Focus
    -- ^ Which window is it in?
  , selMain : Maybe C.NodeId
    -- ^ Selected main
  , selAux : S.Set C.NodeId
    -- ^ Selected auxiliary
  , linkIn : S.Set C.NodeId
    -- ^ The set of node IDs with an in-going relation
  , linkOut : S.Set C.NodeId
    -- ^ The set of node IDs with an out-going relation
  }


drawTree
   : TreeCfg
  -> R.Tree ((M.Node, Position), NodeTyp) -- ^ Tree to draw
  -> Html.Html Msg
drawTree cfg (R.Node ((node, pos), mark) subTrees) =
  let
    lineCfg = { defLineCfg
      | strokeWidth = 2
      , opacity = "0.7" }
    drawForest forest = case forest of
      [] -> []
      t :: ts ->
        drawTree cfg t
          :: viewLine lineCfg pos (second <| first <| R.label t)
          :: drawForest ts
  in
    Html.div []
      (  drawNode cfg node pos mark
      :: drawForest subTrees )


-- | Draw a tree node.
drawNode
   : TreeCfg
  -> M.Node
  -> Position
  -> NodeTyp -- ^ Should be marked as misplaced?
  -> Html.Html Msg
drawNode cfg node =
    case node of
        M.Node r -> drawInternal cfg r
        M.Leaf r -> drawLeaf cfg r


-- | Draw an internal tree node.
drawInternal
   : TreeCfg
  -> M.InternalNode
  -> Position
  -> NodeTyp -- ^ Should be marked as misplaced?
  -> Html.Html Msg
drawInternal cfg node at mark =
  let
    width = stdWidth (M.Node node)
    height = Cfg.nodeHeight
    -- nodeId = Lens.get M.nodeId node
    nodeId = node.nodeId
    auxStyle =
      ( if S.member nodeId cfg.selAux || Just nodeId == cfg.selMain
        then ["background-color" :> "#BC0000"]
        else if mark == Misplaced
        then ["background-color" :> "#EF597B"]
        else ["background-color" :> "#3C8D2F"] )
      ++
      ( if Just nodeId == cfg.selMain
          then ["border" :> "solid", "border-color" :> "black"]
          else ["border" :> "none"] )
    htmlLeaf =
        [ Html.text node.nodeVal
        , case node.nodeTyp of
            Nothing -> Html.sub [] []
            Just en -> Html.sub []
                       [ Html.text <|
                         String.map Char.toUpper <|
                         String.left 2 en.name ]
        ]

    nodeDiv =
      Html.div
        [ nodeMouseDown cfg.focus (M.Node node)
        , Atts.class "noselect"
        , Atts.style <| auxStyle ++
            [ "cursor" :> "pointer"
            -- , "opacity" :> "1.0"

            , "width" :> px width
            , "height" :> px height
            , "border-radius" :> "40%" -- "4px"
            , "position" :> "absolute"

            , "left" :> px (at.x - width // 2)
            , "top" :> px (at.y - height // 2)

            , "color" :> "white"
            , "display" :> "flex"
            , "align-items" :> "center"
            , "justify-content" :> "center"
            ]
        ]
        [Html.p [] htmlLeaf]

    defCircleCfg = Circle.defCircleCfg
    circleCfg isMain =
      { defCircleCfg
      | opacity = Cfg.relMarkerOpacity
      , width = Cfg.relMarkerSize isMain
      , height = Cfg.relMarkerSize isMain }
    circUp =
      { x = at.x - round (toFloat width / Cfg.relMarkerDist)
      , y = at.y - round (toFloat height / Cfg.relMarkerDist) }
    circDown =
      { x = at.x - round (toFloat width / Cfg.relMarkerDist)
      , y = at.y + round (toFloat height / Cfg.relMarkerDist) }
    relDivUp =
      if S.member node.nodeId cfg.linkIn
      then [Circle.drawCircle (circleCfg (cfg.focus == C.Bot)) circUp]
      else []
    relDivDown =
      if S.member node.nodeId cfg.linkOut
      then [Circle.drawCircle (circleCfg (cfg.focus == C.Top)) circDown]
      else []
  in
    Html.div [] (nodeDiv :: relDivUp ++ relDivDown)


-- | Draw a leaf tree node.
drawLeaf
   : TreeCfg
  -> M.LeafNode
  -> Position
  -> NodeTyp -- ^ Should be marked as misplaced?
  -> Html.Html Msg
drawLeaf cfg node at mark =
  let
    width = stdWidth (M.Leaf node)
    height = Cfg.nodeHeight
    nodeId = node.nodeId
    auxStyle =
      ( if S.member nodeId cfg.selAux || Just nodeId == cfg.selMain
        then ["background-color" :> "#BC0000"]
        else if mark == Misplaced
        then ["background-color" :> "#EF597B"]
        else ["background-color" :> "#1F5C9A"] ) -- "#1F9A6D"
      ++
      ( if Just nodeId == cfg.selMain
          then ["border" :> "solid", "border-color" :> "black"]
          else ["border" :> "none"] )
    htmlLeaf =
        [ Html.text node.nodeVal
        , Html.sub [] [Html.text <| toString node.leafPos] ]
  in
    Html.div
      [ nodeMouseDown cfg.focus (M.Leaf node)
      , Atts.class "noselect"
      , Atts.style <| auxStyle ++
          [ "cursor" :> "pointer"
          -- , "opacity" :> "1.0"

          , "width" :> px width
          , "height" :> px height
          , "border-radius" :> "40%" -- "4px"
          , "position" :> "absolute"
          -- , "left" :> px (at.x - nodeWidth // 2)
          -- , "top" :> px (at.y - nodeHeight // 2)
          , "left" :> px (at.x - width // 2)
          , "top" :> px (at.y - height // 2)

          , "color" :> "white"
          , "display" :> "flex"
          , "align-items" :> "center"
          , "justify-content" :> "center"
          ]
      ]
      [Html.p [] htmlLeaf]


---------------------------------------------------
-- Lines
---------------------------------------------------


type alias LineCfg =
  { color : String
  , strokeWidth : Int
  , zindex : Int
  , strokeDasharray : Maybe String
  , opacity : String
  , isArrow : Bool
  }


defLineCfg : LineCfg
defLineCfg =
  { color = "black"
  , strokeWidth = 1
  , zindex = -1
  , strokeDasharray = Nothing
  , opacity = "1"
  , isArrow = False
  }


viewLine : LineCfg -> Position -> Position -> Html.Html Msg
viewLine cfg beg end =
  let
    -- Note that the width is handled in a tricky way. This is to handle the
    -- case where the line is vertical. The case where the line is horizontal is
    -- not handled.
    width  = (\x->x+1) <| abs <| end.x - beg.x
    height = abs <| end.y - beg.y
    (x1, x2) = case end.x >= beg.x of
             True  -> ("1", toString width)
             False -> (toString width, "1")
    (y1, y2) = case end.y >= beg.y of
             True  -> ("0", toString height)
             False -> (toString height, "0")
    dash = case cfg.strokeDasharray of
      Nothing -> []
      Just x  -> [Svg.strokeDasharray x]
    line = Svg.line
      ( [ Svg.stroke cfg.color
        , Svg.strokeWidth (toString cfg.strokeWidth)
        , Svg.opacity cfg.opacity
        , Svg.x1 x1, Svg.y1 y1, Svg.x2 x2, Svg.y2 y2 ]
        ++ dash
      )
      []
    svg = Svg.svg
      [ Svg.width (toString <| (\x->x+1) <| width)
      , Svg.height (toString height)
      ] [line]
  in
    Html.div
      [ Atts.style
          [ "position" :> "absolute"
          , "left" :> px (min beg.x end.x)
          , "top" :> px (min beg.y end.y)
          , "pointer-events" :> "none"
          , "z-index" :> toString cfg.zindex
          ]
      ]
      [svg]


---------------------------------------------------
-- Configuration
---------------------------------------------------


-- | Width of a node.
stdWidth : M.Node -> Int
stdWidth x =
  let
    (txt, ix) = case x of
      M.Node r -> (r.nodeVal, "")
      M.Leaf r -> (r.nodeVal, toString r.leafPos)
  in
    max 30 <| String.length txt * 10 + String.length ix * 6


---------------------------------------------------
-- Events
---------------------------------------------------


nodeMouseDown : C.Focus -> M.Node -> Html.Attribute Msg
nodeMouseDown win x =
  Events.onMouseDown (Select win <| Lens.get M.nodeId x)


---------------------------------------------------
-- Determine which nodes should be marked
-- as "misplaced" or "non-projective"
---------------------------------------------------


-- | To mark nodes as misplaced.
type NodeTyp = Normal | Misplaced


-- | Determine which leaves should be marked as "misplaced".
markMisplaced
    : (a -> M.Node)
    -> R.Tree a
    -> R.Tree (a, NodeTyp)
markMisplaced getNode =
    let
        markTree prevSpan (R.Node (wrapper, span) forest) =
            let
                nodeTyp = case prevSpan of
                    Nothing -> Normal
                    Just (_, prevEnd) ->
                        if prevEnd < first span
                        then Normal
                        else Misplaced
            in
                (Just span, R.Node (wrapper, nodeTyp) (markForest forest))
        markForest =
            second << Util.mapAccumL markTree Nothing
        markRoot (R.Node (wrapper, span) forest) =
            R.Node (wrapper, Normal) (markForest forest)
    in
        propagateMarks << markRoot << addSpans getNode


-- | Propagate the markings downward to the leaves.
propagateMarks
    : R.Tree (a, NodeTyp)
    -> R.Tree (a, NodeTyp)
propagateMarks =
    let
        propTyp typ =
            case typ of
                Normal -> Nothing
                x -> Just x
        markTree fromUp (R.Node (wrapper, typ) forest) =
            case fromUp of
                Nothing ->
                    let newTyp = propTyp typ
                    in  R.Node (wrapper, typ) (markForest newTyp forest)
                Just newTyp ->
                    R.Node (wrapper, newTyp) (markForest fromUp forest)
        markForest : Maybe NodeTyp -> R.Forest (a, NodeTyp) -> R.Forest (a, NodeTyp)
        markForest fromUp = L.map (markTree fromUp)
    in
        markTree Nothing


-- | Determine node spans.
addSpans
    : (a -> M.Node)
    -> R.Tree a
    -> R.Tree (a, (Int, Int))
addSpans getNode =
    let
        go (R.Node wrapper forest0) =
            case getNode wrapper of
                M.Node _ ->
                    let forest = L.map go forest0
                        beg = spanBeg forest
                        end = spanEnd forest
                        span = (beg, end)
                    in  R.Node (wrapper, span) forest
                M.Leaf r ->
                    let span = (r.leafPos, r.leafPos)
                    in  R.Node (wrapper, span) []
        spanBeg xs =
            case L.minimum <| L.map (first << second << R.label) xs of
                Nothing -> Debug.crash "Edit.View.addSpans: spanBeg"
                Just x  -> x
        spanEnd xs =
            case L.maximum <| L.map (second << second << R.label) xs of
                Nothing -> Debug.crash "Edit.View.addSpans: spanEnd"
                Just x  -> x
    in
        go


---------------------------------------------------
-- Positioning
---------------------------------------------------


-- | Position a given tree. This function calculates the positions of the
-- individual nodes in the given tree, based on their widths (see also
-- `R.withWidth`).
positionTree : Position -> R.Tree (M.Node, R.Width) -> R.Tree (M.Node, Position)
positionTree pos (R.Node (node, rootWidth) subTrees) =
  let
    forestWidth = List.sum <| L.map (R.label >> second) subTrees
    positionF w0 forest = case forest of
      [] -> []
      t :: ts ->
        let
          tw = second <| R.label t
          tpos = {x = w0 + tw // 2, y = pos.y + Cfg.moveDown}
        in
          positionTree tpos t :: positionF (w0 + tw) ts
  in
    R.Node (node, pos) (positionF (pos.x - forestWidth // 2) subTrees)


-- | Retrieve the position of a node in a given tree.
nodePos : C.NodeId -> R.Tree (M.Node, Position) -> Maybe Position
nodePos nodeId tree = Maybe.map second <|
  Util.find
    (\node -> Lens.get M.nodeId (first node) == nodeId)
    (R.flatten tree)


---------------------------------------------------
-- Utils
---------------------------------------------------


(:>) : a -> b -> (a, b)
(:>) = (,)


px : Int -> String
px number =
  toString number ++ "px"