(package klvm.s2 [denest.walk
                  
                  regkl.trap-error klvm.s2-from-kl
                  
                  klvm.call klvm.closure klvm.closure-> klvm.closure-nargs
                  klvm.entry klvm.func klvm.func-obj klvm.goto klvm.goto-next
                  klvm.if klvm.if-nargs>0 klvm.labels klvm.nargs klvm.nargs-
                  klvm.nargs-> klvm.nargs-cond klvm.next klvm.next->
                  klvm.nregs-> klvm.pop-error-handler klvm.push-error-handler
                  klvm.put-closure-args klvm.reg klvm.reg-> klvm.ret
                  klvm.ret-> klvm.return klvm.runtime klvm.sp+ klvm.sp-
                  klvm.tailcall klvm.tailif klvm.thaw klvm.toplevel
                  klvm.wipe-stack

                  klvm.entry-template klvm.return-template

                  klvm.s1.func klvm.s1.closure klvm.s1.toplevel klvm.s1.return
                  klvm.s1.walk]

(defstruct context
  (func-name symbol)
  (stack-size number)
  (stack-size-extra number)
  (nargs number)
  (label number)
  (func s-expr)
  (toplevel s-expr))

(set inline-func-entry false)
(set inline-func-return false)
(define next-reg C -> (- (context-stack-size C) 1))
(define nargs-reg C -> (- (context-stack-size C) 2))

(define prepend
  X Acc -> (append (reverse X) Acc))

(define next-label
  C -> (do (context-label-> C (+ (context-label C) 1))
           (context-label C)))

(define close-label
  C [] -> []
  C Acc -> (do (context-func-> C [(reverse Acc) | (context-func C)])
               []))

(define label
  N C Acc -> (do (close-label C Acc)
                 [N]))

(define klvm.entry-template
  Name Nargs -> [klvm.nargs-cond
                 Nargs
                 [[klvm.nregs-> [1]]
                  [klvm.ret-> [klvm.func-obj Name Nargs]]
                  [klvm.wipe-stack]
                  [klvm.goto-next]]
                 [[klvm.nargs- Nargs]]
                 [[klvm.sp+ [klvm.nargs]]
                  [klvm.sp- Nargs]
                  [klvm.nargs- Nargs]]])

(define klvm.return-template
  X Next -> [klvm.if-nargs>0
             [[klvm.closure-> X]
              [klvm.nregs-> [[klvm.nargs] [klvm.closure-nargs]]]
              [klvm.next-> Next]
              [klvm.wipe-stack]
              [klvm.put-closure-args 0]
              [klvm.sp- [klvm.nargs]]
              [klvm.call]]
             [[klvm.ret-> X]
              [klvm.next-> Next]
              [klvm.wipe-stack]
              [klvm.goto-next]]])

(define call-template
  Nargs S+ -> [[klvm.sp+ S+]
               [klvm.nargs-> Nargs]
               [klvm.put-closure-args Nargs]
               [klvm.call]])

(define tailcall-template
  Nargs -> [[klvm.nargs-> Nargs]
            [klvm.put-closure-args Nargs]
            [klvm.call]])

(define entry-op
  Name Nargs -> (klvm.entry-template Name Nargs)
                where (value inline-func-entry)
  Name Nargs -> [klvm.entry Name Nargs])

(define return-op
  X Next -> (klvm.return-template X Next) where (value inline-func-return)
  X Next -> [klvm.return X Next])

(define call-ret
  [] Acc -> Acc
  Ret-reg Acc -> [[klvm.reg-> Ret-reg [klvm.ret]] | Acc])

(define prepare-args
  [] _ Acc -> Acc
  Args C Acc -> (walk-x1 Args C Acc))

(define walk-call
  F Nargs Ret-reg Prep C Acc -> (let S (context-stack-size C)
                                     Next (next-label C)
                                     X [[klvm.next-> Next] | Acc]
                                     X [[klvm.closure-> F] | X]
                                     X (prepare-args Prep C X)
                                     X (prepend (call-template Nargs S) X)
                                     X (label Next C X)
                                     X [[klvm.wipe-stack] | X]
                                     X [[klvm.sp- S] | X]
                                     X (call-ret Ret-reg X)
                                  X))

(define walk-tailcall
  F Nargs Prep C Acc -> (let Acc [[klvm.next-> [klvm.reg (next-reg C)]] | Acc]
                             Acc [[klvm.closure-> F] | Acc]
                             Acc (prepare-args Prep C Acc)
                          (prepend (tailcall-template Nargs) Acc)))

(define walk-if-expr
  X X-label _ true C Acc -> (let L (label X-label C Acc)
                              (walk-x1 X C L))
  X X-label After-label false C Acc -> (let L (label X-label C Acc)
                                            Acc (walk-x1 X C L)
                                         [[klvm.goto After-label] | Acc]))

(define walk-if
  [klvm.reg R] Then Else Tail? C Acc -> 
  (let After-label (next-label C)
       Then-label (next-label C)
       Else-label (next-label C)
       X [klvm.if [klvm.reg R] [klvm.goto Then-label] [klvm.goto Else-label]]
       Acc [X | Acc]
       Acc (walk-if-expr Then Then-label After-label Tail? C Acc)
       Acc (walk-if-expr Else Else-label After-label Tail? C Acc)
    (if Tail?
        Acc
        (label After-label C Acc))))

(define walk-do
  [X] C Acc -> (walk-x1 X C Acc)
  [X | Xs] C Acc -> (walk-do Xs C (walk-x1 X C Acc)))

(define walk-x1
  [do | Xs] C Acc -> (walk-do Xs C Acc)
  [klvm.tailif If Then Else] C Acc -> (walk-if If Then Else true C Acc)
  [klvm.if If Then Else] C Acc -> (walk-if If Then Else false C Acc)
  [klvm.call F Nargs Ret-reg X] C Acc -> (walk-call F Nargs Ret-reg X C Acc)
  [klvm.tailcall F Nargs X] C Acc -> (walk-tailcall F Nargs X C Acc)
  [klvm.reg-> R X] C Acc -> [[klvm.reg-> R X] | Acc]
  [klvm.return X Next] C Acc -> (let R (nargs-reg C)
                                     Acc' [[klvm.nargs-> [klvm.reg R]] | Acc]
                                  [(return-op X Next) | Acc'])
  [klvm.push-error-handler E] C Acc -> [[klvm.push-error-handler E] | Acc]
  [klvm.pop-error-handler] C Acc -> [[klvm.pop-error-handler] | Acc])

(define func-hdr
  klvm.s1.func -> klvm.func
  klvm.s1.toplevel -> klvm.toplevel
  klvm.s1.closure -> klvm.closure)

(define func-entry
  C -> (prepend [(entry-op (context-func-name C) (context-nargs C))
                 [klvm.nregs-> [(+ (context-stack-size C)
                                   (context-stack-size-extra C))]]
                 [klvm.reg-> (nargs-reg C) [klvm.nargs]]
                 [klvm.reg-> (next-reg C) [klvm.next]]]
                (label (next-label C) C [])))

(define walk-toplevel-expr
  [Type Name Args Stack-size Stack-size-extra Code] Acc ->
  (let Nargs (length Args)
       C (mk-context Name Stack-size Stack-size-extra Nargs -1 [] Acc)
       X (func-entry C)
       X (walk-x1 Code C X)
       X (close-label C X)
       Acc' (context-toplevel C)
       Hdr (func-hdr Type)
       Labels [klvm.labels | (reverse (context-func C))]
    [[Hdr Name Args Stack-size Labels] | Acc'])
  where (element? Type [klvm.s1.func klvm.s1.closure klvm.s1.toplevel]))

(define walk-toplevel
  [] Acc -> (reverse Acc)
  [X | Y] Acc -> (walk-toplevel Y (walk-toplevel-expr X Acc)))

(define walk
  X -> (walk-toplevel X []))

(define klvm.runtime
  -> (let X (intern "X")
          E (intern "E")
          R (intern "R")
      [[defun regkl.trap-error [X E]
         [do [klvm.push-error-handler E]
             [let R [X]
               [do [klvm.pop-error-handler]
                   R]]]]]))

(define klvm.s2-from-kl
  Fn Kl -> (walk (klvm.s1.walk Fn Kl)))

)
