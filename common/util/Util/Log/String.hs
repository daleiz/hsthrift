-- Copyright (c) Facebook, Inc. and its affiliates.

{-# LANGUAGE ImplicitParams #-}

-- |
-- This module allows you to log things to stderr. Make sure to initialize your
-- application using 'Facebook.Init.initFacebook' or
-- 'Facebook.Init.withFacebook' beforehand. Otherwise you're going to get a
-- cryptic "Logging before InitGoogleLogging() is written to STDERR" error.
module Util.Log.String
  ( vlog
  , vlogIsOn
  , logInfo
  , logWarning
  , logError
  , logFatal
  ) where

import Control.Monad
import Control.Monad.IO.Class (MonadIO, liftIO)
import Foreign.C
import GHC.Stack

import Util.Log.Internal

-- | Equivalent to @VLOG(level)@, except that in Haskell we only evaluate
-- the message if verbosity at the desired level is enabled. Note that
-- this lazy evaluation of the message only applies to 'vlog', not to
-- any of the other logging functions.
vlog :: (MonadIO m, HasCallStack) => Int -> String -> m ()
vlog level msg = liftIO $ do
  b <- vlogIsOn level
  when b $ logCommon c_glog_verbose (getCaller $ getCallStack callStack) msg

-- | The calling point is actually right next to the head as the head is the
-- current function (in this case it would be logInfo/Warning/Error/Fatal).
getCaller :: [(String, SrcLoc)] -> (String, CInt)
getCaller cs =
  case cs of
    -- Take the first element of the stack if it exists
    ((_,sl):_) -> (srcLocFile sl, fromIntegral $ srcLocStartLine sl)
    _       -> ("Unknown stack trace", 0)

-- | Log message at severity level @INFO@.
logInfo :: (MonadIO m, HasCallStack) => String -> m ()
logInfo msg = liftIO $
  logCommon c_glog_info (getCaller $ getCallStack callStack) msg

-- | Log message at severity level @WARNING@.
logWarning :: (MonadIO m, HasCallStack) => String -> m ()
logWarning msg = liftIO $ logCommon c_glog_warning
  (getCaller $ getCallStack callStack) msg

-- | Log message at severity level @ERROR@.
logError :: (MonadIO m, HasCallStack) => String -> m ()
logError msg = liftIO $
  logCommon c_glog_error (getCaller $ getCallStack callStack) msg

-- | Log message at severity level @FATAL@. This will terminate the program
-- after the message is logged.
logFatal :: (MonadIO m, HasCallStack) => String -> m ()
logFatal msg =
  liftIO $ logCommon c_glog_fatal (getCaller $ getCallStack callStack) msg

logCommon :: (CString -> CInt -> CString -> IO ()) ->
             (String, CInt) -> String -> IO ()
logCommon fn (file, lineNumber) msg =
  withCString file $ \file_cstring ->
    withCString msg $ \msg_cstring ->
      fn file_cstring lineNumber msg_cstring
