{-# OPTIONS_GHC -fno-warn-warnings-deprecations #-}
{-# LANGUAGE FlexibleInstances #-}

module Compiler where

import Control.Applicative
import Control.Monad
import Control.Monad.Identity
import Control.Monad.IO.Class
import Control.Monad.Trans.Class
import Control.Monad.Trans.State
import Control.Monad.Trans.Reader
import Control.Monad.Trans.Writer
import Control.Monad.Trans.Error
import Data.List
import Data.Maybe
import qualified Data.Map as M

import AbsPyxell hiding (Type)
import Utils


-- | Type and name of an LLVM register.
type Result = (Type, String)

-- | State item (for storing different data).
data Item = Number Int | Label String

-- | Compiler monad: Reader for identifier environment, State to store some useful values, Writer to produce output LLVM code.
type Run r = ReaderT (M.Map String Result) (StateT (M.Map String Item) (WriterT String IO)) r


-- | Does nothing.
skip :: Run ()
skip = do
    return $ ()

-- | Outputs several lines of LLVM code.
write :: [String] -> Run ()
write lines = lift $ lift $ tell $ unlines lines

-- | Adds an indent to given lines.
indent :: [String] -> [String]
indent lines = map ('\t':) lines

-- | Gets an identifier from the environment.
getIdent :: Ident -> Run (Maybe Result)
getIdent ident = case ident of
    Ident x -> asks (M.lookup x)


-- | LLVM string representation for a given type.
strType :: Type -> String
strType typ = case typ of
    TInt _ -> "i32"
    TBool _ -> "i1"

-- | Returns an unused index for temporary names.
nextNumber :: Run Int
nextNumber = do
    Number n <- lift $ gets (M.! "number")
    lift $ modify (M.insert "number" (Number (n+1)))
    return $ n+1

-- | Returns an unused register name in the form: '%t\d'.
nextTemp :: Run String
nextTemp = do
    n <- nextNumber
    return $ "%t" ++ show n

-- | Returns an unused label name in the form: 'L\d'.
nextLabel :: Run String
nextLabel = do
    n <- nextNumber
    return $ "L" ++ show n

-- | Starts new LLVM label with a given name.
label :: String -> Run ()
label lbl = do
    write $ [ lbl ++ ":" ]
    lift $ modify (M.insert "label" (Label lbl))

-- | Returns name of the currently active label.
getLabel :: Run String
getLabel = do
    Label l <- lift $ gets (M.! "label")
    return $ l

-- | Outputs LLVM 'br' command with a single goal.
goto :: String -> Run ()
goto lbl = do
    write $ indent [ "br label %" ++ lbl ]

-- | Outputs LLVM 'br' command with two goals depending on a given value.
branch :: String -> String -> String -> Run ()
branch val lbl1 lbl2 = do
    write $ indent [ "br i1 " ++ val ++ ", label %" ++ lbl1 ++ ", label %" ++ lbl2 ]

-- | Outputs LLVM 'alloca' command.
alloca :: Type -> String -> Run ()
alloca typ loc = do
    write $ indent [ loc ++ " = alloca " ++ strType typ ]

-- | Outputs LLVM 'store' command.
store :: Type -> String -> String -> Run ()
store typ val loc = do
    write $ indent [ "store " ++ strType typ ++ " " ++ val ++ ", " ++ strType typ ++ "* " ++ loc ]

-- | Outputs LLVM 'load' command.
load :: Type -> String -> Run String
load typ loc = do
    v <- nextTemp
    write $ indent [ v ++ " = load " ++ strType typ ++ ", " ++ strType typ ++ "* " ++ loc ]
    return $ v

-- | Allocates a new identifier, outputs corresponding LLVM code, and runs continuation with changed environment.
declare :: Type -> Ident -> String -> String -> Run () -> Run ()
declare typ ident val loc cont = case ident of
    Ident x -> do
        alloca typ loc
        store typ val loc
        local (M.insert x (typ, loc)) cont

-- | Outputs LLVM binary operation instruction.
binop :: String -> Type -> String -> String -> Run String
binop op typ val1 val2 = do
    v <- nextTemp
    write $ indent [ v ++ " = " ++ op ++ " " ++ strType typ ++ " " ++ val1 ++ ", " ++ val2 ]
    return $ v


-- | Outputs LLVM code for all statements in the program.
compileProgram :: Program Pos -> Run ()
compileProgram prog = case prog of
    Program _ stmts -> do
        write $ [ "", "declare void @printInt(i32)" ]
        lift $ modify (M.insert "number" (Number 0))
        lift $ modify (M.insert "label" (Label "entry"))
        write $ [ "", "define i32 @main() {", "entry:" ]
        compileStmts stmts skip
        write $ indent [ "ret i32 0" ]
        write $ [ "}" ]

-- | Outputs LLVM code for a block of statements.
compileBlock :: Block Pos -> Run ()
compileBlock block = case block of
    SBlock _ stmts -> compileStmts stmts skip

-- | Outputs LLVM code for a bunch of statements and runs the continuation.
compileStmts :: [Stmt Pos] -> Run () -> Run ()
compileStmts stmts cont = case stmts of
    [] -> cont
    s:ss -> compileStmt s (compileStmts ss cont)

-- | Outputs LLVM code for a single statement and runs the continuation.
compileStmt :: Stmt Pos -> Run () -> Run ()
compileStmt stmt cont = case stmt of
    SSkip _ -> do
        cont
    SExpr _ expr -> do
        (t, v) <- compileExpr expr
        case t of
            TInt _ -> do
                write $ indent [ "call void @printInt(i32 " ++ v ++ ")" ]
        cont
    SAssg _ ident expr -> do
        (t, v) <- compileExpr expr
        r <- getIdent ident
        case r of
            Just (t, l) -> do
                store t v l
                cont
            Nothing -> do
                l <- nextTemp
                declare t ident v l cont
    SIf _ brs el -> do
        l <- nextLabel
        compileBranches brs l
        case el of
            EElse _ block -> do
                compileBlock block
            EEmpty _ -> do
                skip
        goto l >> label l
        cont
    SWhile _ expr block -> do
        l <- nextLabel
        goto l >> label l
        compileCond expr block l
        cont
    where
        compileBranches brs exit = case brs of
            [] -> skip
            b:bs -> case b of
                BElIf _ expr block -> do
                    compileCond expr block exit
                    compileBranches bs exit
        compileCond expr block exit = do
            (t, v) <- compileExpr expr
            l1 <- nextLabel
            l2 <- nextLabel
            branch v l1 l2
            label l1
            compileBlock block
            goto exit
            label l2


-- | Outputs LLVM code that evaluates a given expression. Returns type and name of the result.
compileExpr :: Expr Pos -> Run Result
compileExpr expr =
    case expr of
        EInt _ n -> return $ (tInt, show n)
        ETrue _ -> return $ (tBool, "true")
        EFalse _ -> return $ (tBool, "false")
        EVar _ ident -> compileRval expr
        EMul _ e1 e2 -> compileBinary "mul" e1 e2
        EDiv _ e1 e2 -> compileBinary "sdiv" e1 e2
        EMod _ e1 e2 -> compileBinary "srem" e1 e2
        EAdd _ e1 e2 -> compileBinary "add" e1 e2
        ESub _ e1 e2 -> compileBinary "sub" e1 e2
        ENeg _ e -> compileBinary "sub" (EInt Nothing 0) e
        ECmp _ e1 op e2 -> case op of
            CmpEQ _ -> compileCmp "eq" e1 e2
            CmpNE _ -> compileCmp "ne" e1 e2
            CmpLT _ -> compileCmp "slt" e1 e2
            CmpLE _ -> compileCmp "sle" e1 e2
            CmpGT _ -> compileCmp "sgt" e1 e2
            CmpGE _ -> compileCmp "sge" e1 e2
        ENot _ e -> compileBinary "xor" (ETrue Nothing) e
        EAnd _ e1 e2 -> do
            l1 <- nextLabel
            l2 <- nextLabel
            goto l1 >> label l1
            compileAnd e1 e2 [l1] l2
        EOr _ e1 e2 -> do
            l1 <- nextLabel
            l2 <- nextLabel
            goto l1 >> label l1
            compileOr e1 e2 [l1] l2
    where
        compileBinary op e1 e2 = do
            (t, v1) <- compileExpr e1
            (t, v2) <- compileExpr e2
            v <- binop op t v1 v2
            return $ (t, v)
        compileCmp op e1 e2 = do
            (t, v1) <- compileExpr e1
            (t, v2) <- compileExpr e2
            v <- binop ("icmp " ++ op) t v1 v2
            return $ (tBool, v)
        compileAnd expr1 expr2 preds exit = do
            (t, v1) <- compileExpr expr1
            l1 <- nextLabel
            branch v1 l1 exit
            label l1
            case expr2 of
                EAnd pos e1 e2 -> compileAnd e1 e2 (l1:preds) exit
                otherwise -> do
                    (t, v2) <- compileExpr expr2
                    l2 <- getLabel
                    goto exit >> label exit
                    v3 <- nextTemp
                    write $ indent $ [ v3 ++ " = phi i1 " ++ (intercalate ", " ["[false, %" ++ l ++ "]" | l <- preds]) ++ ", [" ++ v2 ++ ", %" ++ l2 ++ "]" ]
                    return $ (t, v3)
        compileOr expr1 expr2 preds exit = do
            (t, v1) <- compileExpr expr1
            l1 <- nextLabel
            branch v1 exit l1
            label l1
            case expr2 of
                EOr pos e1 e2 -> compileOr e1 e2 (l1:preds) exit
                otherwise -> do
                    (t, v2) <- compileExpr expr2
                    l2 <- getLabel
                    goto exit >> label exit
                    v3 <- nextTemp
                    write $ indent $ [ v3 ++ " = phi i1 " ++ (intercalate ", " ["[true, %" ++ l ++ "]" | l <- preds]) ++ ", [" ++ v2 ++ ", %" ++ l2 ++ "]" ]
                    return $ (t, v3)

-- | Outputs LLVM code that evaluates a given expression as an r-value. Returns type and name of the result.
compileRval :: Expr Pos -> Run Result
compileRval expr = do
    (t, l) <- compileLval expr
    v <- load t l
    return $ (t, v)

-- | Outputs LLVM code that evaluates a given expression as an l-value. Returns type and name of the result (location).
compileLval :: Expr Pos -> Run Result
compileLval expr = case expr of
    EVar _ ident -> do
        r <- getIdent ident
        return $ fromJust r
