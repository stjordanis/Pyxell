module SkelPyxell where

-- Haskell module generated by the BNF converter

import AbsPyxell
import ErrM
type Result = Err String

failure :: Show a => a -> Result
failure x = Bad $ "Undefined case: " ++ show x

transIdent :: Ident -> Result
transIdent x = case x of
  Ident string -> failure x
transProgram :: Show a => Program a -> Result
transProgram x = case x of
  Program _ stmts -> failure x
transStmt :: Show a => Stmt a -> Result
transStmt x = case x of
  SFunc _ ident fargs fret fbody -> failure x
  SRetVoid _ -> failure x
  SRetExpr _ expr -> failure x
  SSkip _ -> failure x
  SPrint _ expr -> failure x
  SPrintEmpty _ -> failure x
  SAssg _ exprs -> failure x
  SAssgMul _ expr1 expr2 -> failure x
  SAssgDiv _ expr1 expr2 -> failure x
  SAssgMod _ expr1 expr2 -> failure x
  SAssgAdd _ expr1 expr2 -> failure x
  SAssgSub _ expr1 expr2 -> failure x
  SAssgBShl _ expr1 expr2 -> failure x
  SAssgBShr _ expr1 expr2 -> failure x
  SAssgBAnd _ expr1 expr2 -> failure x
  SAssgBOr _ expr1 expr2 -> failure x
  SAssgBXor _ expr1 expr2 -> failure x
  SIf _ branchs else_ -> failure x
  SWhile _ expr block -> failure x
  SUntil _ expr block -> failure x
  SFor _ expr1 expr2 block -> failure x
  SForStep _ expr1 expr2 expr3 block -> failure x
  SContinue _ -> failure x
  SBreak _ -> failure x
transFArg :: Show a => FArg a -> Result
transFArg x = case x of
  ANoDefault _ type_ ident -> failure x
  ADefault _ type_ ident expr -> failure x
transFRet :: Show a => FRet a -> Result
transFRet x = case x of
  FProc _ -> failure x
  FFunc _ type_ -> failure x
transFBody :: Show a => FBody a -> Result
transFBody x = case x of
  FDef _ block -> failure x
  FExtern _ -> failure x
transBlock :: Show a => Block a -> Result
transBlock x = case x of
  SBlock _ stmts -> failure x
transBranch :: Show a => Branch a -> Result
transBranch x = case x of
  BElIf _ expr block -> failure x
transElse :: Show a => Else a -> Result
transElse x = case x of
  EElse _ block -> failure x
  EEmpty _ -> failure x
transArgC :: Show a => ArgC a -> Result
transArgC x = case x of
  APos _ expr -> failure x
  ANamed _ ident expr -> failure x
transCmp :: Show a => Cmp a -> Result
transCmp x = case x of
  Cmp1 _ expr1 cmpop expr2 -> failure x
  Cmp2 _ expr cmpop cmp -> failure x
transCmpOp :: Show a => CmpOp a -> Result
transCmpOp x = case x of
  CmpEQ _ -> failure x
  CmpNE _ -> failure x
  CmpLT _ -> failure x
  CmpLE _ -> failure x
  CmpGT _ -> failure x
  CmpGE _ -> failure x
transExpr :: Show a => Expr a -> Result
transExpr x = case x of
  EStub _ -> failure x
  EInt _ integer -> failure x
  EFloat _ double -> failure x
  ETrue _ -> failure x
  EFalse _ -> failure x
  EChar _ char -> failure x
  EString _ string -> failure x
  EArray _ exprs -> failure x
  EVar _ ident -> failure x
  EIndex _ expr1 expr2 -> failure x
  EAttr _ expr ident -> failure x
  ECall _ expr argcs -> failure x
  EPow _ expr1 expr2 -> failure x
  EMinus _ expr -> failure x
  EPlus _ expr -> failure x
  EBNot _ expr -> failure x
  EMul _ expr1 expr2 -> failure x
  EDiv _ expr1 expr2 -> failure x
  EMod _ expr1 expr2 -> failure x
  EAdd _ expr1 expr2 -> failure x
  ESub _ expr1 expr2 -> failure x
  EBShl _ expr1 expr2 -> failure x
  EBShr _ expr1 expr2 -> failure x
  EBAnd _ expr1 expr2 -> failure x
  EBOr _ expr1 expr2 -> failure x
  EBXor _ expr1 expr2 -> failure x
  ERangeIncl _ expr1 expr2 -> failure x
  ERangeExcl _ expr1 expr2 -> failure x
  ERangeInf _ expr -> failure x
  ECmp _ cmp -> failure x
  ENot _ expr -> failure x
  EAnd _ expr1 expr2 -> failure x
  EOr _ expr1 expr2 -> failure x
  ETuple _ exprs -> failure x
  ECond _ expr1 expr2 expr3 -> failure x
  ELambda _ idents expr -> failure x
transType :: Show a => Type a -> Result
transType x = case x of
  TPtr _ type_ -> failure x
  TArr _ integer type_ -> failure x
  TDeref _ type_ -> failure x
  TVoid _ -> failure x
  TInt _ -> failure x
  TFloat _ -> failure x
  TBool _ -> failure x
  TChar _ -> failure x
  TObject _ -> failure x
  TString _ -> failure x
  TArray _ type_ -> failure x
  TTuple _ types -> failure x
  TFunc _ types type_ -> failure x
  TFuncDef _ ident fargs type_ block -> failure x
  TFuncExt _ ident fargs type_ -> failure x

