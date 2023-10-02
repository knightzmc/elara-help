{-# LANGUAGE ImplicitParams #-}

{- | Common module for all the different AST pretty impls.
This includes functions for pretty printing in both context-free and context-sensitive forms
-}
module Elara.AST.Pretty where

import Elara.Data.Pretty
import Elara.Data.Pretty.Styles
import Prelude hiding (group)

none :: [()]
none = []

{- | A 'Nothing' value for 'Maybe' 'Doc's
Useful for avoiding type annotations
-}
nothing :: Maybe ()
nothing = Nothing

prettyStringExpr :: Text -> Doc AnsiStyle
prettyStringExpr = dquotes . pretty

prettyCharExpr :: Char -> Doc AnsiStyle
prettyCharExpr = squotes . escapeChar

prettyLambdaExpr :: (?contextFree :: Bool) => (Pretty a, Pretty b) => [a] -> b -> Doc AnsiStyle
prettyLambdaExpr args body = parens (if ?contextFree then prettyCTFLambdaExpr else prettyLambdaExpr')
  where
    prettyCTFLambdaExpr =
        "\\"
            <+> hsep (pretty <$> args)
            <+> "->"
            <+> parens (pretty body)

    prettyLambdaExpr' = group (flatAlt long short)
      where
        short =
            "\\"
                <+> hsep (pretty <$> args)
                <+> "->"
                <+> pretty body

        long =
            align
                ( "\\" <+> hsep (pretty <$> args) <+> "->" <> hardline <> nest indentDepth (pretty body)
                )

prettyFunctionCallExpr :: (Pretty a, Pretty b, ?contextFree :: Bool) => a -> b -> Doc AnsiStyle
prettyFunctionCallExpr e1 e2 = parens (if ?contextFree then short else group (flatAlt long short))
  where
    short = pretty e1 <+> pretty e2
    long = pretty e1 <> hardline <> indent indentDepth (pretty e2)

prettyIfExpr :: (Pretty a, Pretty b, Pretty c) => a -> b -> c -> Doc AnsiStyle
prettyIfExpr e1 e2 e3 = parens ("if" <+> pretty e1 <+> "then" <+> pretty e2 <+> "else" <+> pretty e3)

prettyBinaryOperatorExpr :: (Pretty a, Pretty b, Pretty c) => a -> b -> c -> Doc AnsiStyle
prettyBinaryOperatorExpr e1 o e2 = parens (pretty e1 <+> pretty o <+> pretty e2)

prettyTupleExpr :: (Pretty a) => NonEmpty a -> Doc AnsiStyle
prettyTupleExpr l = parens (hsep (punctuate "," (pretty <$> toList l)))

prettyMatchExpr :: (Pretty a1, Pretty a2, Foldable t, ?contextFree :: Bool) => a1 -> t a2 -> Doc AnsiStyle
prettyMatchExpr e m = parens ("match" <+> pretty e <+> "with" <+> prettyBlockExpr m)

prettyMatchBranch :: (Pretty a1, Pretty a2) => (a1, a2) -> Doc AnsiStyle
prettyMatchBranch (p, e) = pretty p <+> "->" <+> pretty e

prettyLetInExpr :: (Pretty a1, Pretty a2, Pretty a3, Pretty a4, ?contextFree :: Bool) => a1 -> [a2] -> a3 -> a4 -> Doc AnsiStyle
prettyLetInExpr v ps e1 e2 =
    parens
        ( "let"
            <+> pretty v
            <+> hsep (pretty <$> ps)
            <+> "="
            <+> parensIf ?contextFree (pretty e1)
            <+> "in"
            <+> parensIf ?contextFree (pretty e2)
        )

prettyLetExpr :: (Pretty a1, Pretty a2, Pretty a3, ?contextFree :: Bool) => a1 -> [a2] -> a3 -> Doc AnsiStyle
prettyLetExpr v ps e =
    "let"
        <+> pretty v
        <+> hsep (pretty <$> ps)
        <+> "="
        <+> parensIf ?contextFree (pretty e)

prettyBlockExpr :: (Pretty a, Foldable t, ?contextFree :: Bool) => t a -> Doc AnsiStyle
prettyBlockExpr b = do
    let open = if ?contextFree then "{ " else flatAlt "" "{ "
        close = if ?contextFree then "}" else flatAlt "" " }"
        separator = if ?contextFree then "; " else flatAlt "" "; "
        arrange = if ?contextFree then identity else group . align

    arrange (encloseSep' open close separator (pretty <$> toList b))

encloseSep' :: (?contextFree :: Bool) => Doc AnsiStyle -> Doc AnsiStyle -> Doc AnsiStyle -> [Doc AnsiStyle] -> Doc AnsiStyle
encloseSep' = if ?contextFree then encloseSepUnarranged else encloseSep
  where
    encloseSepUnarranged :: Doc AnsiStyle -> Doc AnsiStyle -> Doc AnsiStyle -> [Doc AnsiStyle] -> Doc AnsiStyle
    encloseSepUnarranged open close _ [] = open <> close
    encloseSepUnarranged open close sep (x : xs) = open <> x <> foldr (\y ys -> sep <> y <> ys) close xs

prettyConstructorPattern :: (Pretty a1, Pretty a2) => a1 -> [a2] -> Doc AnsiStyle
prettyConstructorPattern c p = parens (pretty c <+> hsep (pretty <$> p))

prettyList :: (Pretty a, ?contextFree :: Bool) => [a] -> Doc AnsiStyle
prettyList l =
    if ?contextFree
        then encloseSep' "[ " " ]" ", " (pretty <$> l)
        else list (pretty <$> l)

prettyConsPattern :: (Pretty a1, Pretty a2) => a1 -> a2 -> Doc AnsiStyle
prettyConsPattern e1 e2 = parens (pretty e1 <+> "::" <+> pretty e2)

prettyValueDeclaration :: (Pretty a1, Pretty a2, Pretty a3) => a1 -> a2 -> Maybe a3 -> Doc AnsiStyle
prettyValueDeclaration name e expectedType =
    let defLine = fmap (\t' -> "def" <+> pretty name <+> ":" <+> pretty t') expectedType
        rest =
            [ "let" <+> pretty name <+> "="
            , indent indentDepth (pretty e)
            , "" -- add a newline
            ]
     in vsep (maybeToList defLine <> rest)

prettyTypeDeclaration :: (Pretty a1, Pretty a2, Pretty a3) => a1 -> [a2] -> a3 -> Doc AnsiStyle
prettyTypeDeclaration name vars t =
    vsep
        [ keyword "type" <+> typeName (pretty name)
        , keyword "type" <+> typeName (pretty name) <+> hsep (varName . pretty <$> vars)
        , indent indentDepth (pretty t)
        , "" -- add a newline
        ]
