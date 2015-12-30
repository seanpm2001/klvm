(package klvm.test.x [klvm.test.str-join klvm.test.list-from-vec
                      klvm.test.str-from-sexpr 
                      
                      klvm.s1.translate
                      klvm.s2.translate
                      klvm.bytecode.asm.from-kl 
                      klvm.bytecode.bin.from-kl 
                      klvm.bytecode.asm.print
                      klvm.func klvm.closure klvm.toplevel
                      binary.bytevector-to-file]

  (define write
    (@p Code Test) Prefix -> 
    (let Defs (cn Prefix ".test")
         S1 (cn Prefix ".klvm1")
         S2 (cn Prefix ".klvm2")
         Sa (cn Prefix ".klvma")
         Sb (cn Prefix ".klvmb")
         . (write-to-file Defs (defs Test []))
         . (write-to-file S1 (s1 Code))
         . (write-to-file S2 (s2 Code))
         . (write-asm Code Sa)
         . (write-bytecode Code Sb)
      [Defs S1 S2 Sa Sb]))

  (define call-with-file-output
    File Fn -> (let F (open File out)
                 (trap-error (do (Fn F)
                                 (close F))
                             (/. E (do (close F)
                                       (error (error-to-string E)))))))

  (define s1
    Code -> (let S1 (klvm.s1.translate [] Code true)
              (klvm.test.str-from-sexpr "~R~%" S1)))

  (define s2
    Code -> (let S1 (klvm.s1.translate [] Code true)
                 S2 (klvm.s2.translate S1)
               (str-s2 S2)))

  (define write-asm
    Code File -> (let B (klvm.bytecode.asm.from-kl Code 2)
                   (call-with-file-output
                    File
                    (/. F (klvm.bytecode.asm.print B F)))))

  (define write-bytecode
    Code File -> (let B (klvm.bytecode.bin.from-kl Code 2)
                      . (output "~S: ~S~%" write-bytecode B)
                   (binary.bytevector-to-file File B)))

  (define fmt-vec
    V -> (let L (map (function fmt) (klvm.test.list-from-vec V))
           (make-string "#(~A)" (klvm.test.str-join L " "))))

  (define fmt-list
    List -> (let L (map (function fmt) List)
              (make-string "(~A)" (klvm.test.str-join L " "))))

  (define fmt
    true -> "#t"
    false -> "#f"
    [] -> "()"
    [X | Xs] -> (fmt-list [X | Xs]) 
    X -> (fmt-vec X) where (vector? X)
    X -> (str X))

  (define fmt-def
    X R -> (make-string "~A => ~A" (fmt X) (fmt R)))

  (define defs
    [] Acc -> (let S (klvm.test.str-join (reverse Acc) "c#10; ")
                (make-string "(~A)~%" S))
    [(@p X R) | Ds] Acc -> (defs Ds [(fmt-def X R) | Acc]))

  (define pp-code
    [] S Sep -> S
    [X | Y] S Sep -> (let S (make-string "~A~A~R" S Sep X)
                       (pp-code Y S (make-string "~%    "))))

  (define pp-label
    [N | Code] S Sep -> (let S (make-string "~A~A(~A~%" S Sep N)
                             S (pp-code Code S "    ")
                          (cn S ")")))

  (define pp-labels'
    [[N | X]] S Sep -> (pp-label [N | X] S Sep)
    [[N | X] | Labels] S Sep -> (let Sep' (make-string "~%   ")
                                     S (pp-label [N | X] S Sep)
                                  (pp-labels' Labels S Sep')))

  (define pp-labels
    X S -> (cn (pp-labels' X S "  (") ")"))

  (define str-s2'
    [] S -> (cn S "c#10;")

    [[Head Name Args Nregs Code] | Y] S ->
    (let S (make-string "~A(~A ~R ~R ~R~%" S Head Name Args Nregs)
         S (pp-labels Code S)
         S (make-string "~A)~%~%" S)
      (str-s2' Y S))
    where (element? Head [klvm.func klvm.toplevel klvm.closure])

    [X | Y] S -> (let A (value *maximum-print-sequence-size*)
                      . (set *maximum-print-sequence-size* -1)
                      S (make-string "~A~S~%" S X)
                      . (set *maximum-print-sequence-size* A)
                     (str-s2' Y S)))

  (define str-s2
    X -> (str-s2' X ""))

  (define for-each
    Fn [] -> []
    Fn [X | Xs] -> (do (Fn X) (for-each Fn Xs)))
    
  (define asm-shen
    -> (let Sdir "official/Shen 19.2/KLambda"
            Ddir "klvm/test/shen"
            Files ["core.kl" "declarations.kl" "load.kl" "macros.kl"
                   "prolog.kl" "reader.kl" "sequent.kl" "sys.kl" "t-star.kl"
                   "toplevel.kl" "track.kl" "types.kl" "writer.kl" "yacc.kl"]
         (for-each (/. X (write-asm
                          (read-file (make-string "~A/~A" Sdir X))
                          (make-string "~A/~A.klvma" Ddir X)))
                   Files))))
