module Elara.Parse.Module where

import Control.Lens (view)
import Data.Maybe (fromMaybe, isJust)
import Elara.AST.Frontend (LocatedExpr, Pattern)
import Elara.Data.Module (Exposing (..), Exposition (ExposedValue), Import (..), Module (..), name)
import Elara.Data.Name (ModuleName)
import Elara.Data.Name qualified as Name
import Elara.Data.TypeAnnotation
import Elara.Parse.Declaration
import Elara.Parse.Name (moduleName, varName)
import Elara.Parse.Primitives (Parser, lexeme, oneOrCommaSeparatedInParens, symbol)
import Text.Megaparsec (MonadParsec (try), many, optional, sepEndBy)
import Text.Megaparsec.Char (newline)
import Utils qualified

module' :: Parser (Module LocatedExpr Pattern TypeAnnotation (Maybe ModuleName))
module' = do
  header <- parseHeader
  let _name = maybe (Name.fromString "Main") fst header
  _ <- many newline

  imports <- import' `sepEndBy` many newline
  declarations <- declaration _name `sepEndBy` many newline

  return $
    Module
      { _moduleName = _name,
        _exposing = maybe ExposingAll snd header,
        _moduleImports = imports,
        _declarations = Utils.associateWithKey (view name) declarations
      }

parseHeader :: Parser (Maybe (ModuleName, Exposing))
parseHeader = optional . try $ do
  -- module Name exposing (..)
  symbol "module"
  moduleName' <- lexeme moduleName
  exposing' <- exposing
  pure (moduleName', exposing')

exposing :: Parser Exposing
exposing =
  fromMaybe ExposingAll
    <$> ( optional . try $ do
            symbol "exposing"
            es <- lexeme (oneOrCommaSeparatedInParens exposition)
            pure $ ExposingSome es
        )

exposition :: Parser Exposition
exposition = ExposedValue <$> varName

import' :: Parser Import
import' = do
  symbol "import"
  name <- lexeme moduleName
  qualified <- optional (symbol "qualified")
  as <- optional . try $ do
    symbol "as"
    lexeme moduleName
  Import name as (isJust qualified) <$> exposing