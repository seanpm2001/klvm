(package klvm.bytecode [binary.bitwise-ior binary.bitwise-and
                        binary.arithmetic-shift | & >> << even? div
                        divisible-by?
                        context-backend defstruct
                        klvm.dbg]
  (define cut-package*
    "" W -> W
    (@s "." Cs) W -> (cut-package* Cs "")
    (@s C Cs) W -> (cut-package* Cs (@s W C)))

  (define cut-package
    S -> (intern (cut-package* (str S) "")))

  (define collect-enum-defs
    [] _ Acc -> (reverse Acc)
    [[C V] | Xs] Val Acc -> (collect-enum-defs Xs (+ V 1) [[C | V] | Acc])
    [C | Xs] Val Acc -> (collect-enum-defs Xs (+ Val 1) [[C | Val] | Acc]))

  (define mk-enum-values
    [] Acc -> (reverse Acc)
    [[N | V] | Defs] Acc -> (mk-enum-values Defs [[define N -> V] | Acc]))

  (define unwrap-list
    [] -> []
    [X | Xs] -> [cons X (unwrap-list Xs)])

  (define mk-enum-names
    Name List -> [define (concat Name (intern "-names"))
                   -> (unwrap-list List)])

  (define klvm.bytecode.def-enum-func
    Name Defs -> (let Items (collect-enum-defs Defs 0 [])
                      Names (mk-enum-names Name (map head Items))
                      Enums (mk-enum-values Items [Names])
                   [package null [] | Enums]))

  (define unwind-expr
    _ [X] -> (xbin-func X)
    Op [X Y] -> (Op (xbin-func X) (xbin-func Y))
    Op [X Y | Xs] -> (Op (Op (xbin-func X) (xbin-func Y))
                         (unwind-expr Op Xs)))

  (define xbin-func
    X -> X where (number? X)
    [| X | Xs] -> (unwind-expr (function binary.bitwise-ior) [X | Xs])
    [& X | Xs] -> (unwind-expr (function binary.bitwise-and) [X | Xs])
    [>> X Y] -> (binary.arithmetic-shift (xbin-func X) (- 0 (xbin-func Y)))
    [<< X Y] -> (binary.arithmetic-shift (xbin-func X) (xbin-func Y)))

  (define bin-func'
    0 R _ -> R
    X R L -> (bin-func' (div X 10) R (* L 2)) where (divisible-by? X 10) 
    X R L -> (bin-func' (div X 10) (+ R L) (* L 2)))

  (define bin-func
    X -> (bin-func' X 0 1))

  (define backend-fn
    Name F Args Carg -> (let Head [define F]
                             Args' (if (element? Carg Args)
                                       Args
                                       (append Args [Carg]))
                             N (concat Name (concat - (cut-package F)))
                             Code [[N [context-backend Carg]]
                                   | Args]
                          (append Head Args' [-> Code])))

  (define backend-def
    Name F Type Args Carg Acc -> (let X (backend-fn Name F Args Carg)
                                   [X | Acc]))

  (define backend-defs
    [] Name Acc -> Acc
    [[F Type Args Carg] | Ds] Name Acc ->
    (let X (backend-def Name F Type Args Carg Acc)
      (backend-defs Ds Name X)))

  (define backend-slot
    [Name Type | _] -> [Name Type])

  (define def-backend-fn
    Name Defs -> (let Slots (map (function backend-slot) Defs)
                      Code (backend-defs Defs Name [])
                      M (concat (intern "mk-") 
                                (concat Name (intern "-default")))
                      Margs (map (/. _ []) Defs)
                      Maker [define M -> [(concat mk- Name) | Margs]]
                      Code [Maker | Code]
                   [package null [] [defstruct Name | Slots] | Code]))

  (define set-backend-fn
    Backend Sym -> (let Name (make-string "klvm.bytecode.backend-~A->"
                                          (cut-package Sym))
                     [[function [intern Name]] Backend [function Sym]]))

  (define mk-backend-code
    Defs -> (let Mk [function [intern "klvm.bytecode.mk-backend-default"]]
              [let (protect Backend) [Mk]
                   -  [do | (map (set-backend-fn (protect Backend)) Defs)]
                (protect Backend)]))
                  
  (defmacro def-backend-macro
    [klvm.bytecode.def-backend Name | Defs] -> (def-backend-fn Name Defs))

  (defmacro mk-backend-macro
    [klvm.bytecode.mk-backend' | Defs] -> (mk-backend-code Defs))
    
  (define unwrap-package-null
    [] Acc -> (reverse Acc)
    [[package null _ | Code] | Xs] Acc -> (let Acc (append (reverse Code) Acc)
                                            (unwrap-package-null Xs Acc))
    [X | Xs] Acc -> (unwrap-package-null Xs [X | Acc]))

  (defmacro x.package-null
    [package Pkg Syms | X] -> [package Pkg Syms
                                       | (unwrap-package-null X [])])

  (defmacro def-enum-macro
    [klvm.bytecode.def-enum Name | Defs] -> (def-enum-func Name Defs))

  (defmacro xbin-macro
    [klvm.bytecode.xbin X] -> (xbin-func X)
    [klvm.bytecode.bin.xbin X] -> (xbin-func X)
    [klvm.bytecode.bin X] -> (bin-func X) where (number? X)))
