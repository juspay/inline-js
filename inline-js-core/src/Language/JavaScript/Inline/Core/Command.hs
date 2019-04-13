{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}

module Language.JavaScript.Inline.Core.Command
  ( eval
  , alloc
  , importMJS
  ) where

import Control.Monad.Fail
import qualified Data.ByteString.Lazy as LBS
import Language.JavaScript.Inline.Core.JSCode
import Language.JavaScript.Inline.Core.Message.Class
import Language.JavaScript.Inline.Core.Message.Eval
import Language.JavaScript.Inline.Core.Session
import Prelude hiding (fail)
import System.Directory

checkEvalResponse :: EvalResponse r -> IO r
checkEvalResponse r =
  case r of
    EvalError {..} ->
      fail $
      "Language.JavaScript.Inline.Core.Commands.checkEvalResponse: evaluation failed with " <>
      show evalError
    EvalResult {..} -> pure evalResult

-- | Runs a 'JSCode' and returns the result.
--
-- Throws in Haskell if the response indicates a failure.
--
-- Explicit type annotation of the returned value is often required.
-- See docs of 'EvalRequest' for supported result types.
eval ::
     forall r.
     ( Request (EvalRequest r)
     , Response (EvalResponse r)
     , ResponseOf (EvalRequest r) ~ (EvalResponse r)
     )
  => JSSession
  -> JSCode
  -> IO r
eval s c =
  sendRecv
    s
    (EvalRequest {evalTimeout = Nothing, resolveTimeout = Nothing, evalCode = c} :: EvalRequest r) >>=
  checkEvalResponse

-- | Allocates a @Buffer@ and returns the 'JSVal'.
--
-- Throws in Haskell if the response indicates a failure.
alloc :: JSSession -> LBS.ByteString -> IO JSVal
alloc s buf = sendRecv s AllocRequest {allocContent = buf} >>= checkEvalResponse

-- | @import()@ a @.mjs@ ECMAScript module and returns the 'JSVal' of the module namespace object.
--
-- Throws in Haskell if the response indicates a failure.
importMJS :: JSSession -> FilePath -> IO JSVal
importMJS s p = do
  p' <- canonicalizePath p
  sendRecv s ImportRequest {importPath = p'} >>= checkEvalResponse