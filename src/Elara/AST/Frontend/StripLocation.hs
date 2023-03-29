{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE UndecidableInstances #-}

module Elara.AST.Frontend.StripLocation where

import Elara.AST.Frontend qualified as Frontend
import Elara.AST.Frontend.Unlocated as Unlocated
import Elara.AST.Module
import Elara.AST.Name (Name)
import Elara.AST.Region
import Elara.AST.Select
import Prelude hiding (Op, Type)

class StripLocation a b | a -> b where
    stripLocation :: a -> b

instance StripLocation (Located a) a where
    stripLocation :: Located a -> a
    stripLocation (Located _ a) = a

instance {-# OVERLAPPABLE #-} (Functor f, StripLocation a b) => StripLocation (f a) (f b) where
    stripLocation = fmap stripLocation

instance (StripLocation a a', StripLocation b b') => StripLocation (a, b) (a', b') where
    stripLocation (a, b) = (stripLocation a, stripLocation b)

instance StripLocation Frontend.Expr Expr where
    stripLocation (Frontend.Expr (Located _ expr)) = case expr of
        Frontend.Int i -> Int i
        Frontend.Float f -> Float f
        Frontend.String s -> String s
        Frontend.Char c -> Char c
        Frontend.Unit -> Unit
        Frontend.Var v -> Var (stripLocation v)
        Frontend.Constructor c -> Constructor (stripLocation c)
        Frontend.Lambda p e -> Lambda (stripLocation p) (stripLocation e)
        Frontend.FunctionCall e1 e2 -> FunctionCall (stripLocation e1) (stripLocation e2)
        Frontend.If e1 e2 e3 -> If (stripLocation e1) (stripLocation e2) (stripLocation e3)
        Frontend.BinaryOperator o e1 e2 -> BinaryOperator (stripLocation o) (stripLocation e1) (stripLocation e2)
        Frontend.List l -> List (stripLocation l)
        Frontend.Match e m -> Match (stripLocation e) (stripLocation m)
        Frontend.LetIn v p e1 e2 -> LetIn (stripLocation v) (stripLocation p) (stripLocation e1) (stripLocation e2)
        Frontend.Let v p e -> Let (stripLocation v) (stripLocation p) (stripLocation e)
        Frontend.Block b -> Block (stripLocation b)
        Frontend.InParens e -> InParens (stripLocation e)

instance StripLocation Frontend.Pattern Pattern where
    stripLocation (Frontend.Pattern (Located _ pat)) = case pat of
        Frontend.VarPattern n -> VarPattern (stripLocation n)
        Frontend.ConstructorPattern c p -> ConstructorPattern (stripLocation c) (stripLocation p)
        Frontend.ListPattern p -> ListPattern (stripLocation p)
        Frontend.WildcardPattern -> WildcardPattern
        Frontend.IntegerPattern i -> IntegerPattern i
        Frontend.FloatPattern f -> FloatPattern f
        Frontend.StringPattern s -> StringPattern s
        Frontend.CharPattern c -> CharPattern c

instance StripLocation Frontend.BinaryOperator BinaryOperator where
    stripLocation (Frontend.MkBinaryOperator (Located _ op)) = case op of
        Frontend.Op o -> Op (stripLocation o)
        Frontend.Infixed i -> Infixed (stripLocation i)

instance StripLocation Frontend.Type Type where
    stripLocation (Frontend.TypeVar t) = TypeVar t
    stripLocation (Frontend.FunctionType t1 t2) = FunctionType (stripLocation t1) (stripLocation t2)
    stripLocation Frontend.UnitType = UnitType
    stripLocation (Frontend.TypeConstructorApplication t1 t2) = TypeConstructorApplication (stripLocation t1) (stripLocation t2)
    stripLocation (Frontend.UserDefinedType t) = UserDefinedType (stripLocation t)
    stripLocation (Frontend.RecordType r) = RecordType (stripLocation r)

instance StripLocation (Module Frontend) (Module UnlocatedFrontend) where
    stripLocation (Module m) = Module (stripLocation (stripLocation m :: Module' Frontend))

instance StripLocation (Module' Frontend) (Module' UnlocatedFrontend) where
    stripLocation (Module' n e i d) = Module' (stripLocation n) (stripLocation e) (stripLocation i) (stripLocation d)

instance StripLocation (Exposing Frontend) (Exposing UnlocatedFrontend) where
    stripLocation ExposingAll = ExposingAll
    stripLocation (ExposingSome e) = ExposingSome (stripLocation e)

instance StripLocation (Exposition Frontend) (Exposition UnlocatedFrontend) where
    stripLocation (ExposedValue n) = ExposedValue (stripLocation n)
    stripLocation (ExposedType tn) = ExposedType (stripLocation tn)
    stripLocation (ExposedTypeAndAllConstructors tn) = ExposedTypeAndAllConstructors (stripLocation tn)
    stripLocation (ExposedOp o) = ExposedOp (stripLocation o)

instance StripLocation (Import Frontend) (Import UnlocatedFrontend) where
    stripLocation (Import m) = Import (stripLocation (stripLocation m :: Import' Frontend))

instance StripLocation (Import' Frontend) (Import' UnlocatedFrontend) where
    stripLocation (Import' i a q e) = Import' (stripLocation i) (stripLocation a) q (stripLocation e)

instance StripLocation Frontend.Declaration Declaration where
    stripLocation (Frontend.Declaration d) = stripLocation (stripLocation d :: Frontend.Declaration')

instance StripLocation Frontend.Declaration' Declaration where
    stripLocation (Frontend.Declaration' m n b) = Declaration (stripLocation m) (stripLocation n :: Name) (stripLocation b)

instance StripLocation Frontend.DeclarationBody DeclarationBody where
    stripLocation (Frontend.DeclarationBody d) = stripLocation (stripLocation d :: Frontend.DeclarationBody')

instance StripLocation Frontend.DeclarationBody' DeclarationBody where
    stripLocation (Frontend.Value e p) = Value (stripLocation e) (stripLocation p)
    stripLocation (Frontend.ValueTypeDef t) = ValueTypeDef (stripLocation (stripLocation t :: Frontend.TypeAnnotation))
    stripLocation (Frontend.TypeAlias t) = TypeAlias (stripLocation (stripLocation t :: Frontend.Type))

instance StripLocation Frontend.TypeAnnotation TypeAnnotation where
    stripLocation (Frontend.TypeAnnotation n t) = TypeAnnotation (stripLocation n) (stripLocation t)
