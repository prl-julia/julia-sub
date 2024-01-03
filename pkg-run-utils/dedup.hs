#!/usr/bin/env cabal
{- cabal:
build-depends: base, bytestring, containers, extra
-}

{-# language OverloadedStrings #-}

import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.List.Extra (chunksOf)
import qualified Data.Set as S

marker = "JLSUBTYPELOG: "

main = do
  inp <- BL.getContents
  let ls = map (BL.drop (BL.length marker)) .
        filter (marker `BL.isPrefixOf`) . 
        BL.lines $ inp
  mapM BL.putStrLn (S.toList $ S.fromList ls)

