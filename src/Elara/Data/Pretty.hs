{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Elara.Data.Pretty (
    escapeChar,
    indentDepth,
    parensIf,
    Pretty (..),
    module Pretty,
    module Elara.Data.Pretty.Styles,
    module Prettyprinter.Render.Terminal,
    listToText,
) where

import Data.Map qualified as Map (toList)
import Elara.Data.Pretty.Styles
import Prettyprinter as Pretty hiding (Pretty (..), pretty)
import Prettyprinter qualified as PP
import Prettyprinter.Render.Terminal (AnsiStyle)
import Prelude hiding (group)

indentDepth :: Int
indentDepth = 4

parensIf :: Bool -> Doc ann -> Doc ann
parensIf True = parens
parensIf False = identity

listToText :: (Pretty a) => [a] -> Doc AnsiStyle
listToText elements =
    vsep (fmap prettyEntry elements)
  where
    prettyEntry entry = "• " <> align (pretty entry)

class Pretty a where
    pretty :: a -> Doc AnsiStyle
    default pretty :: (Show a) => a -> Doc AnsiStyle
    pretty = pretty @Text . show

instance Pretty Text where
    pretty = PP.pretty

instance Pretty Int where
    pretty = PP.pretty

instance Pretty Integer where
    pretty = PP.pretty

instance Pretty Double where
    pretty = PP.pretty

instance Pretty Float where
    pretty = PP.pretty

instance Pretty Char where
    pretty = PP.pretty

instance Pretty a => Pretty (Maybe a) where
    pretty = maybe mempty pretty

-- instance {-# OVERLAPPABLE #-} (PP.Pretty a) => Pretty a where
--     pretty = PP.pretty

-- hack
instance PP.Pretty (Doc AnsiStyle) where
    pretty = unAnnotate

escapeChar :: (IsString s) => Char -> s
escapeChar c = case c of
    '\a' -> "\\a"
    '\b' -> "\\b"
    '\f' -> "\\f"
    '\n' -> "\\n"
    '\r' -> "\\r"
    '\t' -> "\\t"
    '\v' -> "\\v"
    '\\' -> "\\\\"
    '\'' -> "\\'"
    '"' -> "\\\""
    _ -> fromString [c]

instance {-# INCOHERENT #-} Pretty String where
    pretty = pretty . toText

instance {-# OVERLAPPABLE #-} (Pretty i) => Pretty [i] where
    pretty = align . list . map pretty

instance (Pretty i) => Pretty (NonEmpty i) where
    pretty = pretty . toList

instance (Pretty a, Pretty b) => Pretty (a, b) where
    pretty (a, b) = tupled [pretty a, pretty b]

instance (Pretty k, Pretty v) => Pretty (Map k v) where
    pretty m = pretty (Map.toList m)

instance (Pretty s) => Pretty (Set s) where
    pretty = group . encloseSep (flatAlt "{ " "{") (flatAlt " }" "}") ", " . fmap pretty . toList
