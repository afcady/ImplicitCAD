-- Implicit CAD. Copyright (C) 2011, Christopher Olah (chris@colah.ca)
-- Released under the GNU GPL, see LICENSE

{-# LANGUAGE MultiParamTypeClasses, FunctionalDependencies, FlexibleInstances, FlexibleContexts, TypeSynonymInstances, UndecidableInstances, ScopedTypeVariables  #-}


import Prelude(IO, Show, String, Int, Maybe(Just,Nothing), Eq, return, ($), show, fmap, (++), putStrLn, filter, zip, null, map, undefined, const, Bool(True,False), fst, snd, sequence, (.), concat, head, tail, sequence, length, (>), (/=), (+))
import Graphics.Implicit.ExtOpenScad.Primitives (primitives)
import Graphics.Implicit.ExtOpenScad.Definitions (ArgParser(AP,APFailIf,APExample,APTest,APTerminator,APBranch))

import qualified Control.Exception as Ex (catch, SomeException)
import Control.Monad (forM_, mapM)

isExample (ExampleDoc _ ) = True
isExample _ = False

isArgument (ArgumentDoc _ _ _) = True
isArgument _ = False

isBranch (Branch _) = True
isBranch _ = False

dumpPrimitive :: String -> [DocPart] -> Int -> IO ()
dumpPrimitive moduleName moduleDocList level = do
            let
                examples = filter isExample moduleDocList
                arguments = filter isArgument moduleDocList
                syntaxes = filter isBranch moduleDocList
                moduleLabel = moduleName

            if level /= 0
              then
                do
                  putStrLn $ "#" ++ moduleLabel
              else
                do
                  putStrLn moduleLabel
                  putStrLn (map (const '-') moduleLabel)
            putStrLn ""

            if null examples
              then
                  return ()
              else
                  do
                    putStrLn "#Examples:\n"
                    forM_ examples $ \(ExampleDoc example) -> do
                      putStrLn $ "   * `" ++ example ++ "`"
                    putStrLn ""

            if null arguments
              then
                  return ()
              else
                do
                  if level /= 0
                    then
                      putStrLn "##Arguments:\n"
                    else
                      if null syntaxes
                      then
                          putStrLn "#Arguments:\n"
                      else
                          putStrLn "#Shared Arguments:\n"
                  forM_ arguments $ \(ArgumentDoc name posfallback description) ->
                      case (posfallback, description) of
                        (Nothing, "") -> do
                          putStrLn $ "   * `" ++ name  ++ "`"
                        (Just fallback, "") -> do
                          putStrLn $ "   * `" ++ name ++ " = " ++ fallback ++ "`"
                        (Nothing, _) -> do
                          putStrLn $ "   * `" ++ name ++ "`"
                          putStrLn $ "     " ++ description
                        (Just fallback, _) -> do
                          putStrLn $ "   * `" ++ name ++ " = " ++ fallback ++ "`"
                          putStrLn $ "     " ++ description
                  putStrLn ""

            if null syntaxes
              then
                  return ()
              else
                  forM_ syntaxes $ \(Branch syntax) -> do
                      dumpPrimitive ("Syntax " ++ (show $ level+1)) syntax (level+1)

main :: IO ()
main = do
        docs <- mapM (getArgParserDocs.($ []).snd) primitives
        let
            names = map fst primitives
            docname = "ImplicitCAD Primitives"

        putStrLn (map (const '=') docname)
        putStrLn docname
        putStrLn (map (const '=') docname)
        putStrLn ""
        putStrLn ""
        forM_ (zip names docs) $ \(moduleName, moduleDocList) -> do
          dumpPrimitive moduleName moduleDocList 0

-- | We need a format to extract documentation into
data Doc = Doc String [DocPart]
             deriving (Show)

data DocPart = ExampleDoc String
             | ArgumentDoc String (Maybe String) String
             | Empty
             | Branch [DocPart]
               deriving (Show,Eq)


--   Here there be dragons!
--   Because we made this a Monad instead of applicative functor, there's no sane way to do this.
--   We give undefined (= an error) and let laziness prevent if from ever being touched.
--   We're using IO so that we can catch an error if this backfires.
--   If so, we *back off*.

-- | Extract Documentation from an ArgParser

getArgParserDocs ::
    (ArgParser a)      -- ^ ArgParser(s)
    -> IO [DocPart]  -- ^ Docs (sadly IO wrapped)

getArgParserDocs (AP name fallback doc fnext) = do
  otherDocs <- Ex.catch (getArgParserDocs $ fnext undefined) (\(e :: Ex.SomeException) -> return [])
  if (otherDocs /= [Empty])
    then
        do
          return $ [(ArgumentDoc name (fmap show fallback) doc)] ++ (otherDocs)
    else
        do
          return $ [(ArgumentDoc name (fmap show fallback) doc)]

getArgParserDocs (APFailIf _ _ child) = do
  childResults <- getArgParserDocs child
  return $ childResults

getArgParserDocs (APExample str child) = do
  childResults <- getArgParserDocs child
  return $ (ExampleDoc str):(childResults)

-- We try to look at as little as possible, to avoid the risk of triggering an error.
-- Yay laziness!

getArgParserDocs (APTest _ _ child) = do
  childResults <- getArgParserDocs child
  return $ childResults

-- To look at this one would almost certainly be death (exception)
getArgParserDocs (APTerminator _) = return $ [(Empty)]

-- This one confuses me.
getArgParserDocs (APBranch children) = do
  putStrLn $ show $ length children
  otherDocs <- Ex.catch (getArgParserDocs (APBranch $ tail children)) (\(e :: Ex.SomeException) -> return [])
  aResults <- getArgParserDocs $ head children
  if (otherDocs /= [(Empty)])
    then
        do
          return $ [Branch ((aResults)++(otherDocs))]
    else
        do
          return aResults
