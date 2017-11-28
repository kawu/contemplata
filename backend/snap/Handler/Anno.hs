{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}


module Handler.Anno
( annoHandler
, adjuHandler
) where


import           Control.Monad (when)
import           Control.Monad.IO.Class (liftIO)
import           Control.Monad.Trans.Class (lift)

import           Data.Map.Syntax ((##))
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import qualified Data.Configurator as Cfg

import qualified Snap.Snaplet.Heist as Heist
import qualified Snap as Snap
import qualified Snap.Snaplet.Auth as Auth
import           Heist.Interpreted (bindSplices, Splice)
import qualified Text.XmlHtml as X

import qualified Odil.Server.Types as Odil
import qualified Odil.Server.DB as DB
-- import qualified Config as Cfg
import           Application
import           Handler.Utils (liftDB)


---------------------------------------
-- Regular annotation
---------------------------------------


annoHandler :: AppHandler ()
annoHandler = do
  Heist.heistLocal (bindSplices localSplices) (Heist.render "annotation")
  where
    localSplices = do
      "annoBody" ## annoBodySplice


annoBodySplice :: Splice AppHandler
annoBodySplice = do
  Just fileIdTxt <- fmap T.decodeUtf8 <$> Snap.getParam "filename"
  Just fileId <- return $ Odil.decodeFileId fileIdTxt
  -- liftIO $ putStrLn "DEBUG: " >> print fileId
  mbUser <- lift $ Snap.with auth Auth.currentUser
  case mbUser of
    Nothing -> return [X.TextNode "access not authorized"]
    Just user -> do
      let login = Auth.userLogin user
      cfg <- lift Snap.getSnapletUserConfig
      -- Just serverPath <- liftIO $ Cfg.fromCfg cfg "websocket-server"
      -- Just serverPathAlt <- liftIO $ Cfg.fromCfg cfg "websocket-server-alt"
      Just serverPath <- liftIO $ Cfg.lookup cfg "websocket-server"
      Just serverPathAlt <- liftIO $ Cfg.lookup cfg "websocket-server-alt"
      -- Mark the file as being annotated
      lift . liftDB $ do
        DB.accessLevel fileId login >>= \case
          Just acc -> when
            (acc >= Odil.Write)
            (DB.startAnnotating fileId)
          _ -> return ()
      let html = X.Element "body" [] [script]
          script = X.Element "script" [("type", "text/javascript")] [text]
          mkArg key val = T.concat [key, ": \"", val, "\""]
          mkArgs = T.intercalate ", " . map (uncurry mkArg)
          text = X.TextNode $ T.concat
            [ "Elm.Main.fullscreen({"
            , mkArgs
              [ ("userName", login)
              , ("fileId", Odil.encodeFileId fileId)
              , ("compId", "")
              , ("websocketServer", serverPath)
              , ("websocketServerAlt", serverPathAlt)
              ]
            , "})"
            ]
--             [ "Elm.Main.fullscreen({userName: \""
--             , Auth.userLogin user
--             , "\"})"
--             ]
      return [html]


---------------------------------------
-- Adjudication
---------------------------------------


adjuHandler :: AppHandler ()
adjuHandler = do
  Heist.heistLocal (bindSplices localSplices) (Heist.render "annotation")
  where
    localSplices = do
      "annoBody" ## adjuBodySplice


adjuBodySplice :: Splice AppHandler
adjuBodySplice = do
  -- The main file
  Just fileIdTxt <- fmap T.decodeUtf8 <$> Snap.getParam "main"
  Just mainId <- return $ Odil.decodeFileId fileIdTxt
  -- The other file, for comparison
  Just fileIdTxt <- fmap T.decodeUtf8 <$> Snap.getParam "comp"
  Just compId <- return $ Odil.decodeFileId fileIdTxt
  mbUser <- lift $ Snap.with auth Auth.currentUser
  case mbUser of
    Nothing -> return [X.TextNode "access not authorized"]
    Just user -> do
      let login = Auth.userLogin user
      cfg <- lift Snap.getSnapletUserConfig
      Just serverPath <- liftIO $ Cfg.lookup cfg "websocket-server"
      Just serverPathAlt <- liftIO $ Cfg.lookup cfg "websocket-server-alt"
--       -- Mark the file as being annotated
--       lift . liftDB $ do
--         DB.accessLevel fileId login >>= \case
--           Just acc -> when
--             (acc >= Odil.Write)
--             (DB.startAnnotating fileId)
--           _ -> return ()
      let html = X.Element "body" [] [script]
          script = X.Element "script" [("type", "text/javascript")] [text]
          mkArg key val = T.concat [key, ": \"", val, "\""]
          mkArgs = T.intercalate ", " . map (uncurry mkArg)
          text = X.TextNode $ T.concat
            [ "Elm.Main.fullscreen({"
            , mkArgs
              [ ("userName", login)
              , ("fileId", Odil.encodeFileId mainId)
              , ("compId", Odil.encodeFileId compId)
              , ("websocketServer", serverPath)
              , ("websocketServerAlt", serverPathAlt)
              ]
            , "})"
            ]
      return [html]
