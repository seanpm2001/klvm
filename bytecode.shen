(package klvm.bytecode [denest.walk regkl.trap-error klvm.s1.walk

                        klvm.bytecode.walk

                        klvm.s1.const?

                        klvm.native klvm.reg klvm.reg-> klvm.call klvm.tailcall
                        klvm.tailif klvm.if klvm.return klvm.mk-closure
                        klvm.push-error-handler klvm.pop-error-handler
                        klvm.lambda]

(defstruct context
  (func symbol)
  (type symbol)
  (frame-size number)
  (frame-size-extra number)
  (nargs number)
  (toplevel (list A))
  (jumps table)
  (backend backend))

(defstruct backend
  (native (A --> klvm.context --> A))
  (mk-code (--> A))
  (code-len (A --> number))
  (code-append! (A --> A --> A))
  (prep-code (A --> A))
  (const (A --> context --> A))
  (loadreg (number --> number --> context --> A --> A))
  (loadfn (number --> symbol --> context --> A --> A))
  (loadconst (number --> B --> context --> A --> A))
  (jump (number --> context --> A --> A))
  (closure-> (unit --> number --> context --> A --> A))
  (closure-tail-> (unit --> number --> context --> A --> A))
  (funcall (A --> context --> A --> A))
  (tailcall (context --> A --> A))
  (if-reg-expr (number --> number --> context --> A --> A))
  (retreg (number --> context --> A --> A))
  (retfn (B --> context --> A --> A))
  (retconst (B --> context --> A --> A))
  (push-error-handler (unit --> context --> A --> A))
  (pop-error-handler (context --> A --> A))
  (emit-func (symbol --> symbol --> (list symbol) --> number --> number
              --> context --> A --> A)))

(klvm.bytecode.def-backend-fn mk-code () C)
(klvm.bytecode.def-backend-fn code-len (X) C)
(klvm.bytecode.def-backend-fn code-append! (X Y) C)
(klvm.bytecode.def-backend-fn prep-code (X) C)
(klvm.bytecode.def-backend-fn const (X C) C)

(klvm.bytecode.def-backend-fn loadreg (To From C Acc) C)
(klvm.bytecode.def-backend-fn loadfn (To From C Acc) C)
(klvm.bytecode.def-backend-fn loadconst (To X C Acc) C)
(klvm.bytecode.def-backend-fn jump (Where C Acc) C)
(klvm.bytecode.def-backend-fn closure-> (X Nargs C Acc) C)
(klvm.bytecode.def-backend-fn closure-tail-> (X Nargs C Acc) C)
(klvm.bytecode.def-backend-fn funcall (X C Acc) C)
(klvm.bytecode.def-backend-fn tailcall (C Acc) C)
(klvm.bytecode.def-backend-fn if-reg-expr (Reg Else C Acc) C)
(klvm.bytecode.def-backend-fn retreg (X C Acc) C)
(klvm.bytecode.def-backend-fn retfn (X C Acc) C)
(klvm.bytecode.def-backend-fn retconst (X C Acc) C)
(klvm.bytecode.def-backend-fn push-error-handler (X C Acc) C)
(klvm.bytecode.def-backend-fn pop-error-handler (C Acc) C)

(klvm.bytecode.def-backend-fn emit-func
                              (Type Name Args Frame-size Frame-size-extra Code
                               C Acc)
                              C)

(define reg->
  To [klvm.reg From] C Acc -> (loadreg To From C Acc)
  To [klvm.lambda From] C Acc -> (loadfn To From C Acc)
  To X C Acc -> (loadconst To X C Acc) where (klvm.s1.const? X))

(define prepare-args
  [] _ _ Acc -> Acc
  [[I | X] | Xs] C Off Acc -> (let Acc (reg-> (+ I Off) X C Acc)
                                (prepare-args Xs C Off Acc)))

(define walk-call
  F Nargs Ret-reg X C Acc -> (let Acc (closure-> F Nargs C Acc)
                                  Off (context-frame-size C)
                                  Acc (prepare-args X C Off Acc)
                               (funcall Ret-reg C Acc)))

(define walk-tailcall
  F Nargs X C Acc -> (let Acc (closure-tail-> F Nargs C Acc)
                          Acc (prepare-args X C 0 Acc)
                       (tailcall C Acc)))

(define walk-return
  [klvm.reg Reg] C Acc -> (retreg Reg C Acc)
  [klvm.lambda X] C Acc -> (retfn X C Acc)
  X C Acc -> (retconst X C Acc) where (klvm.s1.const? X))

(define if-jump
  Where true C Acc -> Acc
  Where false C Acc -> (jump Where C Acc))

(define then-code-len
  Code true C -> (code-len Code C)
  Code false C -> (+ (code-len Code C) 1))

(define walk-if
  [klvm.reg R] Then Else Tail? C Acc ->
  (let Then-code (walk-x1 Then C (mk-code C))
       Else-code (walk-x1 Else C (mk-code C))
       Then-code-len (then-code-len Then-code Tail? C)
       Acc (if-reg-expr R Then-code-len C Acc)
       Acc (code-append! Acc Then-code C)
       Acc (if-jump (code-len Else-code C) Tail? C Acc)
     (code-append! Acc Else-code C)))

(define walk-do
  [X] C Acc -> (walk-x1 X C Acc)
  [X | Xs] C Acc -> (walk-do Xs C (walk-x1 X C Acc)))

(define walk-x1
  [do | X] C Acc -> (walk-do X C Acc)
  [klvm.tailif If Then Else] C Acc -> (walk-if If Then Else true C Acc)
  [klvm.if If Then Else] C Acc -> (walk-if If Then Else false C Acc)
  [klvm.call F Nargs Ret-reg X] C Acc -> (walk-call F Nargs Ret-reg X C Acc)
  [klvm.tailcall F Nargs X] C Acc -> (walk-tailcall F Nargs X C Acc)
  [klvm.reg-> R X] C Acc -> (reg-> R X C Acc)
  [klvm.return X] C Acc -> (walk-return X C Acc)
  [klvm.push-error-handler E] C Acc -> (push-error-handler E C Acc)
  [klvm.pop-error-handler] C Acc -> (pop-error-handler C Acc)
  X _ _ -> (error "Unexpected L1 expression: ~S~%" X))

(define walk-toplevel-expr
  [Type Name Args Frame-size Frame-size-extra Code] S+ B Acc ->
  (let Arity (length Args)
       Frame-size' (+ Frame-size S+)
       C (mk-context Name Type Frame-size' Frame-size-extra Arity Acc [] B)
       X (walk-x1 Code C (mk-code C))
       Acc' (context-toplevel C)
    (emit-func Type Name Args Frame-size' Frame-size-extra X C Acc')))

(define walk-toplevel
  [] S B Acc -> ((backend-prep-code B) Acc)
  [X | Xs] S B Acc -> (walk-toplevel Xs S B (walk-toplevel-expr X S B Acc)))

(define walk
  X S+ B -> (let Code ((backend-mk-code B))
              (walk-toplevel (klvm.s1.walk (backend-native B) X) S+ B Code)))

)
