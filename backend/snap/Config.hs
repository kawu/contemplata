{-# LANGUAGE LambdaCase #-}


module Config
( fromCfg
, fromCfgDef
) where


import qualified Data.Configurator as Cfg
import qualified Data.Configurator.Types as Cfg
import qualified Data.Text as T


-- | Configuration with no default value.
fromCfg :: (Show a, Cfg.Configured a) => Cfg.Config -> Cfg.Name -> IO (Maybe a)
fromCfg cfg key = do
  Cfg.lookup cfg key >>= \case
    Nothing -> return Nothing
    Just path -> do
      putStrLn $ "[Config] Using the configured " ++ T.unpack key ++ " value: " ++ show path
      return $ Just path


-- | Configuration with default value.
fromCfgDef :: (Show a, Cfg.Configured a) => Cfg.Config -> Cfg.Name -> a -> IO a
fromCfgDef cfg key def = do
  Cfg.lookup cfg key >>= \case
    Nothing -> do
      putStrLn $ "[Config] Using the default " ++ T.unpack key ++ " value: " ++ show def
      return def
    Just path -> do
      putStrLn $ "[Config] Using the configured " ++ T.unpack key ++ " value: " ++ show path
      return path

