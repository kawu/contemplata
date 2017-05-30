{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}


-- | Types of the annotation server.


module Odil.Server.Types
(
-- * Types
  FileId
, TreeId
, NodeId
, LeafId
, Sent
, Tree
, Node (..)
, NodeTyp (..)
, File (..)
, Link (..)
, Addr

-- * JSON
) where


import GHC.Generics

import qualified Data.Set as S
import qualified Data.Map.Strict as M
import qualified Data.Tree as R
import qualified Data.Text as T
import qualified Data.Aeson as JSON

import qualified Odil.AnnoTypes as Anno


-----------
-- Types
-----------


-- | ID of a file.
type FileId = T.Text


-- | ID of a syntactic tree.
type TreeId = Int


-- | Node ID.
type NodeId = Int


-- | Leaf ID; corresponds to the order of words in a given sentence.
type LeafId = Int


-- | A sentence underlying a syntactic tree.
type Sent = T.Text


-- | A syntactic tree.
type Tree = R.Tree Node


-- | A node of a syntactic tree.
data Node
  = Node
    { nodeId :: NodeId
    , nodeVal :: T.Text
    , nodeTyp :: Maybe NodeTyp }
  | Leaf
    { leafId :: NodeId
    , leafVal :: T.Text
    , leafPos :: Int }
  deriving (Generic, Show, Eq, Ord)


-- | Type of the node, together with the corresponding annotation.
data NodeTyp
  = NodeEvent Anno.Event
  | NodeTimex
  deriving (Generic, Show, Eq, Ord)


-- | A file.
data File = File
  { treeMap :: M.Map TreeId (Sent, Tree)
  , linkSet :: S.Set Link }
  deriving (Generic, Show, Eq)


-- | A link between two nodes in a given file.
data Link = Link
  { from :: Addr
  , to :: Addr }
  deriving (Generic, Show, Eq, Ord)


-- | A node address.
type Addr = (TreeId, NodeId)


-----------
-- Various
-----------


-----------
-- JSON
-----------


instance JSON.FromJSON NodeTyp
instance JSON.ToJSON NodeTyp where
  toEncoding = JSON.genericToEncoding JSON.defaultOptions

instance JSON.FromJSON Node
instance JSON.ToJSON Node where
  toEncoding = JSON.genericToEncoding JSON.defaultOptions


instance JSON.FromJSON Link
instance JSON.ToJSON Link where
  toEncoding = JSON.genericToEncoding JSON.defaultOptions


instance JSON.FromJSON File
instance JSON.ToJSON File where
  toEncoding = JSON.genericToEncoding JSON.defaultOptions
