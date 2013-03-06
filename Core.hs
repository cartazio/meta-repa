{-# LANGUAGE GADTs #-}
module Core where

import FOAS (reducel3,reducel4,isAtomic)
import qualified FOAS as FO
import qualified HOAS as HO
import qualified FOASCommon as FO
import Types


translateType :: HO.Type a -> Type
translateType (HO.TConst tc) = TConst (translateTConst tc)
translateType (HO.TFun  t1 t2) = TFun  (translateType t1) (translateType t2)
translateType (HO.TTup2 t1 t2) = TTup2 (translateType t1) (translateType t2)
translateType (HO.TTupN ts) = TTupN (HO.tupMap translateType ts)
translateType (HO.TMArr t) = TMArr (translateType t)
translateType (HO.TIArr t) = TIArr (translateType t)
translateType (HO.TIO   t) = TIO   (translateType t)

translateTConst :: HO.TypeConst a -> TypeConst
translateTConst HO.TInt = TInt 
translateTConst HO.TFloat = TFloat 
translateTConst HO.TDouble = TDouble 
translateTConst HO.TBool = TBool 

toFOAS :: HO.Expr a -> FO.Expr
toFOAS (HO.Var v) = FO.Var v

toFOAS (HO.Binop op a b) =
  case op of
    HO.Plus  -> FO.BinOp FO.Plus  (toFOAS a) (toFOAS b)
    HO.Minus -> FO.BinOp FO.Minus (toFOAS a) (toFOAS b)
    HO.Mult  -> FO.BinOp FO.Mult  (toFOAS a) (toFOAS b)
    HO.Quot  -> FO.BinOp FO.Quot  (toFOAS a) (toFOAS b)
    HO.Rem   -> FO.BinOp FO.Rem   (toFOAS a) (toFOAS b)
    HO.Div   -> FO.BinOp FO.Div  (toFOAS a) (toFOAS b)
    HO.Mod   -> FO.BinOp FO.Mod   (toFOAS a) (toFOAS b)
    HO.FDiv  -> FO.BinOp FO.FDiv  (toFOAS a) (toFOAS b)
    HO.And   -> FO.BinOp FO.And  (toFOAS a) (toFOAS b)
    HO.Or    -> FO.BinOp FO.Or   (toFOAS a) (toFOAS b)
    HO.Min   -> FO.BinOp FO.Min  (toFOAS a) (toFOAS b)
    HO.Max   -> FO.BinOp FO.Max  (toFOAS a) (toFOAS b)
toFOAS (HO.Abs a)    = FO.UnOp FO.Abs    (toFOAS a)
toFOAS (HO.Signum a) = FO.UnOp FO.Signum (toFOAS a)
toFOAS (HO.Recip a)  = FO.UnOp FO.Recip  (toFOAS a)
toFOAS (HO.FromInteger  t i) = FO.FromInteger (translateTConst t) i
toFOAS (HO.FromRational t r) = FO.FromRational (translateTConst t) r
toFOAS (HO.FromIntegral t a) = FO.FromIntegral (translateType t) (toFOAS a)

toFOAS (HO.Equal    a b) = FO.Compare FO.EQU (toFOAS a) (toFOAS b)
toFOAS (HO.NotEqual a b) = FO.Compare FO.NEQ (toFOAS a) (toFOAS b)
toFOAS (HO.GTH      a b) = FO.Compare FO.GTH (toFOAS a) (toFOAS b)
toFOAS (HO.LTH      a b) = FO.Compare FO.LTH (toFOAS a) (toFOAS b)
toFOAS (HO.GTE      a b) = FO.Compare FO.GEQ (toFOAS a) (toFOAS b)
toFOAS (HO.LTE      a b) = FO.Compare FO.LEQ (toFOAS a) (toFOAS b)

toFOAS (HO.Tup2 a b) = FO.Tup2 (toFOAS a) (toFOAS b)
toFOAS (HO.Fst a) = FO.Fst (toFOAS a)
toFOAS (HO.Snd a) = FO.Snd (toFOAS a)

toFOAS (HO.TupN t) = FO.TupN (HO.tupMap toFOAS t)
toFOAS (HO.GetN l n a) = FO.GetN l (HO.natToInt n) (toFOAS a)

toFOAS (HO.Let a f) = FO.Let v (toFOAS a) e
  where e = toFOAS $ f (HO.Var v)
        v = getVar e

toFOAS (HO.Return a) = FO.Return (toFOAS a)
toFOAS (HO.Bind a f) = FO.Bind (toFOAS a) (toFOASFun f)

toFOAS (HO.IterateWhile cond step init) =
  FO.IterateWhile
    (toFOASFun cond)
    (toFOASFun step)
    (toFOAS init)
toFOAS (HO.WhileM cond step action init) =
  FO.WhileM
    (toFOASFun cond)
    (toFOASFun step)
    (toFOASFun action)
    (toFOAS init)

toFOAS (HO.RunMutableArray a) = FO.RunMutableArray (toFOAS a)
toFOAS (HO.ReadIArray a b) = FO.ReadIArray (toFOAS a) (toFOAS b)
toFOAS (HO.ArrayLength a) = FO.ArrayLength (toFOAS a)

toFOAS (HO.NewArray a) = FO.NewArray (toFOAS a)
toFOAS (HO.ReadArray a b) = FO.ReadArray  (toFOAS a) (toFOAS b)
toFOAS (HO.WriteArray a b c) = FO.WriteArray (toFOAS a) (toFOAS b) (toFOAS c)

toFOAS (HO.ParM n f) = FO.ParM (toFOAS n) (toFOASFun f)
toFOAS (HO.Skip) = FO.Skip
toFOAS (HO.Print a) = FO.Print (toFOAS a)

toFOASFun :: (HO.Expr a -> HO.Expr b) -> FO.Expr
toFOASFun f = FO.Lambda v e
  where e = toFOAS $ f (HO.Var v)
        v = getVar e


getVar :: FO.Expr -> Int
getVar = FO.exprFold getVar' max max3 max4

getVar' :: (FO.Expr -> Int) -> FO.Expr -> Int
getVar' f (FO.Lambda i _) = i+1
getVar' f (FO.Let i _ _) = i+1
getVar' f e | isAtomic e = 0
            | otherwise  = f e

max3 :: Ord a => a -> a -> a -> a
max3 = reducel3 max

max4 :: Ord a => a -> a -> a -> a -> a
max4 = reducel4 max

