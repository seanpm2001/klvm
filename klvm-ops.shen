(package klvm []
  (define opcode-num
    op_toplevel -> 128
    op_func -> 129
    op_closure -> 130
    op_goto -> 131
    op_goto-if -> 132
    op_call -> 133
    op_nargs>0 -> 134
    op_nargs-cond -> 135
    op_return -> 136
    op_func-exit -> 137
    op_func-entry -> 138
    op_func-obj -> 139
    op_a-set -> 140
    op_a-add -> 141
    op_b-set -> 142
    op_b-add -> 143
    op_nregs-> -> 144
    op_reg-> -> 145
    op_reg -> 146
    op_reg2 -> 147
    op_const-sym -> 148
    op_const-str -> 149
    op_const-i8 -> 150
    op_const-u16 -> 151
    op_const-i16 -> 152
    op_const-i32 -> 153
    op_stack-size -> 154
    op_stack-> -> 155
    op_stack -> 156
    op_stack2 -> 157
    op_inc-stack-ptr -> 158
    op_dec-stack-ptr -> 159
    op_nargs-> -> 160
    op_nargs -> 161
    op_inc-nargs -> 162
    op_dec-nargs -> 163
    op_inc-nargs-by-closure-nargs -> 164
    op_push-extra-args -> 165
    op_pop-extra-args -> 166
    op_closure-> -> 167
    op_closure-nargs -> 168
    op_closure-func -> 169
    op_put-closure-args -> 170
    op_mk-closure -> 171
    op_pop-error-handler -> 172
    op_push-error-handler -> 173
    op_error-unwind-get-handler -> 174
    op_current-error -> 175
    op_fail -> 176
    X -> (error "Unknown operation ~A." X)))