{-# OPTIONS -cpp #-}
--  GIMP Toolkit (GTK) UTF aware string marshalling, version dependencies
--
--  Author : Axel Simon
--          
--  Created: 22 June 2001
--
--  Version $Revision: 1.1 $ from $Date: 2003/07/10 08:20:25 $
--
--  Copyright (c) 1999..2002 Axel Simon
--
--  This file is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This file is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
-- @description@ --------------------------------------------------------------
--
-- * This module adds CString-like functions that handle UTF8 strings.
--   Furthermore it serves as an impedance matcher for different compiler
--   versions.
--
--- DOCU ----------------------------------------------------------------------
--
--
--- TODO ----------------------------------------------------------------------

module FFI(
  with,
  nullForeignPtr,
  foreignFree,
  withUTFString,
  withUTFStringLen,
  newUTFString,
  newUTFStringLen,
  peekUTFString,
  peekUTFStringLen,
  module Foreign,
#if __GLASGOW_HASKELL__>=504
  module Foreign.C
#else
  module CForeign
#endif
  ) where

import Monad	(liftM)
import Char
import LocalData(unsafePerformIO)

#if __GLASGOW_HASKELL__>=504
import Data.Bits
import Foreign.C
import qualified Foreign
import Foreign	 hiding (with)
#else
import Bits
import CForeign
import qualified Foreign
import Foreign	 hiding (withObject)
#endif


#if __GLASGOW_HASKELL__>=504
with :: (Storable a) => a -> (Ptr a -> IO b) -> IO b
with = Foreign.with
#else
with :: (Storable a) => a -> (Ptr a -> IO b) -> IO b
with = Foreign.withObject
#endif

#if __GLASGOW_HASKELL__>=600
foreign import ccall unsafe "&free"
  free' :: FinalizerPtr a

foreignFree :: Ptr a -> FinalizerPtr a
foreignFree _ = free'

nullForeignPtr :: ForeignPtr a
nullForeignPtr = unsafePerformIO $ newForeignPtr nullPtr free'
#else
nullForeignPtr :: ForeignPtr a
nullForeignPtr = unsafePerformIO $ newForeignPtr nullPtr (return ())

foreignFree :: Ptr a -> IO ()
foreignFree = free
#endif


-- Define withUTFString to emit UTF-8.
--
withUTFString :: String -> (CString -> IO a) -> IO a
withUTFString hsStr = withCString (toUTF hsStr)

-- Define withUTFStringLen to emit UTF-8.
--
withUTFStringLen :: String -> (CStringLen -> IO a) -> IO a
withUTFStringLen hsStr = withCStringLen (toUTF hsStr)

-- Define newUTFString to emit UTF-8.
--
newUTFString :: String -> IO CString
newUTFString = newCString . toUTF

-- Define newUTFStringLen to emit UTF-8.
--
newUTFStringLen :: String -> IO CStringLen
newUTFStringLen = newCStringLen . toUTF

-- Define peekUTFString to retrieve UTF-8.
--
peekUTFString :: CString -> IO String
peekUTFString strPtr = liftM fromUTF $ peekCString strPtr

-- Define peekUTFStringLen to retrieve UTF-8.
--
peekUTFStringLen :: CStringLen -> IO String
peekUTFStringLen strPtr = liftM fromUTF $ peekCStringLen strPtr

-- Convert Unicode characters to UTF-8.
--
toUTF :: String -> String
toUTF [] = []
toUTF (x:xs) | ord x<=0x007F = x:toUTF xs
	     | ord x<=0x07FF = chr (0xC0 .|. ((ord x `shift` (-6)) .&. 0x1F)):
			       chr (0x80 .|. (ord x .&. 0x3F)):
			       toUTF xs
	     | otherwise     = chr (0xE0 .|. ((ord x `shift` (-12)) .&. 0x0F)):
			       chr (0x80 .|. ((ord x `shift` (-6)) .&. 0x3F)):
			       chr (0x80 .|. (ord x .&. 0x3F)):
			       toUTF xs

-- Convert UTF-8 to Unicode.
--
fromUTF :: String -> String
fromUTF [] = []
fromUTF (all@(x:xs)) | ord x<=0x7F = x:fromUTF xs
		     | ord x<=0xBF = err
		     | ord x<=0xDF = twoBytes all
		     | ord x<=0xEF = threeBytes all
		     | otherwise   = err
  where
    twoBytes (x1:x2:xs) = chr (((ord x1 .&. 0x1F) `shift` 6) .|.
			       (ord x2 .&. 0x3F)):fromUTF xs
    twoBytes _ = error "fromUTF: illegal two byte sequence"

    threeBytes (x1:x2:x3:xs) = chr (((ord x1 .&. 0x0F) `shift` 12) .|.
				    ((ord x2 .&. 0x3F) `shift` 6) .|.
				    (ord x3 .&. 0x3F)):fromUTF xs
    threeBytes _ = error "fromUTF: illegal three byte sequence" 
    
    err = error "fromUTF: illegal UTF-8 character"