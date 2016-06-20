Require Import compcert.exportclight.Clightdefs.

Local Open Scope Z_scope.

Definition ___builtin_fnmadd : ident := 40%positive.
Definition ___builtin_bswap16 : ident := 32%positive.
Definition ___compcert_va_composite : ident := 16%positive.
Definition ___builtin_fmadd : ident := 38%positive.
Definition ___builtin_nop : ident := 46%positive.
Definition _insert_value : ident := 54%positive.
Definition ___i64_udiv : ident := 24%positive.
Definition ___i64_utof : ident := 22%positive.
Definition ___i64_dtos : ident := 17%positive.
Definition ___builtin_membar : ident := 8%positive.
Definition ___builtin_memcpy_aligned : ident := 5%positive.
Definition _index : ident := 50%positive.
Definition ___builtin_read32_reversed : ident := 43%positive.
Definition ___builtin_va_end : ident := 12%positive.
Definition _guard : ident := 53%positive.
Definition ___builtin_debug : ident := 47%positive.
Definition ___builtin_va_arg : ident := 10%positive.
Definition _next : ident := 57%positive.
Definition ___builtin_write16_reversed : ident := 44%positive.
Definition _tail : ident := 3%positive.
Definition _list : ident := 2%positive.
Definition _head : ident := 1%positive.
Definition ___builtin_fmax : ident := 36%positive.
Definition ___builtin_bswap32 : ident := 31%positive.
Definition ___compcert_va_int64 : ident := 14%positive.
Definition ___builtin_annot : ident := 6%positive.
Definition ___i64_umod : ident := 26%positive.
Definition ___i64_stod : ident := 19%positive.
Definition ___builtin_fmsub : ident := 39%positive.
Definition ___builtin_va_copy : ident := 11%positive.
Definition _sorted : ident := 49%positive.
Definition _main : ident := 59%positive.
Definition ___builtin_fmin : ident := 37%positive.
Definition ___builtin_fabs : ident := 4%positive.
Definition _insertionsort : ident := 58%positive.
Definition ___i64_shr : ident := 28%positive.
Definition ___builtin_annot_intval : ident := 7%positive.
Definition ___builtin_read16_reversed : ident := 42%positive.
Definition ___i64_stof : ident := 21%positive.
Definition ___i64_dtou : ident := 18%positive.
Definition ___builtin_va_start : ident := 9%positive.
Definition _sortedvalue : ident := 52%positive.
Definition ___builtin_write32_reversed : ident := 45%positive.
Definition ___builtin_fnmsub : ident := 41%positive.
Definition ___compcert_va_int32 : ident := 13%positive.
Definition ___i64_shl : ident := 27%positive.
Definition ___builtin_clz : ident := 33%positive.
Definition _p : ident := 56%positive.
Definition ___i64_smod : ident := 25%positive.
Definition ___compcert_va_float64 : ident := 15%positive.
Definition ___builtin_ctz : ident := 34%positive.
Definition ___i64_sar : ident := 29%positive.
Definition _insert : ident := 55%positive.
Definition ___builtin_fsqrt : ident := 35%positive.
Definition ___builtin_bswap : ident := 30%positive.
Definition ___i64_sdiv : ident := 23%positive.
Definition _previous : ident := 51%positive.
Definition _insert_node : ident := 48%positive.
Definition ___i64_utod : ident := 20%positive.

Definition f_insert := {|
  fn_return := (tptr (Tstruct _list noattr));
  fn_callconv := cc_default;
  fn_params := ((_insert_node, (tptr (Tstruct _list noattr))) ::
                (_sorted, (tptr (Tstruct _list noattr))) :: nil);
  fn_vars := nil;
  fn_temps := ((_index, (tptr (Tstruct _list noattr))) ::
               (_previous, (tptr (Tstruct _list noattr))) ::
               (_sortedvalue, tint) :: (_guard, tint) ::
               (_insert_value, tint) :: (61%positive, tint) ::
               (60%positive, tint) :: nil);
  fn_body :=
(Ssequence
  (Sset _previous (Ecast (Econst_int (Int.repr 0) tint) (tptr tvoid)))
  (Ssequence
    (Sset _insert_value
      (Efield
        (Ederef (Etempvar _insert_node (tptr (Tstruct _list noattr)))
          (Tstruct _list noattr)) _head tint))
    (Ssequence
      (Sset _index (Etempvar _sorted (tptr (Tstruct _list noattr))))
      (Ssequence
        (Sifthenelse (Etempvar _index (tptr (Tstruct _list noattr)))
          (Sset _sortedvalue
            (Efield
              (Ederef (Etempvar _index (tptr (Tstruct _list noattr)))
                (Tstruct _list noattr)) _head tint))
          Sskip)
        (Ssequence
          (Ssequence
            (Sifthenelse (Etempvar _index (tptr (Tstruct _list noattr)))
              (Sset 60%positive
                (Ecast
                  (Ebinop Ogt (Etempvar _insert_value tint)
                    (Etempvar _sortedvalue tint) tint) tbool))
              (Sset 60%positive (Econst_int (Int.repr 0) tint)))
            (Sset _guard (Etempvar 60%positive tint)))
          (Ssequence
            (Swhile
              (Etempvar _guard tint)
              (Ssequence
                (Sset _previous
                  (Etempvar _index (tptr (Tstruct _list noattr))))
                (Ssequence
                  (Sset _index
                    (Efield
                      (Ederef (Etempvar _index (tptr (Tstruct _list noattr)))
                        (Tstruct _list noattr)) _tail
                      (tptr (Tstruct _list noattr))))
                  (Ssequence
                    (Sifthenelse (Etempvar _index (tptr (Tstruct _list noattr)))
                      (Sset _sortedvalue
                        (Efield
                          (Ederef
                            (Etempvar _index (tptr (Tstruct _list noattr)))
                            (Tstruct _list noattr)) _head tint))
                      Sskip)
                    (Ssequence
                      (Sifthenelse (Etempvar _index (tptr (Tstruct _list noattr)))
                        (Sset 61%positive
                          (Ecast
                            (Ebinop Ogt (Etempvar _insert_value tint)
                              (Etempvar _sortedvalue tint) tint) tbool))
                        (Sset 61%positive (Econst_int (Int.repr 0) tint)))
                      (Sset _guard (Etempvar 61%positive tint)))))))
            (Ssequence
              (Sassign
                (Efield
                  (Ederef
                    (Etempvar _insert_node (tptr (Tstruct _list noattr)))
                    (Tstruct _list noattr)) _tail
                  (tptr (Tstruct _list noattr)))
                (Etempvar _index (tptr (Tstruct _list noattr))))
              (Ssequence
                (Sifthenelse (Etempvar _previous (tptr (Tstruct _list noattr)))
                  (Ssequence
                    (Sassign
                      (Efield
                        (Ederef
                          (Etempvar _previous (tptr (Tstruct _list noattr)))
                          (Tstruct _list noattr)) _tail
                        (tptr (Tstruct _list noattr)))
                      (Etempvar _insert_node (tptr (Tstruct _list noattr))))
                    (Sreturn (Some (Etempvar _sorted (tptr (Tstruct _list noattr))))))
                  Sskip)
                (Sreturn (Some (Etempvar _insert_node (tptr (Tstruct _list noattr)))))))))))))
|}.

Definition f_insertionsort := {|
  fn_return := (tptr (Tstruct _list noattr));
  fn_callconv := cc_default;
  fn_params := ((_p, (tptr (Tstruct _list noattr))) :: nil);
  fn_vars := nil;
  fn_temps := ((_index, (tptr (Tstruct _list noattr))) ::
               (_sorted, (tptr (Tstruct _list noattr))) ::
               (_next, (tptr (Tstruct _list noattr))) ::
               (62%positive, (tptr (Tstruct _list noattr))) :: nil);
  fn_body :=
(Ssequence
  (Sset _sorted (Ecast (Econst_int (Int.repr 0) tint) (tptr tvoid)))
  (Ssequence
    (Sset _index (Etempvar _p (tptr (Tstruct _list noattr))))
    (Ssequence
      (Swhile
        (Etempvar _index (tptr (Tstruct _list noattr)))
        (Ssequence
          (Sset _next
            (Efield
              (Ederef (Etempvar _index (tptr (Tstruct _list noattr)))
                (Tstruct _list noattr)) _tail (tptr (Tstruct _list noattr))))
          (Ssequence
            (Sassign
              (Efield
                (Ederef (Etempvar _index (tptr (Tstruct _list noattr)))
                  (Tstruct _list noattr)) _tail
                (tptr (Tstruct _list noattr)))
              (Ecast (Econst_int (Int.repr 0) tint) (tptr tvoid)))
            (Ssequence
              (Ssequence
                (Scall (Some 62%positive)
                  (Evar _insert (Tfunction
                                  (Tcons (tptr (Tstruct _list noattr))
                                    (Tcons (tptr (Tstruct _list noattr))
                                      Tnil)) (tptr (Tstruct _list noattr))
                                  cc_default))
                  ((Etempvar _index (tptr (Tstruct _list noattr))) ::
                   (Etempvar _sorted (tptr (Tstruct _list noattr))) :: nil))
                (Sset _sorted
                  (Etempvar 62%positive (tptr (Tstruct _list noattr)))))
              (Sset _index (Etempvar _next (tptr (Tstruct _list noattr))))))))
      (Sreturn (Some (Etempvar _sorted (tptr (Tstruct _list noattr))))))))
|}.

Definition f_main := {|
  fn_return := tint;
  fn_callconv := cc_default;
  fn_params := nil;
  fn_vars := nil;
  fn_temps := nil;
  fn_body :=
(Ssequence
  (Sreturn (Some (Econst_int (Int.repr 0) tint)))
  (Sreturn (Some (Econst_int (Int.repr 0) tint))))
|}.

Definition composites : list composite_definition :=
(Composite _list Struct
   ((_head, tint) :: (_tail, (tptr (Tstruct _list noattr))) :: nil)
   noattr :: nil).

Definition prog : Clight.program := {|
prog_defs :=
((___builtin_fabs,
   Gfun(External (EF_builtin "__builtin_fabs"
                   (mksignature (AST.Tfloat :: nil) (Some AST.Tfloat)
                     cc_default)) (Tcons tdouble Tnil) tdouble cc_default)) ::
 (___builtin_memcpy_aligned,
   Gfun(External (EF_builtin "__builtin_memcpy_aligned"
                   (mksignature
                     (AST.Tint :: AST.Tint :: AST.Tint :: AST.Tint :: nil)
                     None cc_default))
     (Tcons (tptr tvoid)
       (Tcons (tptr tvoid) (Tcons tuint (Tcons tuint Tnil)))) tvoid
     cc_default)) ::
 (___builtin_annot,
   Gfun(External (EF_builtin "__builtin_annot"
                   (mksignature (AST.Tint :: nil) None
                     {|cc_vararg:=true; cc_unproto:=false; cc_structret:=false|}))
     (Tcons (tptr tschar) Tnil) tvoid
     {|cc_vararg:=true; cc_unproto:=false; cc_structret:=false|})) ::
 (___builtin_annot_intval,
   Gfun(External (EF_builtin "__builtin_annot_intval"
                   (mksignature (AST.Tint :: AST.Tint :: nil) (Some AST.Tint)
                     cc_default)) (Tcons (tptr tschar) (Tcons tint Tnil))
     tint cc_default)) ::
 (___builtin_membar,
   Gfun(External (EF_builtin "__builtin_membar"
                   (mksignature nil None cc_default)) Tnil tvoid cc_default)) ::
 (___builtin_va_start,
   Gfun(External (EF_builtin "__builtin_va_start"
                   (mksignature (AST.Tint :: nil) None cc_default))
     (Tcons (tptr tvoid) Tnil) tvoid cc_default)) ::
 (___builtin_va_arg,
   Gfun(External (EF_builtin "__builtin_va_arg"
                   (mksignature (AST.Tint :: AST.Tint :: nil) None
                     cc_default)) (Tcons (tptr tvoid) (Tcons tuint Tnil))
     tvoid cc_default)) ::
 (___builtin_va_copy,
   Gfun(External (EF_builtin "__builtin_va_copy"
                   (mksignature (AST.Tint :: AST.Tint :: nil) None
                     cc_default))
     (Tcons (tptr tvoid) (Tcons (tptr tvoid) Tnil)) tvoid cc_default)) ::
 (___builtin_va_end,
   Gfun(External (EF_builtin "__builtin_va_end"
                   (mksignature (AST.Tint :: nil) None cc_default))
     (Tcons (tptr tvoid) Tnil) tvoid cc_default)) ::
 (___compcert_va_int32,
   Gfun(External (EF_external "__compcert_va_int32"
                   (mksignature (AST.Tint :: nil) (Some AST.Tint) cc_default))
     (Tcons (tptr tvoid) Tnil) tuint cc_default)) ::
 (___compcert_va_int64,
   Gfun(External (EF_external "__compcert_va_int64"
                   (mksignature (AST.Tint :: nil) (Some AST.Tlong)
                     cc_default)) (Tcons (tptr tvoid) Tnil) tulong
     cc_default)) ::
 (___compcert_va_float64,
   Gfun(External (EF_external "__compcert_va_float64"
                   (mksignature (AST.Tint :: nil) (Some AST.Tfloat)
                     cc_default)) (Tcons (tptr tvoid) Tnil) tdouble
     cc_default)) ::
 (___compcert_va_composite,
   Gfun(External (EF_external "__compcert_va_composite"
                   (mksignature (AST.Tint :: AST.Tint :: nil) (Some AST.Tint)
                     cc_default)) (Tcons (tptr tvoid) (Tcons tuint Tnil))
     (tptr tvoid) cc_default)) ::
 (___i64_dtos,
   Gfun(External (EF_external "__i64_dtos"
                   (mksignature (AST.Tfloat :: nil) (Some AST.Tlong)
                     cc_default)) (Tcons tdouble Tnil) tlong cc_default)) ::
 (___i64_dtou,
   Gfun(External (EF_external "__i64_dtou"
                   (mksignature (AST.Tfloat :: nil) (Some AST.Tlong)
                     cc_default)) (Tcons tdouble Tnil) tulong cc_default)) ::
 (___i64_stod,
   Gfun(External (EF_external "__i64_stod"
                   (mksignature (AST.Tlong :: nil) (Some AST.Tfloat)
                     cc_default)) (Tcons tlong Tnil) tdouble cc_default)) ::
 (___i64_utod,
   Gfun(External (EF_external "__i64_utod"
                   (mksignature (AST.Tlong :: nil) (Some AST.Tfloat)
                     cc_default)) (Tcons tulong Tnil) tdouble cc_default)) ::
 (___i64_stof,
   Gfun(External (EF_external "__i64_stof"
                   (mksignature (AST.Tlong :: nil) (Some AST.Tsingle)
                     cc_default)) (Tcons tlong Tnil) tfloat cc_default)) ::
 (___i64_utof,
   Gfun(External (EF_external "__i64_utof"
                   (mksignature (AST.Tlong :: nil) (Some AST.Tsingle)
                     cc_default)) (Tcons tulong Tnil) tfloat cc_default)) ::
 (___i64_sdiv,
   Gfun(External (EF_external "__i64_sdiv"
                   (mksignature (AST.Tlong :: AST.Tlong :: nil)
                     (Some AST.Tlong) cc_default))
     (Tcons tlong (Tcons tlong Tnil)) tlong cc_default)) ::
 (___i64_udiv,
   Gfun(External (EF_external "__i64_udiv"
                   (mksignature (AST.Tlong :: AST.Tlong :: nil)
                     (Some AST.Tlong) cc_default))
     (Tcons tulong (Tcons tulong Tnil)) tulong cc_default)) ::
 (___i64_smod,
   Gfun(External (EF_external "__i64_smod"
                   (mksignature (AST.Tlong :: AST.Tlong :: nil)
                     (Some AST.Tlong) cc_default))
     (Tcons tlong (Tcons tlong Tnil)) tlong cc_default)) ::
 (___i64_umod,
   Gfun(External (EF_external "__i64_umod"
                   (mksignature (AST.Tlong :: AST.Tlong :: nil)
                     (Some AST.Tlong) cc_default))
     (Tcons tulong (Tcons tulong Tnil)) tulong cc_default)) ::
 (___i64_shl,
   Gfun(External (EF_external "__i64_shl"
                   (mksignature (AST.Tlong :: AST.Tint :: nil)
                     (Some AST.Tlong) cc_default))
     (Tcons tlong (Tcons tint Tnil)) tlong cc_default)) ::
 (___i64_shr,
   Gfun(External (EF_external "__i64_shr"
                   (mksignature (AST.Tlong :: AST.Tint :: nil)
                     (Some AST.Tlong) cc_default))
     (Tcons tulong (Tcons tint Tnil)) tulong cc_default)) ::
 (___i64_sar,
   Gfun(External (EF_external "__i64_sar"
                   (mksignature (AST.Tlong :: AST.Tint :: nil)
                     (Some AST.Tlong) cc_default))
     (Tcons tlong (Tcons tint Tnil)) tlong cc_default)) ::
 (___builtin_bswap,
   Gfun(External (EF_builtin "__builtin_bswap"
                   (mksignature (AST.Tint :: nil) (Some AST.Tint) cc_default))
     (Tcons tuint Tnil) tuint cc_default)) ::
 (___builtin_bswap32,
   Gfun(External (EF_builtin "__builtin_bswap32"
                   (mksignature (AST.Tint :: nil) (Some AST.Tint) cc_default))
     (Tcons tuint Tnil) tuint cc_default)) ::
 (___builtin_bswap16,
   Gfun(External (EF_builtin "__builtin_bswap16"
                   (mksignature (AST.Tint :: nil) (Some AST.Tint) cc_default))
     (Tcons tushort Tnil) tushort cc_default)) ::
 (___builtin_clz,
   Gfun(External (EF_builtin "__builtin_clz"
                   (mksignature (AST.Tint :: nil) (Some AST.Tint) cc_default))
     (Tcons tuint Tnil) tint cc_default)) ::
 (___builtin_ctz,
   Gfun(External (EF_builtin "__builtin_ctz"
                   (mksignature (AST.Tint :: nil) (Some AST.Tint) cc_default))
     (Tcons tuint Tnil) tint cc_default)) ::
 (___builtin_fsqrt,
   Gfun(External (EF_builtin "__builtin_fsqrt"
                   (mksignature (AST.Tfloat :: nil) (Some AST.Tfloat)
                     cc_default)) (Tcons tdouble Tnil) tdouble cc_default)) ::
 (___builtin_fmax,
   Gfun(External (EF_builtin "__builtin_fmax"
                   (mksignature (AST.Tfloat :: AST.Tfloat :: nil)
                     (Some AST.Tfloat) cc_default))
     (Tcons tdouble (Tcons tdouble Tnil)) tdouble cc_default)) ::
 (___builtin_fmin,
   Gfun(External (EF_builtin "__builtin_fmin"
                   (mksignature (AST.Tfloat :: AST.Tfloat :: nil)
                     (Some AST.Tfloat) cc_default))
     (Tcons tdouble (Tcons tdouble Tnil)) tdouble cc_default)) ::
 (___builtin_fmadd,
   Gfun(External (EF_builtin "__builtin_fmadd"
                   (mksignature
                     (AST.Tfloat :: AST.Tfloat :: AST.Tfloat :: nil)
                     (Some AST.Tfloat) cc_default))
     (Tcons tdouble (Tcons tdouble (Tcons tdouble Tnil))) tdouble
     cc_default)) ::
 (___builtin_fmsub,
   Gfun(External (EF_builtin "__builtin_fmsub"
                   (mksignature
                     (AST.Tfloat :: AST.Tfloat :: AST.Tfloat :: nil)
                     (Some AST.Tfloat) cc_default))
     (Tcons tdouble (Tcons tdouble (Tcons tdouble Tnil))) tdouble
     cc_default)) ::
 (___builtin_fnmadd,
   Gfun(External (EF_builtin "__builtin_fnmadd"
                   (mksignature
                     (AST.Tfloat :: AST.Tfloat :: AST.Tfloat :: nil)
                     (Some AST.Tfloat) cc_default))
     (Tcons tdouble (Tcons tdouble (Tcons tdouble Tnil))) tdouble
     cc_default)) ::
 (___builtin_fnmsub,
   Gfun(External (EF_builtin "__builtin_fnmsub"
                   (mksignature
                     (AST.Tfloat :: AST.Tfloat :: AST.Tfloat :: nil)
                     (Some AST.Tfloat) cc_default))
     (Tcons tdouble (Tcons tdouble (Tcons tdouble Tnil))) tdouble
     cc_default)) ::
 (___builtin_read16_reversed,
   Gfun(External (EF_builtin "__builtin_read16_reversed"
                   (mksignature (AST.Tint :: nil) (Some AST.Tint) cc_default))
     (Tcons (tptr tushort) Tnil) tushort cc_default)) ::
 (___builtin_read32_reversed,
   Gfun(External (EF_builtin "__builtin_read32_reversed"
                   (mksignature (AST.Tint :: nil) (Some AST.Tint) cc_default))
     (Tcons (tptr tuint) Tnil) tuint cc_default)) ::
 (___builtin_write16_reversed,
   Gfun(External (EF_builtin "__builtin_write16_reversed"
                   (mksignature (AST.Tint :: AST.Tint :: nil) None
                     cc_default)) (Tcons (tptr tushort) (Tcons tushort Tnil))
     tvoid cc_default)) ::
 (___builtin_write32_reversed,
   Gfun(External (EF_builtin "__builtin_write32_reversed"
                   (mksignature (AST.Tint :: AST.Tint :: nil) None
                     cc_default)) (Tcons (tptr tuint) (Tcons tuint Tnil))
     tvoid cc_default)) ::
 (___builtin_nop,
   Gfun(External (EF_builtin "__builtin_nop"
                   (mksignature nil None cc_default)) Tnil tvoid cc_default)) ::
 (___builtin_debug,
   Gfun(External (EF_external "__builtin_debug"
                   (mksignature (AST.Tint :: nil) None
                     {|cc_vararg:=true; cc_unproto:=false; cc_structret:=false|}))
     (Tcons tint Tnil) tvoid
     {|cc_vararg:=true; cc_unproto:=false; cc_structret:=false|})) ::
 (_insert, Gfun(Internal f_insert)) ::
 (_insertionsort, Gfun(Internal f_insertionsort)) ::
 (_main, Gfun(Internal f_main)) :: nil);
prog_public :=
(_main :: _insertionsort :: _insert :: ___builtin_debug :: ___builtin_nop ::
 ___builtin_write32_reversed :: ___builtin_write16_reversed ::
 ___builtin_read32_reversed :: ___builtin_read16_reversed ::
 ___builtin_fnmsub :: ___builtin_fnmadd :: ___builtin_fmsub ::
 ___builtin_fmadd :: ___builtin_fmin :: ___builtin_fmax ::
 ___builtin_fsqrt :: ___builtin_ctz :: ___builtin_clz ::
 ___builtin_bswap16 :: ___builtin_bswap32 :: ___builtin_bswap ::
 ___i64_sar :: ___i64_shr :: ___i64_shl :: ___i64_umod :: ___i64_smod ::
 ___i64_udiv :: ___i64_sdiv :: ___i64_utof :: ___i64_stof :: ___i64_utod ::
 ___i64_stod :: ___i64_dtou :: ___i64_dtos :: ___compcert_va_composite ::
 ___compcert_va_float64 :: ___compcert_va_int64 :: ___compcert_va_int32 ::
 ___builtin_va_end :: ___builtin_va_copy :: ___builtin_va_arg ::
 ___builtin_va_start :: ___builtin_membar :: ___builtin_annot_intval ::
 ___builtin_annot :: ___builtin_memcpy_aligned :: ___builtin_fabs :: nil);
prog_main := _main;
prog_types := composites;
prog_comp_env := make_composite_env composites;
prog_comp_env_eq := refl_equal _
|}.

