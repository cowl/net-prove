module LG.Term where

import LG.Base

data Term = V ValueTerm | E ContextTerm | C CommandTerm deriving (Eq, Show)

data NodeTerm = Va ValueTerm' | Ev ContextTerm' deriving (Eq, Show)

data ValueTerm'   = Variable Name
                  | ValueTerm   :<×> ValueTerm
                  | ContextTerm :<\> ValueTerm
                  | ValueTerm   :</> ContextTerm
                  deriving (Eq, Show)

data ValueTerm    = V' ValueTerm'
                  | Mu Name CommandTerm
                  deriving (Eq, Show)

data ContextTerm' = Covariable Name
                  | ValueTerm    :\  ContextTerm
                  | ContextTerm  :/  ValueTerm
                  | ContextTerm :<+> ContextTerm
                  deriving (Eq, Show)

data ContextTerm  = E' ContextTerm'
                  | Comu Name CommandTerm
                  deriving (Eq, Show)

data CommandTerm  = Cut Name Name Name CommandTerm  -- (first second) / third
                  | ValueTerm' :⌈ Name              -- Command right
                  | Name       :⌉ ContextTerm'      -- Command left
                  deriving (Eq, Show)

fromNodeTerm :: NodeTerm -> Term
fromNodeTerm (Va t) = V (V' t)
fromNodeTerm (Ev t) = E (E' t)

class Wrappable a where
    wrap :: a -> Term
    unwrap :: Term -> a  -- take off one layer of value constructor

instance Wrappable ValueTerm where
    wrap t = V t
    unwrap (V t) = t

instance Wrappable ContextTerm where
    wrap t = E t
    unwrap (E t) = t

instance Wrappable CommandTerm where
    wrap t = C t
    unwrap (C t) = t

class Substitutable a where
    substitute :: ValidSubstitution b => b -> b -> a -> a
    --substitute x for y in z

class ValidSubstitution a where
    asValue    :: a -> Maybe ValueTerm
    asContext  :: a -> Maybe ContextTerm
    asValue   _ = Nothing
    asContext _ = Nothing
    asSubstitution :: (Wrappable a) => NodeTerm -> a
    asSubstitution = unwrap . fromNodeTerm

instance ValidSubstitution ValueTerm where
    asValue x = Just x

instance ValidSubstitution ContextTerm where
    asContext x = Just x

instance Substitutable ValueTerm where
    -- the following matcher enables substitution of a mu binding
    -- for a variable
    substitute x y z@(V' (Variable s)) = case (asValue x, asValue y) of
        (Just x', Just (V' (Variable t))) -> if s == t then x' else z
        _ -> z
    substitute x y (Mu s z)            = Mu s $ substitute x y z
    substitute x y (V' z)              = V'   $ substitute x y z

instance Substitutable ValueTerm' where
    substitute x y (v :<×> w)     = substitute x y v :<×> substitute x y w
    substitute x y (v :<\> w)     = substitute x y v :<\> substitute x y w
    substitute x y (v :</> w)     = substitute x y v :</> substitute x y w
    -- given instance Substitutable ValueTerm, the following matcher
    -- can only apply directly after recursion into (z' :⌈ s')
    substitute x y z@(Variable s) = case (asValue x, asValue y) of
        (Just (V' x'), Just (V' (Variable t))) -> if s == t then x' else z
        _ -> z

instance Substitutable ContextTerm where
    substitute x y z@(E' (Covariable s)) = case (asContext x, asContext y) of
        (Just x', Just (E' (Covariable t))) -> if s == t then x' else z
        _ -> z
    substitute x y (E' z)                = E'     $ substitute x y z
    substitute x y (Comu s z)            = Comu s $ substitute x y z

-- notes for instances ValueTerm, ValueTerm' also apply here
instance Substitutable ContextTerm' where
    substitute x y (v  :\  w)       = substitute x y v  :\  substitute x y w
    substitute x y (v  :/  w)       = substitute x y v  :/  substitute x y w
    substitute x y (v :<+> w)       = substitute x y v :<+> substitute x y w
    substitute x y z@(Covariable s) = case (asContext x, asContext y) of
        (Just (E' x'), Just (E' (Covariable t))) -> if s == t then x' else z
        _ -> z

instance Substitutable CommandTerm where
    substitute x y (Cut s t u z) = Cut s t u $ substitute x y z
    substitute x y (z :⌈ s)      = substitute x y z :⌈ s
    substitute x y (s :⌉ z)      = s :⌉ substitute x y z

isSubtermOf :: Term -> Term -> Bool
t1 `isSubtermOf` t2 = t1 == t2 || case t2 of
    (V (V' (Variable _))) -> False
    (V (V' (t2' :<×> t2''))) -> t1 `isSubtermOf` (V t2') || t1 `isSubtermOf` (V t2'')
    (V (V' (t2' :<\> t2''))) -> t1 `isSubtermOf` (E t2') || t1 `isSubtermOf` (V t2'')
    (V (V' (t2' :</> t2''))) -> t1 `isSubtermOf` (V t2') || t1 `isSubtermOf` (E t2'')
    (V (Mu _ t2')) -> t1 `isSubtermOf` (C t2')
    (E (E' (Covariable _))) -> False
    (E (E' (t2'  :\  t2''))) -> t1 `isSubtermOf` (V t2') || t1 `isSubtermOf` (E t2'')
    (E (E' (t2'  :/  t2''))) -> t1 `isSubtermOf` (E t2') || t1 `isSubtermOf` (V t2'')
    (E (E' (t2' :<+> t2''))) -> t1 `isSubtermOf` (E t2') || t1 `isSubtermOf` (E t2'')
    (E (Comu _ t2')) -> t1 `isSubtermOf` (C t2')
    (C (t2' :⌈ _  )) -> t1 `isSubtermOf` (V (V' t2'))
    (C (_   :⌉ t2')) -> t1 `isSubtermOf` (E (E' t2'))
    (C (Cut _ _ _ t2')) -> t1 `isSubtermOf` (C t2')
