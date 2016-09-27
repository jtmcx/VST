Require Import Coq.Strings.String.

Require Import compcert.lib.Integers.
Require Import compcert.common.AST.
Require Import compcert.cfrontend.Clight.
Require Import compcert.common.Globalenvs.
Require Import compcert.common.Memory.
Require Import compcert.common.Memdata.
Require Import compcert.common.Values.

Require Import msl.Coqlib2.
Require Import msl.eq_dec.
Require Import msl.seplog.
Require Import veric.initial_world.
Require Import veric.juicy_mem.
Require Import veric.juicy_mem_lemmas.
Require Import veric.semax_prog.
Require Import veric.compcert_rmaps.
Require Import veric.Clight_new.
Require Import veric.Clightnew_coop.
Require Import veric.semax.
Require Import veric.semax_ext.
Require Import veric.juicy_extspec.
Require Import veric.initial_world.
Require Import veric.juicy_extspec.
Require Import veric.tycontext.
Require Import veric.semax_ext.
Require Import veric.semax_ext_oracle.
Require Import veric.res_predicates.
Require Import veric.mem_lessdef.
Require Import floyd.coqlib3.
Require Import sepcomp.semantics.
Require Import sepcomp.step_lemmas.
Require Import sepcomp.event_semantics.
Require Import sepcomp.semantics_lemmas.
Require Import concurrency.coqlib5.
Require Import concurrency.permjoin.
Require Import concurrency.semax_conc.
Require Import concurrency.juicy_machine.
Require Import concurrency.concurrent_machine.
Require Import concurrency.scheduler.
Require Import concurrency.addressFiniteMap.
Require Import concurrency.permissions.
Require Import concurrency.JuicyMachineModule.
Require Import concurrency.age_to.
Require Import concurrency.sync_preds_defs.
Require Import concurrency.sync_preds.
Require Import concurrency.join_lemmas.
Require Import concurrency.aging_lemmas.
Require Import concurrency.cl_step_lemmas.
Require Import concurrency.resource_decay_lemmas.
Require Import concurrency.resource_decay_join.
Require Import concurrency.semax_invariant.
Require Import concurrency.semax_simlemmas.
Require Import concurrency.sync_preds.

Set Bullet Behavior "Strict Subproofs".

Lemma rmap_bound_join {b phi1 phi2 phi3} :
  join phi1 phi2 phi3 ->
  rmap_bound b phi3 ->
  rmap_bound b phi2.
Proof.
  intros j B l p; specialize (B l p).
  apply resource_at_join with (loc := l) in j.
  rewrite B in j.
  inv j; eauto.
  erewrite join_to_bot_l; eauto.
Qed.

Lemma mem_compatible_with_age {n tp m phi} :
  mem_compatible_with tp m phi ->
  mem_compatible_with (age_tp_to n tp) m (age_to n phi).
Proof.
  intros [J AC LW LJ JL]; constructor.
  - rewrite join_all_joinlist in *.
    rewrite maps_age_to.
    apply joinlist_age_to, J.
  - apply mem_cohere_age_to; easy.
  - apply lockSet_Writable_age; easy.
  - apply juicyLocks_in_lockSet_age. easy.
  - apply lockSet_in_juicyLocks_age. easy.
Qed.

Lemma resource_decay_lockSet_in_juicyLocks b phi phi' lset :
  resource_decay b phi phi' ->
  lockSet_block_bound lset b ->
  lockSet_in_juicyLocks lset phi ->
  lockSet_in_juicyLocks lset phi'.
Proof.
  intros RD LB IN loc IT.
  destruct (IN _ IT) as (rsh & sh & pp & E).
  (* assert (SL : same_locks phi phi') by (eapply resource_decay_same_locks; eauto). *)
  assert (SL : same_locks_sized phi phi') by (eapply resource_decay_same_locks_sized; eauto).
  destruct (SL loc LKSIZE) as [(rsh' & sh' & pp' &  E') _].
  { rewrite E. exists rsh, sh, pp. reflexivity. }
  destruct RD as [L RD].
  destruct (RD loc) as [NN [R|[R|[[P [v R]]|R]]]].
  + rewrite E in R. simpl in R; rewrite <- R.
    eauto.
  + rewrite E in R. destruct R as (sh'' & v & v' & R & H). discriminate.
  + specialize (LB loc).
    cut (fst loc < b)%positive. now intro; exfalso; eauto.
    apply LB. destruct (AMap.find (elt:=option rmap) loc lset).
    * apply I.
    * inversion IT.
  + destruct R as (v & v' & R & N').
    rewrite E'.
    exists rsh', sh', pp'.
    eauto.
Qed.

Lemma resource_decay_joinlist b phi1 phi1' l Phi :
  rmap_bound b Phi ->
  resource_decay b phi1 phi1' ->
  joinlist (phi1 :: l) Phi ->
  exists Phi',
    joinlist (phi1' :: (map (age_to (level phi1')) l)) Phi' /\
    resource_decay b Phi Phi'.
Proof.
  intros B rd (x & h & j).
  assert (Bx : rmap_bound b x). { apply (rmap_bound_join j) in B. intuition. }
  destruct (resource_decay_join _ _ _ _ _ Bx rd j) as (Phi' & j' & rd').
  exists Phi'; split; auto.
  exists (age_to (level phi1') x); split; auto.
  apply joinlist_age_to, h.
Qed.

Lemma resource_decay_join_all {tp m Phi} c' {phi' i} {cnti : ThreadPool.containsThread tp i}:
  rmap_bound (Mem.nextblock m) Phi ->
  resource_decay (Mem.nextblock m) (ThreadPool.getThreadR cnti) phi' /\
  level (getThreadR cnti) = S (level phi') ->
  join_all tp Phi ->
  exists Phi',
    join_all (@updThread i (age_tp_to (level phi') tp) (cnt_age' cnti) c' phi') Phi' /\
    resource_decay (Mem.nextblock m) Phi Phi' /\
    level Phi = S (level Phi').
Proof.
  do 2 rewrite join_all_joinlist.
  intros B (rd, lev) j.
  rewrite (maps_getthread _ _ cnti) in j.
  destruct (resource_decay_joinlist _ _ _ _ _ B rd j) as (Phi' & j' & rd').
  exists Phi'; split; [ | split]; auto.
  - rewrite maps_updthread.
    exact_eq j'. f_equal. f_equal. rewrite <-all_but_map, maps_age_to.
    auto.
  - exact_eq lev; f_equal.
    + apply rmap_join_sub_eq_level. eapply joinlist_join_sub; eauto. left; auto.
    + f_equal. apply rmap_join_sub_eq_level. eapply joinlist_join_sub; eauto. left; auto.
Qed.

Lemma resource_fmap_YES_inv f g r sh rsh k pp :
  resource_fmap f g r = YES sh rsh k pp ->
  exists pp', r = YES sh rsh k pp' /\ pp = preds_fmap f g pp'.
Proof.
  destruct r as [t0 | t0 p k0 p0 | k0 p]; simpl; try congruence.
  injection 1 as <- <- <- <-. eauto.
Qed.

Lemma resource_fmap_PURE_inv f g r k pp :
  resource_fmap f g r = PURE k pp ->
  exists pp', r = PURE k pp' /\ pp = preds_fmap f g pp'.
Proof.
  destruct r as [t0 | t0 p k0 p0 | k0 p]; simpl; try congruence.
  injection 1 as <- <-. eauto.
Qed.

Lemma resource_fmap_NO_inv f g r rsh :
  resource_fmap f g r = NO rsh ->
  r = NO rsh.
Proof.
  destruct r as [t0 | t0 p k0 p0 | k0 p]; simpl; try congruence.
Qed.

Lemma cl_step_mem_step ge c m c' m' : cl_step ge c m c' m' -> mem_step m m'.
Admitted.

Lemma mem_step_contents_at_None m m' loc :
  Mem.valid_block m (fst loc) ->
  mem_step m m' ->
  access_at m loc Cur = None ->
  contents_at m' loc = contents_at m loc.
Proof.
  intros V Ms Ac.
  destruct loc as (b, ofs).
  pose proof mem_step_obeys_cur_write m b ofs m' V as H.
  specialize H _ Ms.
  unfold contents_at in *.
  simpl; symmetry.
  apply H; clear H.
  unfold access_at in *.
  unfold Mem.perm in *.
  simpl in *.
  rewrite Ac.
  intros O; inversion O.
Qed.

Lemma mem_step_contents_at_Nonempty m m' loc :
  Mem.valid_block m (fst loc) ->
  mem_step m m' ->
  access_at m loc Cur = Some Nonempty ->
  contents_at m' loc = contents_at m loc.
Proof.
  intros V Ms Ac.
  destruct loc as (b, ofs).
  pose proof mem_step_obeys_cur_write m b ofs m' V as H.
  specialize H _ Ms.
  unfold contents_at in *.
  simpl; symmetry.
  apply H; clear H.
  unfold access_at in *.
  unfold Mem.perm in *.
  simpl in *.
  rewrite Ac.
  intros O; inversion O.
Qed.

Import Mem.

(*
Lemma mem_step_max_access_at m m' loc :
  mem_step m m' ->
  valid_block m (fst loc) ->
  (forall k, access_at m loc k = access_at m' loc k \/
   (access_at m loc Cur = Some Freeable /\
    access_at m' loc Max = None)).
(*  (~ valid_block m (fst loc) /\    (* not true *)
   (max_access_at m loc = None /\
    max_access_at m' loc = Some Freeable)). *)
Proof.
  (* Lennart is proving this at the moment *)
Admitted.
 *)

Lemma mem_cohere_step_new_attempt c c' jm jm' Phi (X : rmap) ge :
  mem_cohere' (m_dry jm) Phi ->
  sepalg.join (m_phi jm) X Phi ->
  corestep (juicy_core_sem cl_core_sem) ge c jm c' jm' ->
  exists Phi',
    sepalg.join (m_phi jm') (age_to (level (m_phi jm')) X) Phi' /\
    mem_cohere' (m_dry jm') Phi'.
Proof.
  intros MC J (S & RD & L).
  assert (Bx : rmap_bound (Mem.nextblock (m_dry jm)) X) by apply (rmap_bound_join J), MC.
  destruct (resource_decay_join _ _ _ _ _  Bx RD J) as [Phi' [J' RD']].
  apply cl_step_mem_step in S. clear c c'.
  remember (m_dry jm) as m.
  remember (m_dry jm') as m'.
  exists Phi'. split. apply J'.
  revert Phi X jm jm' Heqm Heqm' J RD MC L Bx J' RD'.
  induction S; intros Phi X jm jm' -> -> J RD MC L Bx J' RD'.
  - (* store *)
    (* hm, that does not help much because it does not correlate with
    resource_decay *)
Admitted.


Lemma perm_of_res_resource_fmap f g r :
  perm_of_res (resource_fmap f g r) = perm_of_res r.
Proof.
  destruct r as [t0 | t0 p [] p0 | k p]; simpl; auto.
Qed.

Lemma resource_fmap_join f g r1 r2 r3 :
  join r1 r2 r3 ->
  join (resource_fmap f g r1) (resource_fmap f g r2) (resource_fmap f g r3).
Proof.
  destruct r1 as [t1 | t1 p1 k1 pp1 | k1 pp1];
    destruct r2 as [t2 | t2 p2 k2 pp2 | k2 pp2];
    destruct r3 as [t3 | t3 p3 k3 pp3 | k3 pp3]; simpl; auto;
      intros j; inv j; constructor; auto.
Qed.

Lemma juicy_mem_perm_of_res_Max jm loc :
  perm_order'' (max_access_at (m_dry jm) loc) (perm_of_res (m_phi jm @ loc)).
Proof.
  rewrite <- (juicy_mem_access jm loc).
  apply access_cur_max.
Qed.

Lemma decay_rewrite m m' :
  decay m m' <->
  forall loc, 
    (~valid_block m (fst loc) ->
     valid_block m' (fst loc) ->
     (forall k, access_at m' loc k = Some Freeable) \/
     (forall k, access_at m' loc k = None))
    /\ (valid_block m (fst loc) ->
       (forall k, (access_at m loc k = Some Freeable /\ access_at m' loc k = None)) \/
       (forall k, access_at m loc k = access_at m' loc k)).
Proof.
  unfold decay.
  match goal with
    |- (forall x : ?A, forall y : ?B, ?P) <-> _ =>
    eapply iff_trans with (forall loc : A * B, let x := fst loc in let y := snd loc in P)
  end.
  {
    split.
    intros H []; apply H.
    intros H b ofs; apply (H (b, ofs)).
  }
  split; auto.
Qed.

Lemma valid_block0 m b : ~valid_block m b <-> (b >= nextblock m)%positive.
Admitted.

Lemma valid_block1 m b : valid_block m b <-> (b < nextblock m)%positive.
Admitted.

Lemma mem_cohere_step c c' jm jm' Phi (X : rmap) ge :
  mem_cohere' (m_dry jm) Phi ->
  sepalg.join (m_phi jm) X Phi ->
  corestep (juicy_core_sem cl_core_sem) ge c jm c' jm' ->
  exists Phi',
    sepalg.join (m_phi jm') (age_to (level (m_phi jm')) X) Phi' /\
    mem_cohere' (m_dry jm') Phi'.
Proof.
  intros MC J C.
  destruct C as [step [RD L]].
  assert (Bx : rmap_bound (Mem.nextblock (m_dry jm)) X) by apply (rmap_bound_join J), MC.
  destruct (resource_decay_join _ _ _ _ _  Bx RD (* L *) J) as [Phi' [J' RD']].
  exists Phi'. split. apply J'.
  pose proof cl_step_mem_step _ _ _ _ _ step as ms.
  pose proof cl_step_decay _ _ _ _ _ step as dec.
  
  destruct MC as [A B C D].
  unfold contents_cohere in *.
  
  constructor.
  
  - (* Proving contents_cohere *)
    intros sh rsh v loc pp AT.
    specialize A _ _ _ loc.
    apply (resource_at_join _ _ _ loc) in J.
    apply (resource_at_join _ _ _ loc) in J'.
    destruct RD as (lev, RD); specialize (RD loc).
    
    rewrite age_to_resource_at in *.
    pose proof juicy_mem_contents jm as Co.
    pose proof juicy_mem_contents jm' as Co'.
    pose proof juicy_mem_access jm as Ac.
    pose proof juicy_mem_access jm' as Ac'.
    unfold contents_cohere in *.
    specialize Co _ _ _ loc.
    specialize Co' _ _ _ loc.
    specialize (Ac loc).
    specialize (Ac' loc).
    specialize (Bx loc).
    remember (Phi @ loc) as R.
    remember (Phi' @ loc) as R'.
    remember (m_phi jm @ loc) as j.
    remember (m_phi jm' @ loc) as j'.
    remember (X @ loc) as x.
    remember (resource_fmap (approx (level (m_phi jm'))) (approx (level (m_phi jm'))) x) as x'.
    clear Heqx Heqj Heqj' HeqR' HeqR.
    subst R'.
    inv J'.
    
    + (* everything in jm' *)
      specialize (Co' _ _ _ _ eq_refl).
      auto.
    
    + (* everything in X : it means nothing has been changed at this place in jm' *)
      symmetry in H0.
      apply resource_fmap_YES_inv in H0.
      destruct H0 as (pp' & -> & ->).
      
      inv J.
      * (* case where nothing came from jm, which means indeed
        contents was not changed *)
        specialize (A _ _ _ _ eq_refl).
        destruct A as [A ->].
        rewrite preds_fmap_NoneP; split; auto.
        simpl in Ac.
        assert (Mem.valid_block (m_dry jm) (fst loc)). {
          Lemma not_Pge_Plt a b : ~ Pge a b -> Plt a b.
          Proof.
            unfold Plt. zify. omega.
          Qed.
          apply not_Pge_Plt.
          intros Hl; specialize (Bx Hl).
          discriminate.
        }
        if_tac in Ac.
        -- rewrite mem_step_contents_at_None with (m := m_dry jm); auto.
        -- rewrite mem_step_contents_at_Nonempty with (m := m_dry jm); auto.
      
      * (* case where something was in jm, which is impossible because
        everything is in X *)
        exfalso.
        destruct RD as [NN [RD|[RD|[[P [v' RD]]|RD]]]].
        all: breakhyps.
        injection H as -> -> -> ->.
        apply join_pfullshare in H5.
        destruct H5.
    
    + (* from both X and jm' *)
      symmetry in H1.
      apply resource_fmap_YES_inv in H1.
      destruct H1 as (pp' & -> & ->).
      simpl in *.
      inv J; eauto.
  
  - (* Proving access_cohere' *)
    intros loc.
    specialize (B loc).
    destruct RD as (lev, RD).
    specialize (RD loc).
    destruct RD as [NN [RD|[RD|[[P [v' RD]]|RD]]]].
    + (* The "preserving" case of resource_decay: in this case, same
      wet resources in jm and jm', hence same resources in Phi and
      Phi' *)
      apply resource_at_join with (loc := loc) in J'.
      rewrite <-RD in J'.
      rewrite age_to_resource_at in J'.
      
      apply resource_at_join with (loc := loc) in J.
      pose proof resource_fmap_join (approx (level (m_phi jm'))) (approx (level (m_phi jm'))) _ _ _ J as J_.
      pose proof join_eq J' J_ as E'.
      
      rewrite decay_rewrite in dec.
      specialize (dec loc).
      unfold rmap_bound in *.
      
      destruct dec as (dec1, dec2).
      destruct (valid_block_dec (m_dry jm) (fst loc)); swap 1 2.
      * rewrite <-valid_block0 in NN. autospec NN. rewrite NN in *.
        do 2 autospec Bx.
        rewrite Bx in *.
        inv J.
        rewr (Phi @ loc) in E'. simpl in E'. rewrite E'.
        apply join_bot_bot_eq in RJ. subst. simpl. if_tac. 2:tauto.
        destruct (max_access_at (m_dry jm') loc); constructor.
      * clear dec1. autospec dec2.
        destruct dec2 as [Freed | Same].
        -- exfalso (* old Cur is Freeable, new Cur is None, which
           contradict the case from resource_decay *).
           clear NN step lev L Bx A v.
           clear -Freed RD.
           specialize (Freed Cur).
           do 2 rewrite juicy_mem_access in Freed.
           rewrite <-RD in Freed.
           rewrite perm_of_res_resource_fmap in Freed.
           destruct Freed; congruence.
        -- unfold max_access_at in * (* same Cur and Max *).
           rewrite <-(Same Max), E'.
           rewrite perm_of_res_resource_fmap; auto.
    
    + (* "Write" case *)
      admit.
    
    + (* "Alloc" case *)
      autospec NN.
      admit.
    
    + (* "Free" case *)
      admit.
  
  - (* Proving max_access_cohere *)
    intros loc.
    specialize (C loc).
    admit.
  
  - (* Proving alloc_cohere *)
    intros loc g.
    pose proof juicy_mem_alloc_cohere jm' loc g as Ac'.
    specialize (Bx loc).
    assert_specialize Bx. {
      apply Pos.le_ge. apply Pos.ge_le in g. eapply Pos.le_trans. 2:eauto.
      apply forward_nextblock.
      Lemma mem_step_forward m m' : mem_step m m' -> mem_forward m m'.
        (* Lennart is to push this *)
      Admitted.
      apply mem_step_forward, ms.
    }
    apply resource_at_join with (loc := loc) in J'.
    rewr (m_phi jm' @ loc) in J'.
    rewrite age_to_resource_at in J'.
    rewr (X @ loc) in J'.
    simpl in J'.
    inv J'.
    rewrite (join_bot_bot_eq rsh3); auto.
Admitted.
  
    (*
 
    destruct (RD
      * specialize (Co' _ _ _ _ eq_refl).
        eauto.
      breakhyps.
      subst.
      simpl in *.
      inv J.
      discriminate.
      simpl in *.
        
        injection H0
        simpl in *.
        now breakhyps.
        simpl in *; discriminate.
        specialize (A _ _ _ _ eq_refl).
        destruct A as [A ->].
        rewrite preds_fmap_NoneP; split; auto.
        simpl in Ac.
        assert (Mem.valid_block (m_dry jm) (fst loc)). {
          apply not_Pge_Plt.
          intros Hl; specialize (Bx Hl).
          discriminate.
        }
        if_tac in Ac.
        -- rewrite mem_step_contents_at_None with (m := m_dry jm); auto.
        -- rewrite mem_step_contents_at_Nonempty with (m := m_dry jm); auto.
              
      * eapply A; eauto.
      unfold contents_at in *.
      (* apply cl_step_mem_step  *)
      
            (*
      if_tac in Ac'.
      * erewrite cl_step_access_at_None; eauto.
        
      * 
      
      admit.
    + (* everything in jm' *)
      specialize (Co' _ _ _ _ eq_refl).
      auto.
  
  - 
      inv J.
      
      destruct RD as [NN [RD|[RD|[[P [v' RD]]|RD]]]].
      * apply resource_fmap_NO_inv in RD. subst j.
      inv J.
      specialize (A _ _ _ _ eq_refl).
      subst x.
      destruct RD as [NN [RD|[RD|[[P [v' RD]]|RD]]]].
      * apply resource_fmap_YES_inv in RD.
        destruct RD as (pp' & -> & ->).
        inv J.
        specialize (Co' _ _ _ _ eq_refl).
        auto.
      * destruct RD as (rsh0 & v0 & v' & E & E').
        apply resource_fmap_YES_inv in E.
        destruct E as (pp' & E & HN).
        subst j.
        specialize (Co' _ _ _ _ eq_refl).
        
        symmetry in HN.
        
        eapply preds_fmap_NoneP_approx in HN.
        rewrite preds_fmap_NoneP; split; auto.
        
        simpl.
        unfold NoneP in *.
        destruct A; simpl; split; [ | subst; unfold "oo"; auto].
        unfold NoneP in *.
      
      
    + (* all was in jm' *)
      destruct MC.
      * rewr (m_phi jm' @ loc) in R.

        apply resource_fmap_inv in R.
        rewr (m_phi jm @ loc) in Jloc.
        inv Jloc.
        
          
      destruct rd
      specialize (cont_coh0 sh rsh v loc pp).
      destruct cont_coh0. split; auto.
      rewr (Phi @ loc) in Jloc.
      admit.
    + (* all was in X *)
(*      rewrite <-H in Jloc.
      inversion Jloc; subst.
      * symmetry in H7.
        pose proof cont_coh MC _ H7.
        intuition.
        (* because the juice was NO, the dry hasn't changed *)
        admit.
      * (* same reasoning? *)
        admit.
    + (* joining of permissions, values don't change *)
      symmetry in H.
      destruct jm'.
      apply (JMcontents _ _ _ _ _ H).. *)
*)
Admitted.

     *)

Lemma resource_decay_matchfunspec {b phi phi' g Gamma} :
  resource_decay b phi phi' ->
  matchfunspec g Gamma phi ->
  matchfunspec g Gamma phi'.
Proof.
  intros RD M.
  unfold matchfunspec in *.
  intros b0 fs psi' necr' FUN.
  specialize (M b0 fs phi ltac:(constructor 2)).
  apply (hereditary_necR necr').
  { clear.
    intros phi phi' A (id & hg & hgam); exists id; split; auto. }
  apply (anti_hereditary_necR necr') in FUN; swap 1 2.
  { intros x y a. apply anti_hereditary_func_at', a. }
  apply (resource_decay_func_at'_inv RD) in FUN.
  autospec M.
  destruct M as (id & Hg & HGamma).
  exists id; split; auto.
Qed.

(** About lock_coherence *)

Lemma resource_decay_lock_coherence {b phi phi' lset m} :
  resource_decay b phi phi' ->
  lockSet_block_bound lset b ->
  (forall l p, AMap.find l lset = Some (Some p) -> level p = level phi) ->
  lock_coherence lset phi m ->
  lock_coherence (AMap.map (Coqlib.option_map (age_to (level phi'))) lset) phi' m.
Proof.
  intros rd BOUND SAMELEV LC loc; pose proof rd as rd'; destruct rd' as [L RD].
  specialize (LC loc).
  specialize (RD loc).
  rewrite AMap_find_map_option_map.
  destruct (AMap.find loc lset)
    as [[unlockedphi | ] | ] eqn:Efind;
    simpl option_map; cbv iota beta; swap 1 3.
  - rewrite <-isLKCT_rewrite.
    rewrite <-isLKCT_rewrite in LC.
    intros sh sh' z pp.
    destruct RD as [NN [R|[R|[[P [v R]]|R]]]].
    + split; intros E; rewrite E in *;
        destruct (phi @ loc); try destruct k; simpl in R; try discriminate;
          [ refine (proj1 (LC _ _ _ _) _); eauto
          | refine (proj2 (LC _ _ _ _) _); eauto ].
    + destruct R as (sh'' & v & v' & E & E'). split; congruence.
    + split; congruence.
    + destruct R as (sh'' & v & v' & R). split; congruence.
  
  - assert (fst loc < b)%positive.
    { apply BOUND.
      rewrite Efind.
      constructor. }
    destruct LC as (dry & sh & R & lk); split; auto.
    eapply resource_decay_LK_at in lk; eauto.
  
  - assert (fst loc < b)%positive.
    { apply BOUND.
      rewrite Efind.
      constructor. }
    destruct LC as (dry & sh & R & lk & sat); split; auto.
    exists sh, (approx (level phi') R); split.
    + eapply resource_decay_LK_at' in lk; eauto.
    + match goal with |- ?a \/ ?b => cut (~b -> a) end.
      { destruct (level phi'); auto. } intros Nz.
      split.
      * rewrite level_age_by.
        rewrite level_age_to.
        -- omega.
        -- apply SAMELEV in Efind.
           eauto with *.
      * destruct sat as [sat | ?]; [ | omega ].
        unfold age_to.
        rewrite age_by_age_by.
        rewrite plus_comm.
        rewrite <-age_by_age_by.
        apply age_by_ind.
        { destruct R as [p h]. apply h. }
        apply sat.
Qed.

Lemma lock_coherence_age_to lset Phi m n :
  lock_coherence lset Phi m ->
  lock_coherence (AMap.map (option_map (age_to n)) lset) Phi m.
Proof.
  intros C loc; specialize (C loc).
  rewrite AMap_find_map_option_map.
  destruct (AMap.find (elt:=option rmap) loc lset) as [[o|]|];
    simpl option_map;
    cbv iota beta.
  all:try solve [intuition].
  destruct C as [B C]; split; auto. clear B.
  destruct C as (sh & R & lk & sat).
  exists sh, R; split. eauto.
  destruct sat as [sat|?]; auto. left.
  unfold age_to.
  rewrite age_by_age_by, plus_comm, <-age_by_age_by.
  revert sat.
  apply age_by_ind.
  apply (proj2_sig R).
Qed.

Lemma load_restrPermMap m tp Phi b ofs m_any
  (compat : mem_compatible_with tp m Phi) :
  lock_coherence (lset tp) Phi m_any ->
  AMap.find (elt:=option rmap) (b, ofs) (lset tp) <> None ->
  Mem.load
    Mint32
    (restrPermMap (mem_compatible_locks_ltwritable (mem_compatible_forget compat)))
    b ofs =
  Some (decode_val Mint32 (Mem.getN (size_chunk_nat Mint32) ofs (Mem.mem_contents m) !! b)).
Proof.
  intros lc e.
  Transparent Mem.load.
  unfold Mem.load in *.
  if_tac; auto.
  exfalso.
  apply H.
  eapply Mem.valid_access_implies.
  eapply lset_valid_access; eauto.
  constructor.
Qed.

Lemma lock_coh_bound tp m Phi
      (compat : mem_compatible_with tp m Phi)
      (coh : lock_coherence' tp Phi m compat) :
  lockSet_block_bound (lset tp) (Mem.nextblock m).
Proof.
  intros loc find.
  specialize (coh loc).
  destruct (AMap.find (elt:=option rmap) loc (lset tp)) as [o|]; [ | inversion find ].
  match goal with |- (?a < ?b)%positive => assert (D : (a >= b \/ a < b)%positive) by (zify; omega) end.
  destruct D as [D|D]; auto. exfalso.
  assert (AT : exists (sh : Share.t) (R : pred rmap), (LK_at R sh loc) Phi). {
    destruct o.
    - destruct coh as [LOAD (sh' & R' & lk & sat)]; eauto.
    - destruct coh as [LOAD (sh' & R' & lk)]; eauto.
  }
  clear coh.
  destruct AT as (sh & R & AT).
  destruct compat.
  destruct all_cohere0.
  specialize (all_coh0 loc D).
  specialize (AT loc).
  destruct loc as (b, ofs).
  simpl in AT.
  if_tac in AT. 2:range_tac.
  if_tac in AT. 2:tauto.
  rewrite all_coh0 in AT.
  destruct AT.
  congruence.
Qed.

Lemma same_except_cur_jm_ tp m phi i cnti compat :
  same_except_cur m (m_dry (@jm_ tp m phi i cnti compat)).
Proof.
  repeat split.
  extensionality loc.
  apply juicyRestrictMax.
Qed.

Lemma resource_decay_join_identity b phi phi' e e' :
  resource_decay b phi phi' ->
  sepalg.joins phi e ->
  sepalg.joins phi' e' ->
  identity e ->
  identity e' ->
  e' = age_to (level phi') e.
Proof.
  intros rd j j' i i'.
  apply rmap_ext.
  - apply rmap_join_eq_level in j.
    apply rmap_join_eq_level in j'.
    destruct rd as (lev, rd).
    rewrite level_age_to; eauto with *.
  - intros l.
    rewrite age_to_resource_at.
    apply resource_at_identity with (loc := l) in i.
    apply resource_at_identity with (loc := l) in i'.
    apply empty_NO in i.
    apply empty_NO in i'.
    destruct j as (a & j).
    destruct j' as (a' & j').
    apply resource_at_join with (loc := l) in j.
    apply resource_at_join with (loc := l) in j'.
    unfold compcert_rmaps.R.AV.address in *.
    destruct i as [E | (k & pp & E)], i' as [E' | (k' & pp' & E')]; rewrite E, E' in *.
    + reflexivity.
    + inv j'.
      pose proof resource_decay_PURE_inv rd as I.
      repeat autospec I.
      breakhyps.
      rewr (phi @ l) in j.
      inv j.
    + inv j.
      pose proof resource_decay_PURE rd as I.
      repeat autospec I.
      rewr (phi' @ l) in j'.
      inv j'.
    + inv j.
      pose proof resource_decay_PURE rd as I.
      specialize (I l k pp ltac:(auto)).
      rewr (phi' @ l) in j'.
      inv j'.
      reflexivity.
Qed.

Lemma jsafeN_downward {Z} {Jspec : juicy_ext_spec Z} {ge n z c jm} :
  jsafeN Jspec ge (S n) z c jm ->
  jsafeN Jspec ge n z c jm.
Proof.
  apply safe_downward1.
Qed.

Lemma mem_cohere'_store m tp m' b ofs i Phi :
  forall Hcmpt : mem_compatible tp m,
    lockRes tp (b, Int.intval ofs) <> None ->
    Mem.store
      Mint32 (restrPermMap (mem_compatible_locks_ltwritable Hcmpt))
      b (Int.intval ofs) (Vint i) = Some m' ->
    mem_compatible_with tp m Phi (* redundant with Hcmpt, but easier *) ->
    mem_cohere' m' Phi.
Proof.
  intros Hcmpt lock Hstore compat.
  pose proof store_outside' _ _ _ _ _ _ Hstore as SO.
  destruct compat as [J MC LW JL LJ].
  destruct MC as [Co Ac Ma N].
  split.
  - intros sh sh' v (b', ofs') pp E.
    specialize (Co sh sh' v (b', ofs') pp E).
    destruct Co as [<- ->]. split; auto.
    destruct SO as (Co1 & A1 & N1).
    specialize (Co1 b' ofs').
    destruct Co1 as [In|Out].
    + exfalso (* because there is no lock at (b', ofs') *).
      specialize (LJ (b, Int.intval ofs)).
      cleanup.
      destruct (AMap.find (elt:=option rmap) (b, Int.intval ofs) (lset tp)).
      2:tauto.
      autospec LJ.
      destruct LJ as (sh1 & sh1' & pp & EPhi).
      destruct In as (<-, In).
      destruct (eq_dec ofs' (Int.intval ofs)).
      * subst ofs'.
        congruence.
      * pose (ii := (ofs' - Int.intval ofs)%Z).
        assert (Hii : (0 < ii < LKSIZE)%Z).
        { unfold ii; split. omega.
          unfold LKSIZE, LKCHUNK, align_chunk, size_chunk in *.
          omega. }
        pose proof rmap_valid_e1 Phi b (Int.intval ofs) _ _ Hii sh1' as H.
        assert_specialize H.
        { rewrite EPhi. reflexivity. }
        replace (Int.intval ofs + ii)%Z with ofs' in H by (unfold ii; omega).
        rewrite E in H. simpl in H. congruence.
        
    + rewrite <-Out.
      rewrite restrPermMap_contents.
      auto.
      
  - intros loc.
    replace (max_access_at m' loc)
    with (max_access_at
            (restrPermMap (mem_compatible_locks_ltwritable Hcmpt)) loc)
    ; swap 1 2.
    { unfold max_access_at in *.
      destruct SO as (_ & -> & _). reflexivity. }
    clear SO.
    rewrite restrPermMap_max.
    apply Ac.
    
  - cut (max_access_cohere (restrPermMap (mem_compatible_locks_ltwritable Hcmpt)) Phi).
    { unfold max_access_cohere in *.
      unfold max_access_at in *.
      destruct SO as (_ & <- & <-). auto. }
    intros loc; specialize (Ma loc).
    rewrite restrPermMap_max. auto.

  - unfold alloc_cohere in *.
    destruct SO as (_ & _ & <-). auto.
Qed.

Section Simulation.
  Variables
    (CS : compspecs)
    (ext_link : string -> ident)
    (ext_link_inj : forall s1 s2, ext_link s1 = ext_link s2 -> s1 = s2).

  Definition Jspec' := (@OK_spec (Concurrent_Espec unit CS ext_link)).
  
  Open Scope string_scope.
  
  Lemma Jspec'_juicy_mem_equiv : ext_spec_stable juicy_mem_equiv (JE_spec _ Jspec').
  Proof.
    split; [ | easy ].
    intros e x b tl vl z m1 m2 E.
    
    unfold Jspec' in *.
    destruct e as [name sg | | | | | | | | | | | ].
    all: try (exfalso; simpl in x; do 5 (if_tac in x; [ discriminate | ]); apply x).
    
    (* dependent destruction *)
    revert x.
    
    (** * the case of acquire *)
    funspec_destruct "acquire".
    rewrite (proj2 E).
    exact (fun x y => y).
    
    (** * the case of release *)
    funspec_destruct "release".
    rewrite (proj2 E).
    exact (fun x y => y).
    
    (** * the case of makelock *)
    funspec_destruct "makelock".
    rewrite (proj2 E).
    exact (fun x y => y).
    
    (** * the case of freelock *)
    funspec_destruct "freelock".
    rewrite (proj2 E).
    exact (fun x y => y).
    
    (** * the case of spawn *)
    funspec_destruct "spawn".
    rewrite (proj2 E).
    exact (fun x y => y).
    
    (** * no more cases *)
    simpl; tauto.
  Qed.
  
  Lemma Jspec'_hered : ext_spec_stable age (JE_spec _ Jspec').
  Proof.
    split; [ | easy ].
    intros e x b tl vl z m1 m2 A.
    
    unfold Jspec' in *.
    destruct e as [name sg | | | | | | | | | | | ].
    all: try (exfalso; simpl in x; do 5 (if_tac in x; [ discriminate | ]); apply x).
    
    apply age_jm_phi in A.
    
    (* dependent destruction *)
    revert x.
    1:funspec_destruct "acquire".
    2:funspec_destruct "release".
    3:funspec_destruct "makelock".
    4:funspec_destruct "freelock".
    5:funspec_destruct "spawn".
    
    all:intros.
    all:breakhyps.
    all:agejoinhyp.
    all:breakhyps.
    all:agehyps.
    all:agehyps.
    all:eauto.
  Qed.
  
  (* Preservation lemma for core steps *)  
  Lemma invariant_thread_step
        {Z} (Jspec : juicy_ext_spec Z) Gamma
        n m ge i sch tp Phi ci ci' jmi'
        (Stable : ext_spec_stable age Jspec)
        (Stable' : ext_spec_stable juicy_mem_equiv Jspec)
        (gam : matchfunspec (filter_genv ge) Gamma Phi)
        (compat : mem_compatible_with tp m Phi)
        (En : level Phi = S n)
        (lock_bound : lockSet_block_bound (ThreadPool.lset tp) (Mem.nextblock m))
        (sparse : lock_sparsity (lset tp))
        (lock_coh : lock_coherence' tp Phi m compat)
        (safety : threads_safety Jspec m ge tp Phi compat (S n))
        (wellformed : threads_wellformed tp)
        (unique : unique_Krun tp (i :: sch))
        (cnti : containsThread tp i)
        (stepi : corestep (juicy_core_sem cl_core_sem) ge ci (personal_mem cnti (mem_compatible_forget compat)) ci' jmi')
        (safei' : forall ora : Z, jsafeN Jspec ge n ora ci' jmi')
        (Eci : getThreadC cnti = Krun ci)
        (tp' := age_tp_to (level jmi') tp)
        (tp'' := @updThread i tp' (cnt_age' cnti) (Krun ci') (m_phi jmi') : ThreadPool.t)
        (cm' := (m_dry jmi', ge, (i :: sch, tp''))) :
    state_invariant Jspec Gamma n cm'.
  Proof.
    (** * Two steps : [x] -> [x'] -> [x'']
          1. we age [x] to get [x'], the level decreasing
          2. we update the thread to  get [x'']
     *)
    destruct compat as [J AC LW LJ JL] eqn:Ecompat. 
    rewrite <-Ecompat in *.
    pose proof J as J_; move J_ before J.
    rewrite join_all_joinlist in J_.
    pose proof J_ as J__.
    rewrite maps_getthread with (cnti := cnti) in J__.
    destruct J__ as (ext & Hext & Jext).
    assert (Eni : level (jm_ cnti compat) = S n). {
      rewrite <-En, level_juice_level_phi.
      eapply rmap_join_sub_eq_level.
      exists ext; auto.
    }
    
    (** * Getting new global rmap (Phi'') with smaller level [n] *)
    assert (B : rmap_bound (Mem.nextblock m) Phi) by apply compat.
    destruct (resource_decay_join_all (Krun ci') B (proj2 stepi) J)
      as [Phi'' [J'' [RD L]]].
    rewrite join_all_joinlist in J''.
    assert (Eni'' : level (m_phi jmi') = n). {
      clear -stepi Eni.
      rewrite <-level_juice_level_phi.
      cut (S (level jmi') = S n); [ congruence | ].
      destruct stepi as [_ [_ <-]].
      apply Eni.
    }
    unfold LocksAndResources.res in *.
    pose proof eq_refl tp' as Etp'.
    unfold tp' at 2 in Etp'.
    move Etp' before tp'.
    rewrite level_juice_level_phi, Eni'' in Etp'.
    assert (En'' : level Phi'' = n). {
      rewrite <-Eni''.
      symmetry; apply rmap_join_sub_eq_level.
      rewrite maps_updthread in J''.
      destruct J'' as (r & _ & j).
      exists r; auto.
    }
    
    (** * First, age the whole machine *)
    pose proof J_ as J'.
    unshelve eapply @joinlist_age_to with (n := n) in J'.
    (* auto with *. (* TODO please report -- but hard to reproduce *) *)
    all: hnf.
    all: [> refine ag_rmap |  | refine Age_rmap | refine Perm_rmap ].
    
    (** * Then relate this machine with the new one through the remaining maps *)
    rewrite (maps_getthread i tp cnti) in J'.
    rewrite maps_updthread in J''.
    pose proof J' as J'_. destruct J'_ as (ext' & Hext' & Jext').
    rewrite maps_age_to, all_but_map in J''.
    pose proof J'' as J''_. destruct J''_ as (ext'' & Hext'' & Jext'').
    rewrite Eni'' in *.
    assert (Eext'' : ext'' = age_to n ext). {
      destruct (coqlib3.nil_or_non_nil (map (age_to n) (all_but i (maps tp)))) as [N|N]; swap 1 2.
      - (* Uniqueness of [ext] : when the rest is not empty *)
        eapply @joinlist_age_to with (n := n) in Hext.
        all: [> | now apply Age_rmap | now apply Perm_rmap ].
        unshelve eapply (joinlist_inj _ _ _ _ Hext'' Hext).
        apply N.
      - (* when the list is empty, we know that ext (and hence [age_to
        .. ext]) and ext' are identity, and they join with something
        that have the same PURE *)
        rewrite N in Hext''. simpl in Hext''.
        rewrite <-Eni''.
        eapply resource_decay_join_identity.
        + apply (proj2 stepi).
        + exists Phi. apply Jext.
        + exists Phi''. apply Jext''.
        + change (joinlist nil ext). exact_eq Hext. f_equal.
          revert N.
          destruct (maps tp) as [|? [|]]; destruct i; simpl; congruence || auto.
        + change (joinlist nil ext''). apply Hext''.
    }
    subst ext''.
    
    assert (compat_ : mem_compatible_with tp (m_dry (jm_ cnti compat)) Phi).
    { apply mem_compatible_with_same_except_cur with (m := m); auto.
      apply same_except_cur_jm_. }
    
    assert (compat' : mem_compatible_with tp' (m_dry (jm_ cnti compat)) (age_to n Phi)).
    { unfold tp'.
      rewrite level_juice_level_phi, Eni''.
      apply mem_compatible_with_age. auto. }
    
    assert (compat'' : mem_compatible_with tp'' (m_dry jmi') Phi'').
    {
      unfold tp''.
      constructor.
      
      - (* join_all (proved in lemma) *)
        rewrite join_all_joinlist.
        rewrite maps_updthread.
        unfold tp'. rewrite maps_age_to, all_but_map.
        exact_eq J''; repeat f_equal.
        auto.
      
      - (* cohere *)
        pose proof compat_ as c. destruct c as [_ MC _ _ _].
        destruct (mem_cohere_step
             ci ci' (jm_ cnti compat) jmi'
             Phi ext ge MC Jext stepi) as (Phi''_ & J''_ & MC''_).
        exact_eq MC''_.
        f_equal.
        rewrite Eni'' in J''_.
        eapply join_eq; eauto.
      
      - (* lockSet_Writable *)
        simpl.
        clear -LW stepi lock_coh lock_bound compat_.
        destruct stepi as [step _]. fold (jm_ cnti compat) in step.
        intros b ofs IN.
        unfold tp' in IN.
        rewrite lset_age_tp_to in IN.
        rewrite isSome_find_map in IN.
        specialize (LW b ofs IN).
        intros ofs0 interval.
        
        (* the juicy memory doesn't help much because we care about Max
        here. There are several cases were no permission change, the
        only cases where they do are:
        (1) call_internal (alloc_variables m -> m1)
        (2) return (free_list m -> m')
        in the end, (1) cannot hurt because there is already
        something, but maybe things have returned?
         *)
        
        set (mi := m_dry (jm_ cnti compat)).
        fold mi in step.
        (* state that the Cur [Nonempty] using the juice and the
             fact that this is a lock *)
        assert (CurN : (Mem.mem_access mi) !! b ofs0 Cur = Some Nonempty
                       \/ (Mem.mem_access mi) !! b ofs0 Cur = None).
        {
          pose proof juicyRestrictCurEq as H.
          unfold access_at in H.
          replace b with (fst (b, ofs0)) by reflexivity.
          replace ofs0 with (snd (b, ofs0)) by reflexivity.
          unfold mi.
          destruct compat_ as [_ MC _ _ _].
          destruct MC as [_ AC _ _].
          unfold jm_, personal_mem, personal_mem'; simpl m_dry.
          rewrite (H _ _  _ (b, ofs0)).
          cut (Mem.perm_order'' (Some Nonempty) (perm_of_res (ThreadPool.getThreadR cnti @ (b, ofs0)))). {
            destruct (perm_of_res (ThreadPool.getThreadR cnti @ (b,ofs0))) as [[]|]; simpl.
            all:intros po; inversion po; subst; eauto.
          }
          clear -compat IN interval lock_coh lock_bound.
          apply po_trans with (perm_of_res (Phi @ (b, ofs0))).
          - destruct compat.
            specialize (lock_coh (b, ofs)).
            assert (lk : exists (sh : Share.t) (R : pred rmap), (LK_at R sh (b, ofs)) Phi). {
              destruct (AMap.find (elt:=option rmap) (b, ofs) (ThreadPool.lset tp)) as [[lockphi|]|].
              - destruct lock_coh as [_ [sh [R [lk _]]]].
                now eexists _, _; apply lk.
              - destruct lock_coh as [_ [sh [R lk]]].
                now eexists _, _; apply lk.
              - discriminate.
            }
            destruct lk as (sh & R & lk).
            specialize (lk (b, ofs0)). simpl in lk.
            assert (adr_range (b, ofs) lock_size (b, ofs0))
              by apply interval_adr_range, interval.
            if_tac in lk; [ | tauto ].
            if_tac in lk.
            + injection H1 as <-.
              destruct lk as [p ->].
              simpl.
              constructor.
            + destruct lk as [p ->].
              simpl.
              constructor.
          - cut (join_sub (ThreadPool.getThreadR cnti @ (b, ofs0)) (Phi @ (b, ofs0))).
            + apply po_join_sub.
            + apply resource_at_join_sub.
              eapply compatible_threadRes_sub.
              apply compat.
        }
        
        apply cl_step_decay in step.
        pose proof step b ofs0 as D.
        assert (Emi: (Mem.mem_access mi) !! b ofs0 Max = (Mem.mem_access m) !! b ofs0 Max).
        {
          pose proof juicyRestrictMax (acc_coh (thread_mem_compatible (mem_compatible_forget compat) cnti)) (b, ofs0).
          unfold max_access_at, access_at in *.
          simpl fst in H; simpl snd in H.
          rewrite H.
          reflexivity.
        }
        
        destruct (Maps.PMap.get b (Mem.mem_access m) ofs0 Max)
          as [ [ | | | ] | ] eqn:Emax;
          try solve [inversion LW].
        + (* Max = Freeable *)
          
          (* concluding using [decay] *)
          revert step CurN.
          clearbody mi.
          generalize (m_dry jmi'); intros mi'.
          clear -Emi. intros D [NE|NE].
          * replace ((Mem.mem_access mi') !! b ofs0 Max) with (Some Freeable). now constructor.
            symmetry.
            destruct (D b ofs0) as [A B].
            destruct (valid_block_dec mi b) as [v|n].
            -- autospec B.
               destruct B as [B|B].
               ++ destruct (B Cur). congruence.
               ++ specialize (B Max). congruence.
            -- pose proof Mem.nextblock_noaccess mi b ofs0 Max n.
               congruence.
          * replace ((Mem.mem_access mi') !! b ofs0 Max) with (Some Freeable). now constructor.
            symmetry.
            destruct (D b ofs0) as [A B].
            destruct (valid_block_dec mi b) as [v|n].
            -- autospec B.
               destruct B as [B|B].
               ++ destruct (B Cur); congruence.
               ++ specialize (B Max). congruence.
            -- pose proof Mem.nextblock_noaccess mi b ofs0 Max n.
               congruence.
        
        + (* Max = writable : must be writable after, because unchanged using "decay" *)
          assert (Same: (Mem.mem_access m) !! b ofs0 Max = (Mem.mem_access mi) !! b ofs0 Max) by congruence.
          revert step Emi Same.
          generalize (m_dry jmi').
          generalize (juicyRestrict (acc_coh (thread_mem_compatible (mem_compatible_forget compat) cnti))).
          clear.
          intros m0 m1 D Emi Same.
          match goal with |- _ ?a ?b => cut (a = b) end.
          { intros ->; apply po_refl. }
          specialize (D b ofs0).
          destruct D as [A B].
          destruct (valid_block_dec mi b) as [v|n].
          * autospec B.
            destruct B as [B|B].
            -- destruct (B Max); congruence.
            -- specialize (B Max). congruence.
          * pose proof Mem.nextblock_noaccess m b ofs0 Max n.
            congruence.
        
        + (* Max = Readable : impossible because Max >= Writable  *)
          autospec LW.
          autospec LW.
          rewrite Emax in LW.
          inversion LW.
        
        + (* Max = Nonempty : impossible because Max >= Writable  *)
          autospec LW.
          autospec LW.
          rewrite Emax in LW.
          inversion LW.
        
        + (* Max = none : impossible because Max >= Writable  *)
          autospec LW.
          autospec LW.
          rewrite Emax in LW.
          inversion LW.
      
      - (* juicyLocks_in_lockSet *)
        eapply same_locks_juicyLocks_in_lockSet.
        + eapply resource_decay_same_locks.
          apply RD.
        + simpl.
          clear -LJ.
          intros loc sh psh P z H.
          unfold tp'.
          rewrite lset_age_tp_to.
          rewrite isSome_find_map.
          eapply LJ; eauto.
        
      - (* lockSet_in_juicyLocks *)
        eapply resource_decay_lockSet_in_juicyLocks.
        + eassumption.
        + simpl.
          apply lockSet_Writable_lockSet_block_bound.
          clear -LW.
          intros b ofs.
          unfold tp'; rewrite lset_age_tp_to.
          rewrite isSome_find_map.
          apply LW.
        
        + clear -JL.
          unfold tp'.
          intros addr; simpl.
          unfold tp'; rewrite lset_age_tp_to.
          rewrite isSome_find_map.
          apply JL.
    }
    (* end of proving mem_compatible_with *)
    
    (* Now that mem_compatible_with is established, we move on to the
       invariant. Two important parts:

       1) lock coherence is maintained, because the thread step could
          not affect locks in either kinds of memories
       
       2) safety is maintained: for thread #i (who just took a step),
          safety of the new state follows from safety of the old
          state. For thread #j != #i, we need to prove that the new
          memory is [juicy_mem_equiv] to the old one, in the sense
          that wherever [Cur] was readable the values have not
          changed.
    *)
    
    apply state_invariant_c with (PHI := Phi'') (mcompat := compat''); auto.
    - (* matchfunspecs *)
      eapply resource_decay_matchfunspec; eauto.
    
    - (* lock coherence: own rmap has changed, but we prove it did not affect locks *)
      unfold tp''; simpl.
      unfold tp'; simpl.
      apply lock_sparsity_age_to. auto.
    
    - (* lock coherence: own rmap has changed, but we prove it did not affect locks *)
      unfold lock_coherence', tp''; simpl lset.

      (* replacing level (m_phi jmi') with level Phi' ... *)
      assert (level (m_phi jmi') = level Phi'') by congruence.
      cut (lock_coherence
            (AMap.map (option_map (age_to (level Phi''))) (lset tp)) Phi''
            (restrPermMap (mem_compatible_locks_ltwritable (mem_compatible_forget compat'')))).
      { intros A; exact_eq A.
        f_equal. unfold tp'; rewrite lset_age_tp_to.
        f_equal. f_equal. f_equal. rewrite level_juice_level_phi; auto. }
      (* done replacing *)
      
      (* operations on the lset: nothing happened *)
      apply (resource_decay_lock_coherence RD).
      { auto. }
      { intros. eapply join_all_level_lset; eauto. }
      
      clear -lock_coh lock_bound stepi.
      
      (* what's important: lock values couldn't change during a corestep *)
      assert
        (SA' :
           forall loc,
             AMap.find (elt:=option rmap) loc (lset tp) <> None ->
             load_at (restrPermMap (mem_compatible_locks_ltwritable (mem_compatible_forget compat))) loc =
             load_at (restrPermMap (mem_compatible_locks_ltwritable (mem_compatible_forget compat''))) loc).
      {
        destruct stepi as [step RD].
        unfold cl_core_sem in *.
        simpl in step.
        pose proof cl_step_decay _ _ _ _ _ step as D.
        intros (b, ofs) islock.
        pose proof juicyRestrictMax (acc_coh (thread_mem_compatible (mem_compatible_forget compat) cnti)) (b, ofs).
        pose proof juicyRestrictContents (acc_coh (thread_mem_compatible (mem_compatible_forget compat) cnti)) (b, ofs).
        unfold load_at in *; simpl.
        set (W  := mem_compatible_locks_ltwritable (mem_compatible_forget compat )).
        set (W' := mem_compatible_locks_ltwritable (mem_compatible_forget compat'')).
        pose proof restrPermMap_Cur W as RW.
        pose proof restrPermMap_Cur W' as RW'.
        pose proof restrPermMap_contents W as CW.
        pose proof restrPermMap_contents W' as CW'.
        Transparent Mem.load.
        unfold Mem.load in *.
        destruct (Mem.valid_access_dec (restrPermMap W) Mint32 b ofs Readable) as [r|n]; swap 1 2.
        
        { (* can't be not readable *)
          destruct n.
          apply Mem.valid_access_implies with Writable.
          - eapply lset_valid_access; eauto.
          - constructor.
        }
        
        destruct (Mem.valid_access_dec (restrPermMap W') Mint32 b ofs Readable) as [r'|n']; swap 1 2.
        { (* can't be not readable *)
          destruct n'.
          split.
          - apply Mem.range_perm_implies with Writable.
            + eapply lset_range_perm; eauto.
              unfold tp''; simpl.
              unfold tp'; rewrite lset_age_tp_to.
              rewrite AMap_find_map_option_map.
              destruct (AMap.find (elt:=option rmap) (b, ofs) (lset tp)).
              * discriminate.
              * tauto.
            + constructor.
          - (* basic alignment *)
            eapply lock_coherence_align; eauto.
        }
        
        f_equal.
        f_equal.
        apply Mem.getN_exten.
        intros ofs0 interval.
        eapply equal_f with (b, ofs0) in CW.
        eapply equal_f with (b, ofs0) in CW'.
        unfold contents_at in CW, CW'.
        simpl fst in CW, CW'.
        simpl snd in CW, CW'.
        rewrite CW, CW'.
        pose proof cl_step_unchanged_on _ _ _ _ _ b ofs0 step as REW.
        rewrite <- REW.
        - reflexivity.
        - unfold Mem.valid_block in *.
          simpl.
          apply (lock_bound (b, ofs)).
          destruct (AMap.find (elt:=option rmap) (b, ofs) (lset tp)). reflexivity. tauto.
        - pose proof juicyRestrictCurEq (acc_coh (thread_mem_compatible (mem_compatible_forget compat) cnti)) (b, ofs0) as h.
          unfold access_at in *.
          simpl fst in h; simpl snd in h.
          unfold Mem.perm in *.
          rewrite h.
          cut (Mem.perm_order'' (Some Nonempty) (perm_of_res (getThreadR cnti @ (b, ofs0)))).
          { destruct (perm_of_res (getThreadR cnti @ (b, ofs0))); intros A B.
            all: inversion A; subst; inversion B; subst. }
          apply po_trans with (perm_of_res (Phi @ (b, ofs0))); swap 1 2.
          + eapply po_join_sub.
            apply resource_at_join_sub.
            eapply compatible_threadRes_sub.
            apply compat.
          + clear -lock_coh islock interval.
            (* todo make lemma out of this *)
            specialize (lock_coh (b, ofs)).
            assert (lk : exists sh R, (LK_at R sh (b, ofs)) Phi). {
              destruct (AMap.find (elt:=option rmap) (b, ofs) (lset tp)) as [[|]|].
              - destruct lock_coh as [_ (? & ? & ? & ?)]; eauto.
              - destruct lock_coh as [_ (? & ? & ?)]; eauto.
              - tauto.
            }
            destruct lk as (R & sh & lk).
            specialize (lk (b, ofs0)).
            simpl in lk.
            assert (adr_range (b, ofs) lock_size (b, ofs0))
              by apply interval_adr_range, interval.
            if_tac in lk; [|tauto].
            if_tac in lk.
            * destruct lk as [pp ->]. simpl. constructor.
            * destruct lk as [pp ->]. simpl. constructor.
      }
      (* end of proof of: lock values couldn't change during a corestep *)
      
      unfold lock_coherence' in *.
      intros loc; specialize (lock_coh loc). specialize (SA' loc).
      destruct (AMap.find (elt:=option rmap) loc (lset tp)) as [[lockphi|]|].
      + destruct lock_coh as [COH ?]; split; [ | easy ].
        rewrite <-COH; rewrite SA'; auto.
        congruence.
      + destruct lock_coh as [COH ?]; split; [ | easy ].
        rewrite <-COH; rewrite SA'; auto.
        congruence.
      + easy.
    
    - (* safety *)
      intros j cntj ora.
      destruct (eq_dec i j) as [e|n0].
      + subst j.
        replace (Machine.getThreadC cntj) with (Krun ci').
        * specialize (safei' ora).
          exact_eq safei'.
          f_equal.
          unfold jm_ in *.
          {
            apply juicy_mem_ext.
            - unfold personal_mem in *.
              simpl.
              match goal with |- _ = _ ?c => set (coh := c) end.
              apply mem_ext.
              
              + reflexivity.
              
              + rewrite juicyRestrictCur_unchanged.
                * reflexivity.
                * intros.
                  unfold "oo".
                  rewrite eqtype_refl.
                  unfold tp'; simpl.
                  unfold access_at in *.
                  destruct jmi'; simpl.
                  eauto.
              
              + reflexivity.
            
            - simpl.
              unfold "oo".
              rewrite eqtype_refl.
              auto.
          }
          
        * (* assert (REW: tp'' = (age_tp_to (level (m_phi jmi')) tp')) by reflexivity. *)
          (* clearbody tp''. *)
          subst tp''.
          rewrite gssThreadCode. auto.
      
      + unfold tp'' at 1.
        unfold tp' at 1.
        unshelve erewrite gsoThreadCode; auto.
        
        clear Ecompat Hext' Hext'' J'' Jext Jext' Hext RD J' LW LJ JL.
        
        (** * Bring other thread #j's memory up to current #i's level *)
        assert (cntj' : Machine.containsThread tp j). {
          unfold tp'', tp' in cntj.
          apply cntUpdate' in cntj.
          rewrite <-cnt_age in cntj.
          apply cntj.
        }
        pose (jmj' := age_to (level (m_phi jmi')) (@jm_ tp m Phi j cntj' compat)).
        
        (** * #j's memory is equivalent to the one it will be started in *)
        assert (E : juicy_mem_equiv  jmj' (jm_ cntj compat'')). {
          split.
          - unfold jmj'.
            rewrite m_dry_age_to.
            unfold jm_.
            unfold tp'' in compat''.
            pose proof
                 jstep_preserves_mem_equiv_on_other_threads
                 m ge i j tp ci ci' jmi' n0
                 (mem_compatible_forget compat)
                 cnti cntj' stepi
                 (mem_compatible_forget compat'')
              as H.
            exact_eq H.
            repeat f_equal.
            apply proof_irr.
          
          - unfold jmj'.
            unfold jm_ in *.
            rewrite m_phi_age_to.
            change (age_to (level (m_phi jmi')) (getThreadR cntj')
                    = getThreadR cntj).
            unfold tp'', tp'.
            unshelve erewrite gsoThreadRes; auto.
            unshelve erewrite getThreadR_age. auto.
            reflexivity.
        }
        
        unshelve erewrite <-gtc_age; auto.
        pose proof safety _ cntj' ora as safej.
        
        (* factoring all Krun / Kblocked / Kresume / Kinit cases in this one assert *)
        assert (forall c, jsafeN Jspec ge (S n) ora c (jm_ cntj' compat) ->
                     jsafeN Jspec ge n ora c (jm_ cntj compat'')) as othersafe.
        {
          intros c s.
          apply jsafeN_downward in s.
          apply jsafeN_age_to with (l := n) in s; auto.
          refine (jsafeN_mem_equiv _ _ s); auto.
          exact_eq E; f_equal.
          unfold jmj'; f_equal. auto.
        }
  
        destruct (@getThreadC j tp cntj') as [c | c | c v | v v0]; solve [auto].
    
    - (* wellformedness *)
      intros j cntj.
      unfold tp'', tp'.
      destruct (eq_dec i j) as [ <- | ij].
      + unshelve erewrite gssThreadCode; auto.
      + unshelve erewrite gsoThreadCode; auto.
        specialize (wellformed j). clear -wellformed.
        assert_specialize wellformed by (destruct tp; auto).
        unshelve erewrite <-gtc_age; auto.
    
    - (* uniqueness *)
      intros notalone j cntj q Ecj.
      hnf in unique.
      assert_specialize unique by (destruct tp; apply notalone).
      specialize (unique j).
      destruct (eq_dec i j) as [ <- | ij].
      + apply unique with (cnti := cnti) (q := ci); eauto.
      + assert_specialize unique by (destruct tp; auto).
        apply unique with (q := q); eauto.
        exact_eq Ecj. f_equal.
        unfold tp'',  tp'.
        unshelve erewrite gsoThreadCode; auto.
        unshelve erewrite <-gtc_age; auto.
  Qed.
  
  Lemma restrPermMap_mem_contents p' m (Hlt: permMapLt p' (getMaxPerm m)): 
    Mem.mem_contents (restrPermMap Hlt) = Mem.mem_contents m.
  Proof.
    reflexivity.
  Qed.
  
  Lemma islock_valid_access tp m b ofs p
        (compat : mem_compatible tp m) :
    (4 | ofs) ->
    lockRes tp (b, ofs) <> None ->
    p <> Freeable ->
    Mem.valid_access
      (restrPermMap
         (mem_compatible_locks_ltwritable compat))
      Mint32 b ofs p.
  Proof.
    intros div islock NE.
    eapply Mem.valid_access_implies with (p1 := Writable).
    2:destruct p; constructor || tauto.
    pose proof lset_range_perm.
    do 6 autospec H.
    split; auto.
  Qed.
  
  
  Ltac jmstep_inv :=
    match goal with
    | H : JuicyMachine.start_thread _ _ _ |- _ => inversion H
    | H : JuicyMachine.resume_thread _ _  |- _ => inversion H
    | H : threadStep _ _ _ _ _ _          |- _ => inversion H
    | H : JuicyMachine.suspend_thread _ _ |- _ => inversion H
    | H : syncStep _ _ _ _ _ _            |- _ => inversion H
    | H : threadHalted _                  |- _ => inversion H
    | H : JuicyMachine.schedfail _        |- _ => inversion H
    end; try subst.
  
  Ltac getThread_inv :=
    match goal with
    | [ H : @getThreadC ?i _ _ = _ ,
            H2 : @getThreadC ?i _ _ = _ |- _ ] =>
      pose proof (getThreadC_fun _ _ _ _ _ _ H H2)
    | [ H : @getThreadR ?i _ _ = _ ,
            H2 : @getThreadR ?i _ _ = _ |- _ ] =>
      pose proof (getThreadR_fun _ _ _ _ _ _ H H2)
    end.
  
  Lemma Ejuicy_sem : juicy_sem = juicy_core_sem cl_core_sem.
  Proof.
    unfold juicy_sem; simpl.
    f_equal.
    unfold SEM.Sem, SEM.CLN_evsem.
    rewrite SEM.CLN_msem.
    reflexivity.
  Qed.
  
  Theorem preservation Gamma n state state' :
    state_step state state' ->
    state_invariant Jspec' Gamma (S n) state ->
    state_invariant Jspec' Gamma n state' \/
    state_invariant Jspec' Gamma (S n) state'.
  Proof.
    intros STEP.
    inversion STEP as [ | ge m m' sch sch' tp tp' jmstep E E']. now auto.
    (* apply state_invariant_S *)
    subst state state'; clear STEP.
    intros INV.
    inversion INV as [m0 ge0 sch0 tp0 Phi lev gam compat sparse lock_coh safety wellformed unique E].
    subst m0 ge0 sch0 tp0.
    
    destruct sch as [ | i sch ].
    
    (* empty schedule: we loop in the same state *)
    {
      inversion jmstep; subst; try inversion HschedN.
      (* PRESERVATION :
      subst; split.
      - constructor.
      - apply state_invariant_c with (PHI := Phi) (mcompat := compat); auto; [].
        intros i cnti ora. simpl.
        specialize (safety i cnti ora); simpl in safety.
        destruct (ThreadPool.getThreadC cnti); auto.
        all: eapply safe_downward1; intuition.
       *)
    }
    
    destruct (ssrnat.leq (S i) tp.(ThreadPool.num_threads).(pos.n)) eqn:Ei; swap 1 2.
    
    (* bad schedule *)
    {
      inversion jmstep; subst; try inversion HschedN; subst tid;
        unfold ThreadPool.containsThread, is_true in *;
        try congruence.
      simpl.
      
      assert (i :: sch <> sch) by (clear; induction sch; congruence).
      inversion jmstep; subst; simpl in *; try tauto;
        unfold ThreadPool.containsThread, is_true in *;
        try congruence.
      right. (* not consuming step level *)
      apply state_invariant_c with (PHI := Phi) (mcompat := compat); auto.
      (*
      + intros i0 cnti0 ora.
        specialize (safety i0 cnti0 ora); simpl in safety.
        eassert.
        * eapply safety; eauto.
        * destruct (ThreadPool.getThreadC cnti0) as [c|c|c v|v1 v2] eqn:Ec; auto;
            intros Safe; try split; try eapply safe_downward1, Safe.
          intros c' E. eapply safe_downward1, Safe, E.
      *)
      + (* invariant about "only one Krun and it is scheduled": the
          bad schedule case is not possible *)
        intros H0 i0 cnti q H1.
        exfalso.
        specialize (unique H0 i0 cnti q H1).
        destruct unique as [sch' unique]; injection unique as <- <- .
        congruence.
    }
    
    (* the schedule selected one thread *)
    assert (cnti : ThreadPool.containsThread tp i) by apply Ei.
    remember (ThreadPool.getThreadC cnti) as ci eqn:Eci; symmetry in Eci.
    (* remember (ThreadPool.getThreadR cnti) as phi_i eqn:Ephi_i; symmetry in Ephi_i. *)
    
    destruct ci as
        [ (* Krun *) ci
        | (* Kblocked *) ci
        | (* Kresume *) ci v
        | (* Kinit *) v1 v2 ].
    
    (* thread[i] is running *)
    {
      pose (jmi := personal_mem cnti (mem_compatible_forget compat)).
      (* pose (phii := m_phi jmi). *)
      (* pose (mi := m_dry jmi). *)
      
      destruct ci as [ve te k | ef sig args lid ve te k] eqn:Heqc.
      
      (* thread[i] is running and some internal step *)
      {
        (* get the next step of this particular thread (with safety for all oracles) *)
        assert (next: exists ci' jmi',
                   corestep (juicy_core_sem cl_core_sem) ge ci jmi ci' jmi'
                   /\ forall ora, jsafeN Jspec' ge n ora ci' jmi').
        {
          specialize (safety i cnti).
          pose proof (safety tt) as safei.
          rewrite Eci in *.
          inversion safei as [ | ? ? ? ? c' m'' step safe H H2 H3 H4 | | ]; subst.
          2: now match goal with H : at_external _ _ = _ |- _ => inversion H end.
          2: now match goal with H : halted _ _ = _ |- _ => inversion H end.
          exists c', m''. split; [ apply step | ].
          revert step safety safe; clear.
          generalize (jm_ cnti compat).
          generalize (State ve te k).
          unfold jsafeN.
          intros c j step safety safe ora.
          eapply safe_corestep_forward.
          - apply juicy_core_sem_preserves_corestep_fun.
            apply semax_lemmas.cl_corestep_fun'.
          - apply step.
          - apply safety.
        }
        
        destruct next as (ci' & jmi' & stepi & safei').
        pose (tp'' := @ThreadPool.updThread i tp cnti (Krun ci') (m_phi jmi')).
        pose (tp''' := age_tp_to (level jmi') tp').
        pose (cm' := (m_dry jmi', ge, (i :: sch, tp'''))).
        
        (* now, the step that has been taken in jmstep must correspond
        to this cm' *)
        inversion jmstep; subst; try inversion HschedN; subst tid;
          unfold ThreadPool.containsThread, is_true in *;
          try congruence.
        
        - (* not in Kinit *)
          jmstep_inv. getThread_inv. congruence.
        
        - (* not in Kresume *)
          jmstep_inv. getThread_inv. congruence.
        
        - (* here is the important part, the corestep *)
          jmstep_inv.
          assert (En : level Phi = S n) by auto. (* will be in invariant *)
          left. (* consuming one step of level *)
          eapply invariant_thread_step; eauto.
          + apply Jspec'_hered.
          + apply Jspec'_juicy_mem_equiv.
          + eapply lock_coh_bound; eauto.
          + exact_eq Hcorestep.
            rewrite Ejuicy_sem.
            do 2 f_equal.
            apply proof_irr.
          + rewrite Ejuicy_sem in *.
            getThread_inv.
            injection H as <-.
            unfold jmi in stepi.
            exact_eq safei'.
            extensionality ora.
            cut ((ci', jmi') = (c', jm')). now intros H; injection H as -> ->; auto.
            eapply juicy_core_sem_preserves_corestep_fun; eauto.
            * apply semax_lemmas.cl_corestep_fun'.
            * exact_eq Hcorestep.
              do 2 f_equal; apply proof_irr.
        
        - (* not at external *)
          jmstep_inv. getThread_inv.
          injection H as <-.
          erewrite corestep_not_at_external in Hat_external. discriminate.
          unfold SEM.Sem in *.
          rewrite SEM.CLN_msem.
          eapply stepi.
          
        - (* not in Kblocked *)
          jmstep_inv.
          all: getThread_inv.
          all: congruence.
          
        - (* not halted *)
          jmstep_inv. getThread_inv.
          injection H as <-.
          erewrite corestep_not_halted in Hcant. discriminate.
          unfold SEM.Sem in *.
          rewrite SEM.CLN_msem.
          eapply stepi.
      }
      (* end of internal step *)
      
      (* thread[i] is running and about to call an external: Krun (at_ex c) -> Kblocked c *)
      {
        inversion jmstep; subst; try inversion HschedN; subst tid;
          unfold ThreadPool.containsThread, is_true in *;
          try congruence.
        
        - (* not in Kinit *)
          jmstep_inv. getThread_inv. congruence.
        
        - (* not in Kresume *)
          jmstep_inv. getThread_inv. congruence.
        
        - (* not a corestep *)
          jmstep_inv. getThread_inv. injection H as <-.
          pose proof corestep_not_at_external _ _ _ _ _ _ Hcorestep.
          rewrite Ejuicy_sem in *.
          discriminate.
        
        - (* we are at an at_ex now *)
          jmstep_inv. getThread_inv.
          injection H as <-.
          rename m' into m.
          right. (* no aging *)
          
          match goal with |- _ _ (_, _, (_, ?tp)) => set (tp' := tp) end.
          assert (compat' : mem_compatible_with tp' m Phi).
          {
            clear safety wellformed unique.
            destruct compat as [JA MC LW LC LJ].
            constructor; [ | | | | ].
            - destruct JA as [tp phithreads philocks Phi jointhreads joinlocks join].
              econstructor; eauto.
            - apply MC.
            - intros b o H.
              apply (LW b o H).
            - apply LC.
            - apply LJ.
          }
          
          apply state_invariant_c with (PHI := Phi) (mcompat := compat').
          + assumption.
          
          + (* matchfunspec *)
            assumption.
          
          + (* lock sparsity *)
            auto.
          
          + (* lock coherence *)
            unfold lock_coherence' in *.
            exact_eq lock_coh.
            f_equal.
            f_equal.
            apply proof_irr.
          
          + (* safety (same, except one thing is Kblocked instead of Krun) *)
            intros i0 cnti0' ora.
            destruct (eq_dec i i0) as [ii0 | ii0].
            * subst i0.
              unfold tp'.
              rewrite ThreadPool.gssThreadCC.
              specialize (safety i cnti ora).
              rewrite Eci in safety.
              simpl.
              simpl in safety.
              unfold jm_ in *.
              erewrite personal_mem_ext.
              -- apply safety.
              -- intros i0 cnti1 cnti'.
                 apply ThreadPool.gThreadCR.
            * assert (cnti0 : ThreadPool.containsThread tp i0) by auto.
              unfold tp'.
              rewrite <- (@ThreadPool.gsoThreadCC _ _ tp ii0 ctn cnti0).
              specialize (safety i0 cnti0 ora).
              clear -safety.
              destruct (@ThreadPool.getThreadC i0 tp cnti0).
              -- unfold jm_ in *.
                 erewrite personal_mem_ext.
                 ++ apply safety.
                 ++ intros; apply ThreadPool.gThreadCR.
              -- unfold jm_ in *.
                 erewrite personal_mem_ext.
                 ++ apply safety.
                 ++ intros; apply ThreadPool.gThreadCR.
              -- unfold jm_ in *.
                 intros c' E.
                 erewrite personal_mem_ext.
                 ++ apply safety, E.
                 ++ intros; apply ThreadPool.gThreadCR.
              -- constructor.
          
          + (* wellformed. *)
            intros i0 cnti0'.
            destruct (eq_dec i i0) as [ii0 | ii0].
            * subst i0.
              unfold tp'.
              rewrite ThreadPool.gssThreadCC.
              simpl.
              congruence.
            * assert (cnti0 : ThreadPool.containsThread tp i0) by auto.
              unfold tp'.
              rewrite <- (@ThreadPool.gsoThreadCC _ _ tp ii0 ctn cnti0).
              specialize (wellformed i0 cnti0).
              destruct (@ThreadPool.getThreadC i0 tp cnti0).
              -- constructor.
              -- apply wellformed.
              -- apply wellformed.
              -- constructor.
          
          + (* uniqueness *)
            intros notalone i0 cnti0' q Eci0.
            pose proof (unique notalone i0 cnti0' q) as unique'.
            destruct (eq_dec i i0) as [ii0 | ii0].
            * subst i0.
              unfold tp' in Eci0.
              rewrite ThreadPool.gssThreadCC in Eci0.
              discriminate.
            * assert (cnti0 : ThreadPool.containsThread tp i0) by auto.
              unfold tp' in Eci0.
              clear safety wellformed.
              rewrite <- (@gsoThreadCC _ _ tp ii0 ctn cnti0) in Eci0.
              destruct (unique notalone i cnti _ Eci).
              destruct (unique notalone i0 cnti0 q Eci0).
              congruence.
        
        - (* not in Kblocked *)
          jmstep_inv.
          all: getThread_inv.
          all: congruence.
          
        - (* not halted *)
          jmstep_inv. getThread_inv.
          injection H as <-.
          erewrite at_external_not_halted in Hcant. discriminate.
          unfold SEM.Sem in *.
          rewrite SEM.CLN_msem.
          simpl.
          congruence.
      } (* end of Krun (at_ex c) -> Kblocked c *)
    } (* end of Krun *)
    
    (* thread[i] is in Kblocked *)
    { (* only one possible jmstep, in fact divided into 6 sync steps *)
      inversion jmstep; try inversion HschedN; subst tid;
        unfold ThreadPool.containsThread, is_true in *;
        try congruence; try subst;
        try solve [jmstep_inv; getThread_inv; congruence].
      
      simpl SCH.schedSkip in *.
      left (* TO BE CHANGED *).
      (* left (* we need aging, because we're using the safety of the call *). *)
      match goal with |- _ _ _ (?M, _, (_, ?TP)) => set (tp_ := TP); set (m_ := M) end.
      pose (compat_ := mem_compatible_with tp_ m_ (age_to n Phi)).
      jmstep_inv.
      
      cleanup.
      assert (El : level (getThreadR Htid) - 1 = n). {
        rewrite getThread_level with (Phi := Phi).
        - cleanup.
          rewrite lev.
          omega.
        - destruct compat. auto.
      }
      cleanup.
      
      pose proof mem_compatible_with_age compat (n := n) as compat_aged.
      
      - (* the case of acquire *)
        assert (compat' : compat_). {
          subst compat_ tp_ m_.
          rewrite El.
          constructor.
          - destruct compat as [J].
            clear -J lev His_unlocked Hadd_lock_res.
            rewrite join_all_joinlist in *.
            rewrite maps_age_to.
            rewrite maps_updlock1.
            erewrite maps_getlock3 in J; eauto.
            rewrite maps_remLockSet_updThread.
            rewrite maps_updthread.
            simpl map.
            assert (pr:containsThread (remLockSet tp (b, Int.intval ofs)) i) by auto.
            rewrite (maps_getthread i _ pr) in J.
            rewrite gRemLockSetRes with (cnti := Htid) in J. clear pr.
            revert Hadd_lock_res J.
            generalize (getThreadR Htid) d_phi (m_phi jm').
            generalize (all_but i (maps (remLockSet tp (b, Int.intval ofs)))).
            cleanup.
            clear -lev.
            intros l a b c j h.
            rewrite Permutation.perm_swap in h.
            pose proof @joinlist_age_to _ _ _ _ _ n _ _ h as h'.
            simpl map in h'.
            apply age_to_join_eq with (k := n) in j; auto.
            + eapply joinlist_merge; eassumption.
            + cut (level c = level Phi). omega.
              apply join_level in j. destruct j.
              eapply (joinlist_level a) in h.
              * congruence.
              * left; auto.
          
          - (* mem_cohere' *)
            destruct compat as [J MC].
            clear safety lock_coh jmstep.
            eapply mem_cohere'_store with
            (tp := age_tp_to n tp)
              (Hcmpt := mem_compatible_forget compat_aged)
              (i := Int.zero).
            + cleanup.
              rewrite lset_age_tp_to.
              rewrite AMap_find_map_option_map.
              rewrite His_unlocked. simpl. congruence.
            + exact_eq Hstore.
              f_equal.
              f_equal.
              apply restrPermMap_ext.
              unfold lockSet in *.
              rewrite lset_age_tp_to.
              intros b0.
              rewrite (@A2PMap_option_map rmap (lset tp)).
              reflexivity.
              
            + auto.
          
          - (* lockSet_Writable *)
            pose proof (loc_writable compat) as lw.
            intros b' ofs' is; specialize (lw b' ofs').
            destruct (eq_dec (b, Int.intval ofs) (b', ofs')).
            + injection e as <- <- .
              intros ofs0 int0.
              rewrite (Mem.store_access _ _ _ _ _ _ Hstore).
              pose proof restrPermMap_Max as RR.
              unfold permission_at in RR.
              rewrite RR; clear RR.
              clear is.
              assert_specialize lw. {
                clear lw.
                cleanup.
                rewrite His_unlocked.
                reflexivity.
              }
              specialize (lw ofs0).
              autospec lw.
              exact_eq lw; f_equal.
              unfold getMaxPerm in *.
              rewrite PMap.gmap.
              reflexivity.
            + assert_specialize lw. {
                simpl in is.
                rewrite AMap_find_map_option_map in is.
                rewrite AMap_find_add in is.
                if_tac in is. tauto.
                exact_eq is.
                unfold ssrbool.isSome in *.
                cleanup.
                destruct (AMap.find (elt:=option rmap) (b', ofs') (lset tp));
                  reflexivity.
              }
              intros ofs0 inter.
              specialize (lw ofs0 inter).
              exact_eq lw. f_equal.
              set (m_ := restrPermMap _) in Hstore.
              change (max_access_at m (b', ofs0) = max_access_at (m_dry jm') (b', ofs0)).
              transitivity (max_access_at m_ (b', ofs0)).
              * unfold m_.
                rewrite restrPermMap_max.
                reflexivity.
              * pose proof store_outside' _ _ _ _ _ _ Hstore as SO.
                unfold access_at in *.
                destruct SO as (_ & SO & _).
                apply equal_f with (x := (b', ofs0)) in SO.
                apply equal_f with (x := Max) in SO.
                apply SO.
          - (* juicyLocks_in_lockSet *)
            pose proof jloc_in_set compat as jl.
            intros loc sh1 sh1' pp z E.
            cleanup.
            (* rewrite lset_age_tp_to. *)
            (* rewrite AMap_find_map_option_map. *)
            Lemma isSome_option_map {A B} (f : A -> B) o : ssrbool.isSome (option_map f o) = ssrbool.isSome o.
            Proof.
              destruct o; reflexivity.
            Qed.
            (* rewrite isSome_option_map. *)
            apply juicyLocks_in_lockSet_age with (n := n) in jl.
            specialize (jl loc sh1 sh1' pp z E).
            simpl.
            Lemma AMap_map_add {A B} (f : A -> B) m x y :
              AMap.Equal
                (AMap.map f (AMap.add x y m))
                (AMap.add x (f y) (AMap.map f m)).
            Proof.
              intros k.
              rewrite AMap_find_map_option_map.
              rewrite AMap_find_add.
              rewrite AMap_find_add.
              rewrite AMap_find_map_option_map.
              destruct (AMap.find (elt:=A) k m); if_tac; auto.
            Qed.
            rewrite AMap_map_add.
            rewrite AMap_find_add.
            if_tac. reflexivity.
            rewrite lset_age_tp_to in jl.
            apply jl.
          
          - (* lockSet_in_juicyLocks *)
            pose proof lset_in_juice compat as lj.
            intros loc; specialize (lj loc).
            simpl.
            rewrite AMap_map_add.
            rewrite AMap_find_add.
            rewrite AMap_find_map_option_map.
            if_tac; swap 1 2.
            + cleanup.
              rewrite isSome_option_map.
              intros is; specialize (lj is).
              destruct lj as (sh' & psh' & P & E).
              rewrite age_to_resource_at.
              rewrite E. simpl. eauto.
            + intros _. subst loc.
              assert_specialize lj. {
                cleanup.
                rewrite His_unlocked.
                reflexivity.
              }
              destruct lj as (sh' & psh' & P & E).
              rewrite age_to_resource_at.
              rewrite E. simpl. eauto.
        }
        
        apply state_invariant_c with (mcompat := compat').
        + (* level *)
          apply level_age_to. omega.
        
        + (* matchfunspec *)
          revert gam. clear.
          Lemma matchfunspec_age_to e Gamma n Phi :
            matchfunspec e Gamma Phi ->
            matchfunspec e Gamma (age_to n Phi).
          Proof.
            unfold matchfunspec in *.
            apply age_to_pred.
          Qed.
          apply matchfunspec_age_to.
        
        + (* lock sparsity *)
          unfold tp_ in *.
          simpl.
          cleanup.
          eapply sparsity_same_support with (lset tp); auto.
          apply lset_same_support_sym.
          eapply lset_same_support_trans.
          * apply lset_same_support_map.
          * apply lset_same_support_sym.
            apply same_support_change_lock.
            cleanup.
            rewrite His_unlocked. congruence.
        
        + (* lock coherence *)
          intros loc.
          simpl (AMap.find _ _).
          rewrite AMap_find_map_option_map.
          rewrite AMap_find_add.
          specialize (lock_coh loc).
          if_tac.
          
          * (* current lock is acquired: load is indeed 0 *)
            { subst loc.
              split; swap 1 2.
              - (* the rmap is unchanged (but we lose the SAT information) *)
                cut (exists sh0 R0, (LK_at R0 sh0 (b, Int.intval ofs)) Phi).
                { intros (sh0 & R0 & AP). exists sh0, R0. apply age_to_pred, AP. }
                cleanup.
                rewrite His_unlocked in lock_coh.
                destruct lock_coh as (H & ? & ? & lk & _).
                eauto.
              
              - (* in dry : it is 0 *)
                unfold m_ in *; clear m_.
                unfold compat_ in *; clear compat_.
                unfold load_at.
                clear (* lock_coh *) Htstep Hload.
                
                unfold Mem.load. simpl fst; simpl snd.
                if_tac [H|H].
                + rewrite restrPermMap_mem_contents.
                  apply Mem.load_store_same in Hstore.
                  unfold Mem.load in Hstore.
                  if_tac in Hstore; [ | discriminate ].
                  apply Hstore.
                + exfalso.
                  apply H; clear H.
                  apply islock_valid_access.
                  * apply Mem.load_store_same in Hstore.
                    unfold Mem.load in Hstore.
                    if_tac [[H H']|H] in Hstore; [ | discriminate ].
                    apply H'.
                  * unfold tp_.
                    Lemma LockRes_age_content1 js n a :
                      lockRes (age_tp_to n js) a = option_map (option_map (age_to n)) (lockRes js a).
                    Proof.
                      cleanup.
                      rewrite lset_age_tp_to, AMap_find_map_option_map.
                      reflexivity.
                    Qed.
                    rewrite LockRes_age_content1.
                    rewrite JTP.gssLockRes. simpl. congruence.
                  * congruence.
            }
          
          * (* not the current lock *)
            rewrite El.
            destruct (AMap.find (elt:=option rmap) loc (lset tp)) as [o|] eqn:Eo; swap 1 2.
            {
              simpl.
              clear -lock_coh.
              rewrite isLK_age_to, isCT_age_to. auto.
            }
            (* options:
             - maintain the invariant that the distance between
                two locks is >= 4 (or =0)
             - try to relate to the wet memory?
             - others?
             *)
            set (u := load_at _ _).
            set (v := load_at _ _) in lock_coh.
            assert (L : forall val, v = Some val -> u = Some val); unfold u, v in *.
            (* ; clear u v. *)
            {
              intros val.
              unfold load_at in *.
              clear lock_coh.
              destruct loc as (b', ofs'). simpl fst in *; simpl snd in *.
              pose proof sparse (b, Int.intval ofs) (b', ofs') as SPA.
              assert_specialize SPA by (cleanup; congruence).
              assert_specialize SPA by (cleanup; congruence).
              simpl in SPA.
              destruct SPA as [SPA|SPA]; [ tauto | ].
              unfold Mem.load in *.
              if_tac [V|V]; [ | congruence].
              if_tac [V'|V'].
              - do 2 rewrite restrPermMap_mem_contents.
                intros G; exact_eq G.
                f_equal.
                f_equal.
                f_equal.
                simpl.
                
                pose proof store_outside' _ _ _ _ _ _ Hstore as OUT.
                destruct OUT as (OUT, _).
                cut (forall z,
                        (0 <= z < 4)%Z ->
                        ZMap.get (ofs' + z)%Z (Mem.mem_contents m) !! b' =
                        ZMap.get (ofs' + z)%Z (Mem.mem_contents m_) !! b').
                {
                  intros G.
                  repeat rewrite <- Z.add_assoc.
                  f_equal.
                  - specialize (G 0%Z ltac:(omega)).
                    exact_eq G. repeat f_equal; auto with zarith.
                  - f_equal; [apply G; omega | ].
                    f_equal; [apply G; omega | ].
                    f_equal; apply G; omega.
                }
                intros z Iz.
                specialize (OUT b' (ofs' + z)%Z).
                
                destruct OUT as [[-> OUT]|OUT]; [ | clear SPA].
                + exfalso.
                  destruct SPA as [? | [_ SPA]]; [ tauto | ].
                  eapply far_range in SPA. apply SPA; clear SPA.
                  apply OUT. omega.
                + unfold contents_at in *.
                  simpl in OUT.
                  apply OUT.
              
              - exfalso.
                apply V'; clear V'.
                unfold Mem.valid_access in *.
                split. 2:apply V. destruct V as [V _].
                unfold Mem.range_perm in *.
                intros ofs0 int0; specialize (V ofs0 int0).
                unfold Mem.perm in *.
                pose proof restrPermMap_Cur as RR.
                unfold permission_at in *.
                rewrite RR in *.
                unfold tp_.
                rewrite lockSet_age_to.
                rewrite <-lockSet_updLockSet.
                match goal with |- _ ?a _ => cut (a = Some Writable) end.
                { intros ->. constructor. }
                
                destruct SPA as [bOUT | [<- ofsOUT]].
                + rewrite gsoLockSet_2; auto.
                  eapply lockSet_spec_2.
                  * hnf; simpl. eauto.
                  * cleanup. rewrite Eo. reflexivity.
                + rewrite gsoLockSet_1; auto.
                  * eapply lockSet_spec_2.
                    -- hnf; simpl. eauto.
                    -- cleanup. rewrite Eo. reflexivity.
                  * unfold far in *.
                    simpl in *.
                    zify.
                    omega.
            }
            destruct o; destruct lock_coh as (Load & sh' & R' & lks); split.
            -- now intuition.
            -- exists sh', R'.
               destruct lks as (lk, sat); split.
               ++ revert lk.
                  apply age_to_pred.
               ++ destruct sat as [sat|sat].
                  ** left; revert sat.
                     unfold age_to in *.
                     rewrite age_by_age_by.
                     apply age_by_age_by_pred.
                     omega.
                  ** congruence.
            -- now intuition.
            -- exists sh', R'.
               revert lks.
               apply age_to_pred.
        
        + (* safety *)
          intros j lj ora.
          specialize (safety j lj ora).
          unfold tp_.
          unshelve erewrite <-gtc_age. auto.
          unshelve erewrite gLockSetCode; auto.
          destruct (eq_dec i j).
          * {
              (* use the "well formed" property to derive that this is
              an external call, and derive safety from this.  But the
              level has to be decreased, here. *)
              subst j.
              rewrite gssThreadCode.
              replace lj with Htid in safety by apply proof_irr.
              rewrite Hthread in safety.
              specialize (wellformed i Htid).
              rewrite Hthread in wellformed.
              intros c' Ec'.
              inversion safety as [ | ?????? step | ???????? ae Pre Post Safe | ????? Ha]; swap 2 3.
              - (* not corestep *)
                exfalso.
                clear -Hat_external step.
                apply corestep_not_at_external in step.
                rewrite jstep.JuicyFSem.t_obligation_3 in step.
                set (u := at_external _) in Hat_external.
                set (v := at_external _) in step.
                assert (u = v).
                { unfold u, v. f_equal.
                  unfold SEM.Sem in *.
                  rewrite SEM.CLN_msem.
                  reflexivity. }
                congruence.
              
              - (* not halted *)
                exfalso.
                clear -Hat_external Ha.
                assert (Ae : at_external SEM.Sem c <> None). congruence.
                eapply at_external_not_halted in Ae.
                unfold juicy_core_sem in *.
                unfold cl_core_sem in *.
                simpl in *.
                unfold SEM.Sem in *.
                rewrite SEM.CLN_msem in *.
                simpl in *.
                congruence.
              
              - (* at_external : we can now use safety *)
                subst z c0 m0.
                destruct Post with
                  (ret := Some (Vint Int.zero))
                  (m' := jm_ lj compat')
                  (z' := ora) (n' := n) as (c'' & Ec'' & Safe').
                + auto.
                + hnf. (* ouch *) admit.
                + (* ouch, we must satisfy the post condition *)
                  unfold ext_spec_post in *.
                  admit.
                + exact_eq Safe'.
                  unfold jsafeN in *.
                  unfold juicy_safety.safeN in *.
                  f_equal.
                  cut (Some c'' = Some c'). injection 1; auto.
                  rewrite <-Ec'', <-Ec'.
                  unfold cl_core_sem; simpl.
                  auto.
            }
          
          * unshelve erewrite gsoThreadCode; auto.
            admit.
            (* destruct (@getThreadC j tp lj). *)
            (* use safety, but there are [personal_mem] things involved *)
        
        + (* well_formedness *)
          intros j lj.
          unfold tp_.
          specialize (wellformed j lj).
          Set Printing Implicit.
          unshelve erewrite <-gtc_age. auto.
          unshelve erewrite gLockSetCode; auto.
          destruct (eq_dec i j).
          * subst j.
            rewrite gssThreadCode.
            replace lj with Htid in wellformed by apply proof_irr.
            rewrite Hthread in wellformed.
            auto.
          * unshelve erewrite gsoThreadCode; auto.
        
        + (* uniqueness *)
          apply no_Krun_unique_Krun.
          (* unfold tp_ in *. *)
          unfold tp_.
          Unset Printing Implicit.
          rewrite no_Krun_age_tp_to.
          apply no_Krun_updLockSet.
          apply no_Krun_stable. congruence.
          eapply unique_Krun_no_Krun. eassumption.
          instantiate (1 := Htid). rewrite Hthread.
          congruence.
      
      - (* the case of release *)
        admit.
      
      - (* the case of spawn *)
        admit.
      
      - (* the case of makelock *)
        admit.
      
      - (* the case of freelock *)
        admit.
      
      - (* the case of acq-fail *)
        admit.
    }
    
    (*thread[i] is in Kresume *)
    { (* again, only one possible case *)
      right (* no aging *).
      inversion jmstep; try inversion HschedN; subst tid;
        unfold ThreadPool.containsThread, is_true in *;
        try congruence; try subst;
        try solve [jmstep_inv; getThread_inv; congruence].
      jmstep_inv.
      rename m' into m.
      assert (compat' : mem_compatible_with (updThreadC ctn (Krun c')) m Phi).
      {
        clear safety wellformed unique.
        destruct compat as [JA MC LW LC LJ].
        constructor; [ | | | | ].
        - destruct JA as [tp phithreads philocks Phi jointhreads joinlocks join].
          econstructor; eauto.
        - apply MC.
        - intros b o H.
          apply (LW b o H).
        - apply LC.
        - apply LJ.
      }
      
      apply state_invariant_c with (PHI := Phi) (mcompat := compat').
      + (* level *)
        assumption.
      
      + (* matchfunspec *)
        assumption.
      
      + (* lock sparsity *)
        auto.
      
      + (* lock coherence *)
        unfold lock_coherence' in *.
        exact_eq lock_coh.
        f_equal.
        f_equal.
        apply proof_irr.
      
      + (* safety : the new c' is derived from "after_external", so
           that's not so good? *)
        intros i0 cnti0' ora.
        destruct (eq_dec i i0) as [ii0 | ii0].
        * subst i0.
          rewrite ThreadPool.gssThreadCC.
          specialize (safety i cnti ora).
          rewrite Eci in safety.
          simpl.
          (* apply safe_downward1. *)
          change (jsafeN Jspec' ge (S n) ora c' (jm_ cnti0' compat')).
          getThread_inv. injection H as -> -> .
          specialize (safety c').
          unfold SEM.Sem in *.
          rewrite SEM.CLN_msem in *.
          specialize (safety ltac:(eauto)).
          exact_eq safety.
          f_equal.
          unfold jm_ in *.
          apply personal_mem_ext.
          intros i0 cnti0 cnti'.
          unshelve erewrite gThreadCR; auto.
        * assert (cnti0 : ThreadPool.containsThread tp i0) by auto.
          rewrite <- (@ThreadPool.gsoThreadCC _ _ tp ii0 ctn cnti0).
          specialize (safety i0 cnti0 ora).
          clear -safety.
          destruct (@ThreadPool.getThreadC i0 tp cnti0).
          -- unfold jm_ in *.
             erewrite personal_mem_ext.
             ++ apply safety.
             ++ intros; apply ThreadPool.gThreadCR.
          -- unfold jm_ in *.
             erewrite personal_mem_ext.
             ++ apply safety.
             ++ intros; apply ThreadPool.gThreadCR.
          -- unfold jm_ in *.
             erewrite personal_mem_ext.
             ++ intros c'' E; apply safety, E.
             ++ intros; apply ThreadPool.gThreadCR.
          -- constructor.
      
      + (* wellformed. *)
        intros i0 cnti0'.
        destruct (eq_dec i i0) as [ii0 | ii0].
        * subst i0.
          rewrite ThreadPool.gssThreadCC.
          constructor.
        * assert (cnti0 : ThreadPool.containsThread tp i0) by auto.
          rewrite <- (@ThreadPool.gsoThreadCC _ _ tp ii0 ctn cnti0).
          specialize (wellformed i0 cnti0).
          destruct (@ThreadPool.getThreadC i0 tp cnti0).
          -- constructor.
          -- apply wellformed.
          -- apply wellformed.
          -- constructor.
             
      + (* uniqueness *)
        intros notalone i0 cnti0' q Eci0.
        pose proof (unique notalone i0 cnti0' q) as unique'.
        destruct (eq_dec i i0) as [ii0 | ii0].
        * subst i0.
          eauto.
        * assert (cnti0 : ThreadPool.containsThread tp i0) by auto.
          clear safety wellformed.
          rewrite <- (@gsoThreadCC _ _ tp ii0 ctn cnti0) in Eci0.
          destruct (unique notalone i0 cnti0 q Eci0).
          congruence.
    }
    
    (* thread[i] is in Kinit *)
    {
      (* still unclear how to handle safety of Kinit states *)
      admit.
    }
  Admitted.
End Simulation.
