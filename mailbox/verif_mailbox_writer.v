Require Import mailbox.verif_atomic_exchange.
Require Import VST.concurrency.conclib.
Require Import VST.concurrency.ghosts.
Require Import VST.floyd.library.
Require Import VST.zlist.sublist.
Require Import mailbox.mailbox.
Require Import mailbox.verif_mailbox_specs.

Set Bullet Behavior "Strict Subproofs".

Opaque upto.

Ltac entailer_for_load_tac ::= unfold tc_efield; go_lower; entailer'.
Ltac entailer_for_store_tac ::= unfold tc_efield; go_lower; entailer'.

Lemma body_writer : semax_body Vprog Gprog f_writer writer_spec.
Proof.
  start_function.
  forward_call gv.
  forward.
  forward_loop (EX v : Z, EX b0 : Z, EX lasts : list Z, EX h : list hist,
   PROP (0 <= b0 < B; Forall (fun x => 0 <= x < B) lasts; Zlength h = N; ~In b0 lasts)
   LOCAL (temp _v (vint v); temp _arg arg; gvars gv)
   SEP (data_at Ews tint Empty (gv _writing); data_at Ews tint (vint b0) (gv _last_given);
   data_at Ews (tarray tint N) (map (fun x => vint x) lasts) (gv _last_taken);
   data_at sh1 (tarray (tptr tint) N) comms (gv _comm); data_at sh1 (tarray (tptr tlock) N) locks (gv _lock);
   data_at sh1 (tarray (tptr tbuffer) B) bufs (gv _bufs);
   fold_right sepcon emp (map (fun r0 => comm_loc lsh (Znth r0 locks) (Znth r0 comms)
     (Znth r0 g) (Znth r0 g0) (Znth r0 g1) (Znth r0 g2) bufs
     (Znth r0 shs) gsh2 (Znth r0 h)) (upto (Z.to_nat N)));
   fold_right sepcon emp (map (fun r0 => ghost_var gsh1 (vint b0) (Znth r0 g1) *
     ghost_var gsh1 (vint (@Znth Z (-1) r0 lasts)) (Znth r0 g2)) (upto (Z.to_nat N)));
   fold_right sepcon emp (map (fun i => EX sh : share, !! (if eq_dec i b0 then sh = sh0
     else sepalg_list.list_join sh0 (make_shares shs lasts i) sh) &&
     (EX v : Z, @data_at CompSpecs sh tbuffer (vint v) (Znth i bufs))) (upto (Z.to_nat B)))))
  break: (@FF (environ->mpred) _).
  { Exists 0 0 (repeat 1 (Z.to_nat N)) (repeat (empty_map : hist) (Z.to_nat N)); entailer!; simpl.
    my_auto.
    { repeat constructor; computable. }
    rewrite sepcon_map.
    apply derives_refl'.
    rewrite !sepcon_assoc; f_equal; f_equal; [|f_equal].
    - rewrite list_Znth_eq with (l := g1) at 1.
      replace (length g1) with (Z.to_nat N) by (symmetry; rewrite <- Zlength_length; auto; unfold N; computable).
      rewrite map_map; auto.
    - rewrite list_Znth_eq with (l := g2) at 1.
      replace (length g2) with (Z.to_nat N) by (symmetry; rewrite <- Zlength_length; auto; unfold N; computable).
      erewrite map_map, map_ext_in; eauto.
      intros; rewrite In_upto in *.
      match goal with |- context[@Znth Z (-1) a ?l] => replace (@Znth Z (-1) a l) with 1; auto end.
      apply Forall_Znth; auto.
    - erewrite map_ext_in; eauto.
      intros; rewrite In_upto in *.
      destruct (eq_dec a 0); auto.
      destruct (eq_dec a 1), (eq_dec 1 a); auto; try lia.
      { apply pred_ext; Intros sh; Exists sh; entailer!.
        * constructor.
        * match goal with H : sepalg_list.list_join sh0 _ sh |- _ => inv H; auto end. }
      generalize (make_shares_out a (repeat 1 (Z.to_nat N)) shs); simpl; intro Heq.
      destruct (eq_dec 1 a); [contradiction n0; auto|].
       rewrite Heq; auto; [|lia].
      apply pred_ext; Intros sh; Exists sh; entailer!.
      eapply list_join_eq; eauto. }
  Intros v b0 lasts h.
  rewrite sepcon_map; Intros.
  forward_call (b0, lasts, gv).
  Intros b.
  rewrite (extract_nth_sepcon (map _ (upto (Z.to_nat B))) b); [|rewrite Zlength_map; auto].
  erewrite Znth_map, Znth_upto; auto; rewrite ?Z2Nat.id; try lia.
  Intros sh v0.
  rewrite (data_at_isptr _ tbuffer); Intros.
  forward.
  destruct (eq_dec b b0); [absurd (b = b0); auto|].
  assert_PROP (Zlength lasts = N).
  { gather_SEP (data_at _ _ _ (gv _last_taken)).
    go_lowerx; apply sepcon_derives_prop.
    eapply derives_trans; [apply data_array_at_local_facts|].
    apply prop_left; intros (_ & ? & _); apply prop_right.
    unfold unfold_reptype in *; simpl in *.
    rewrite Zlength_map in *; auto. }
  rewrite make_shares_out in *; auto; [|setoid_rewrite H; auto].
  assert (sh = Ews) by (eapply list_join_eq; eauto); subst.
  forward.
  gather_SEP (fold_right sepcon emp (map (fun x : Z => ghost_var gsh1 (vint b0) _) _))
                     (fold_right sepcon emp (map (fun x : Z => ghost_var gsh1 (vint (Znth x lasts)) _) _)).
  rewrite <- sepcon_map.
  gather_SEP (data_at _ _ _ (Znth b bufs))
                    (fold_right sepcon emp (upd_Znth b _ _)).
 replace_SEP 0 (fold_right sepcon emp (map (fun i => EX sh2 : share,
    !! (if eq_dec i b0 then sh2 = sh0 else sepalg_list.list_join sh0 (make_shares shs lasts i) sh2) &&
    (EX v1 : Z, data_at sh2 tbuffer (vint v1) (Znth i bufs))) (upto (Z.to_nat B)))).
  { Opaque B.
    go_lowerx; eapply derives_trans with (Q := _ * _);
      [|erewrite replace_nth_sepcon, upd_Znth_triv; try apply derives_refl; eauto].

    rewrite Znth_map by (rewrite (Zlength_upto); assumption).
    rewrite Znth_upto by assumption.
    destruct (eq_dec b b0); [absurd (b = b0); auto|].
    rewrite make_shares_out; auto; [|setoid_rewrite H; auto].
    Exists Ews v; entailer!. }
  change (upto 3) with (upto (Z.to_nat N)).
  change (upto 5) with (upto (Z.to_nat B)).
  forward_call (comms, locks, bufs, b, b0, lasts,
    sh1, lsh, shs, g, g0, g1, g2, h, sh0, gv).
  Intros x; destruct x as (lasts', h').
  rewrite sepcon_map; Intros.
  forward.
  Exists (v + 1) b lasts' h'; rewrite sepcon_map; entailer!.
  replace N with (Zlength h) by auto; symmetry; eapply mem_lemmas.Forall2_Zlength; eauto.
  simpl; cancel.
Qed.
