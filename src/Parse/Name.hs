{-# LANGUAGE TypeFamilies #-}

module Parse.Name where

-- (varName, typeName, opName, moduleName, qualified)

import Control.Monad (when)
import Control.Monad.Combinators.Expr (Operator (InfixL), makeExprParser)
import Data.Functor
import Data.List (singleton)
import Data.Maybe
import Data.Text (pack)
import Debug.Trace (traceShowM)
import Elara.Name
import Parse.Primitives
import Text.Megaparsec
import Text.Megaparsec.Char
import Text.Parser.Combinators (endByNonEmpty)

varName :: Parser Name
varName = qualified varName' False
  where
    varName' :: Parser Name
    varName' = VarName . pack <$> lexeme ((:) <$> lowerChar <*> many alphaNumChar)

typeName :: Parser Name
typeName = qualified typeName' True

typeName' :: Parser Name
typeName' = TypeName . pack <$> lexeme ((:) <$> upperChar <*> many alphaNumChar)

opName :: Parser Name
opName = qualified opName' False
  where
    opName' :: Parser Name
    opName' = OpName . pack <$> lexeme (some operatorChar)
    operatorChar = oneOf ("!#$%&*+./<=>?@\\^|-~" :: String)

moduleName :: Parser Name
moduleName = typeName

qualified :: Parser Name -> Bool -> Parser Name
qualified parser isType = do
  qual <- sepEndBy typeName' (char '.')
  all <-
    if isType
      then pure qual
      else ((qual ++) . singleton) <$> parser
  when (null all) $ void parser
  pure $ foldl1 QualifiedName all