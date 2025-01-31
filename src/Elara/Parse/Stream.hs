{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE RecordWildCards #-}

module Elara.Parse.Stream where

import Data.Text qualified as T
import Elara.AST.Region (HasPath (path), Located (Located), RealPosition (Position), RealSourceRegion, generatedFileName, generatedSourcePos, sourceRegion, startPos, unlocated, _RealSourceRegion)
import Elara.Lexer.Token
import Text.Megaparsec

data TokenStream = TokenStream
    { tokenStreamInput :: !String
    , tokenStreamTokens :: ![Lexeme]
    , skipIndents :: Bool
    }
    deriving (Show, Eq)

pattern L :: a -> Located a
pattern L i <- Located _ i

instance Stream TokenStream where
    type Token TokenStream = Lexeme
    type Tokens TokenStream = [Lexeme]
    tokenToChunk Proxy x = [x]
    tokensToChunk Proxy xs = xs
    chunkToTokens Proxy = identity
    chunkLength Proxy = length
    chunkEmpty Proxy = null
    take1_ :: TokenStream -> Maybe (Text.Megaparsec.Token TokenStream, TokenStream)
    take1_ (TokenStream _ [] _) = Nothing
    take1_ (TokenStream str (Located _ t : ts) skipIndents@True) | isIndent t = take1_ (TokenStream str ts skipIndents)
    take1_ (TokenStream str (t : ts) skipIndents) =
        Just (t, TokenStream (drop (tokensLength (Proxy @TokenStream) (t :| [])) str) ts skipIndents)
    takeN_ n (TokenStream str s skipIndents)
        | n <= 0 = Just ([], TokenStream str s skipIndents)
        | null s = Nothing
        | otherwise -- repeatedly call take1_ until it returns Nothing
            =
            let (x, s') = takeWhile_ (const True) (TokenStream str s skipIndents)
             in case takeN_ (n - length x) s' of
                    Nothing -> Nothing
                    Just (xs, s'') -> Just (x ++ xs, s'')

    takeWhile_ f (TokenStream str s skipIndents) =
        let (x, s') = span f s
         in case nonEmpty x of
                Nothing -> (x, TokenStream str s' skipIndents)
                Just nex -> (x, TokenStream (drop (tokensLength (Proxy @TokenStream) nex) str) s' skipIndents)

instance VisualStream TokenStream where
    showTokens Proxy =
        toString
            . T.intercalate " "
            . toList
            . fmap (tokenRepr . view unlocated)
    tokensLength Proxy xs = sum (tokenLength <$> xs)

instance TraversableStream TokenStream where
    reachOffset o PosState{..} =
        ( Just (prefix ++ restOfLine)
        , PosState
            { pstateInput =
                TokenStream
                    { tokenStreamInput = postStr
                    , tokenStreamTokens = postLexemes
                    , skipIndents = pstateInput.skipIndents
                    }
            , pstateOffset = max pstateOffset o
            , pstateSourcePos = newSourcePos
            , pstateTabWidth = pstateTabWidth
            , pstateLinePrefix = prefix
            }
        )
      where
        prefix =
            if sameLine
                then pstateLinePrefix ++ preLine
                else preLine
        sameLine = sourceLine newSourcePos == sourceLine pstateSourcePos
        newSourcePos =
            case postLexemes of
                [] -> pstateSourcePos
                (x : _) -> sourceRegionToSourcePos x sourceRegion startPos
        (preLexemes, postLexemes) = splitAt (o - pstateOffset) (tokenStreamTokens pstateInput)
        (preStr, postStr) = splitAt tokensConsumed (tokenStreamInput pstateInput)
        preLine = reverse . takeWhile (/= '\n') . reverse $ preStr
        tokensConsumed =
            case nonEmpty preLexemes of
                Nothing -> 0
                Just nePre -> tokensLength (Proxy @TokenStream) nePre
        restOfLine = takeWhile (/= '\n') postStr

sourceRegionToSourcePos :: HasPath a1 => Located a2 -> Lens' (Located a2) a1 -> Lens' RealSourceRegion RealPosition -> SourcePos
sourceRegionToSourcePos sr l which = do
    let fp = view (l % path) sr
    case preview (sourceRegion % _RealSourceRegion % which) sr of
        Just pos -> realPositionToSourcePos fp pos
        Nothing -> generatedSourcePos fp

realPositionToSourcePos :: Maybe FilePath -> RealPosition -> SourcePos
realPositionToSourcePos fp (Position line column) =
    SourcePos
        { sourceName = fromMaybe generatedFileName fp
        , sourceLine = mkPos line
        , sourceColumn = mkPos column
        }

tokenLength :: Lexeme -> Int
tokenLength = T.length . tokenRepr . view unlocated
