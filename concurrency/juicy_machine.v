Require Import compcert.lib.Axioms.

Require Import msl.age_to.
Require Import concurrency.sepcomp. Import SepComp.
Require Import sepcomp.semantics_lemmas.

Require Import concurrency.enums_equality.
Require Import concurrency.pos.
Require Import concurrency.scheduler.
Require Import concurrency.concurrent_machine.
Require Import concurrency.addressFiniteMap. (*The finite maps*)
Require Import concurrency.threads_lemmas.
Require Import concurrency.rmap_locking.
Require Import concurrency.lksize.
Require Import concurrency.semantics.
Require Import Coq.Program.Program.
From mathcomp.ssreflect Require Import ssreflect ssrbool ssrnat ssrfun eqtype seq fintype finfun.
Set Implicit Arguments.

(*NOTE: because of redefinition of [val], these imports must appear 
  after Ssreflect eqtype.*)
Require Import compcert.common.AST.     (*for typ*)
Require Import compcert.common.Values. (*for val*)
Require Import compcert.common.Globalenvs. 
Require Import compcert.common.Memory.
Require Import compcert.lib.Integers.

Require Import Coq.ZArith.ZArith.

(*From msl get the juice! *)
Require Import veric.compcert_rmaps.
Require Import veric.juicy_mem.
Require Import veric.juicy_mem_lemmas.
Require Import veric.juicy_extspec.
Require Import veric.jstep.
Require Import veric.res_predicates.



Set Bullet Behavior "Strict Subproofs".



(**)
Require Import veric.res_predicates. (*For the precondition of lock make and free*)

(*  This shoul be replaced by global: 
    Require Import concurrency.lksize.  *)

Require Import (*compcert_linking*) concurrency.permissions concurrency.threadPool.

(* There are some overlaping definition conflicting. 
   Here we fix that. But this is obviously ugly and
   the conflicts should be removed by renaming!     *)
Notation "x <= y" := (x <= y)%nat. 
Notation "x < y" := (x < y)%nat.


(*Module LockPool.
  (* The lock set is a Finite Map:
     Address -> option option rmap
     Where the first option stands for the address being a lock
     and the second for the lock being locked/unlocked *)
  Definition LockPool:= address -> option (option rmap).
  Notation SSome x:= (Some (Some x)).
  Notation SNone:= (Some None).
End LockPool.
Export LockPool.*)

Module LocksAndResources.
  Definition res := rmap.
  Definition lock_info: Type := option rmap.
End LocksAndResources.

Module ThreadPool (SEM:Semantics) <: ThreadPoolSig
    with Module TID:= NatTID with Module SEM:=SEM
    with Module RES:= LocksAndResources.
  Include (OrdinalPool SEM LocksAndResources).
  (** The Lock Resources Set *)

  Definition is_lock t:= fun loc => AMap.mem loc (lset t).

  (*Add/Update lock: Notice that adding and updating are the same, depending wether then
    lock was already there. *)
  (*Definition addLock tp loc (res: option Res.res):=
  mk (num_threads tp)
     (pool tp)
     (perm_maps tp)
     (AMap.add loc res (lset tp)).
  (*Remove Lock*)
  Definition remLock tp loc:=
  mk (num_threads tp)
     (pool tp)
     (perm_maps tp)
     (AMap.remove loc (lset tp)). *)
   
End ThreadPool.

Module Concur.

  
  Module mySchedule := ListScheduler NatTID.
  
  (** Semantics of the coarse-grained juicy concurrent machine*)
  Module JuicyMachineShell (SEM:Semantics)  <: ConcurrentMachineSig
      with Module ThreadPool.TID:=mySchedule.TID
      with Module ThreadPool.SEM:= SEM
      with Module ThreadPool.RES := LocksAndResources
      with Module Events.TID := NatTID.
      Import LocksAndResources.
      (*Notation lockMap:=(address -> option (option rmap)).*)
      Notation lockMap:= (AMap.t (option rmap)).
      Notation SSome x:= (Some (Some x)).
      Notation SNone:= (Some None).
      Module Events := Events.
      Module ThreadPool := ThreadPool SEM.
      
    Import ThreadPool.
    Import ThreadPool.SEM.
    Import event_semantics Events.
    Notation tid := NatTID.tid.

    (** Memories*)
    Definition richMem: Type:= juicy_mem.
    Definition dryMem: richMem -> mem:= m_dry.
    Definition diluteMem: mem -> mem := fun x => x.
    
    (** Environment and Threadwise semantics *)
    (* This all comes from the SEM. *)
    (*Parameter G : Type.
    Parameter Sem : CoreSemantics G code mem.*)
    Notation the_sem := (csem (event_semantics.msem Sem)).
    
    (*thread pool*)
    Import ThreadPool.  
    Notation thread_pool := (ThreadPool.t).  
    
    (** Machine Variables*)
    Definition lp_id : tid:= (0)%nat. (*lock pool thread id*)
    
    (** Invariants*)
    (** The state respects the memory*)
    Definition access_cohere' m phi:= forall loc,
        Mem.perm_order'' (max_access_at m loc) (perm_of_res (phi @ loc)).

    (* This is similar to the coherence of juicy memories, *
     * but for entire machines. It is slighly weaker in one way:
     * - acc_coh is looser and only talks about maxcoh. 
     * - alse acc_coh  might me redundant with max_coh IDK... x*)
    Record mem_cohere' m phi :=
      { cont_coh: contents_cohere m phi;
        (*acc_coh: access_cohere m phi;*)
        (*acc_coh: access_cohere' m phi;*)
        max_coh: max_access_cohere m phi;
        all_coh: alloc_cohere m phi
      }.
    Definition mem_thcohere tp m :=
      forall {tid} (cnt: containsThread tp tid), mem_cohere' m (getThreadR cnt).
    
    Definition mem_lock_cohere (ls:lockMap) m:=
      forall loc rm, AMap.find loc ls = SSome rm -> mem_cohere' m rm.
    
    (* given n <= m, returns the list [n-1,...,0] with proofs of < m *)
    (*Program Fixpoint enum_from n m (pr : le n m) : list (ordinal m) :=
      match n with
        O => nil
      | S n => (@Ordinal m n ltac:(rewrite <-Heq_n in *; apply (introT leP pr)))
                :: @enum_from n m ltac:(rewrite <-Heq_n in *; apply le_Sn_le, pr)
      end.*)
    
    (*Definition enum n := rev (@enum_from n n (le_refl n)).*)
    
    Lemma length_enum_from n m pr : List.length (@enums_equality.enum_from n m pr) = n.
    Proof.
      induction n; auto.
      simpl.
      rewrite IHn; auto.
    Qed.
      
    Lemma length_enum n : List.length (enums_equality.enum n) = n.
    Proof.
      unfold enums_equality.enum.
      rewrite Coq.Lists.List.rev_length.
      apply length_enum_from.
    Qed.
    
    (*Join juice from all threads *)
    Definition getThreadsR tp:=
      map (perm_maps tp) (enums_equality.enum (num_threads tp)).
    
    Fixpoint join_list (ls: seq.seq res) r:=
      if ls is phi::ls' then exists r', join phi r' r /\ join_list ls' r' else
        app_pred emp r.  (*Or is is just [amp r]?*)
    Definition join_threads tp r:= join_list (getThreadsR tp) r.

    Lemma getThreadsR_addThread tp v1 v2 phi :
      getThreadsR (addThread tp v1 v2 phi) = getThreadsR tp ++ phi :: nil.
    Proof.
    Admitted. (* getThreadsR_addThread *)
    
    (*Join juice from all locks*)
    Fixpoint join_list' (ls: seq.seq (option res)) (r:option res):=
      if ls is phi::ls' then exists (r':option res),
          @join _ (@Join_lower res _) phi r' r /\ join_list' ls' r' else r=None.
    Definition join_locks tp r:= join_list' (map snd (AMap.elements (lset tp))) r.

    (*Join all the juices*)
    Inductive join_all: t -> res -> Prop:=
      AllJuice tp r0 r1 r:
        join_threads tp r0 ->
        join_locks tp r1 ->
        join (Some r0) r1 (Some r) ->
        join_all tp r.

    
    Definition juicyLocks_in_lockSet (lset : lockMap) (juice: rmap):=
      forall loc sh psh P z, juice @ loc = YES sh psh (LK z) P  ->  AMap.find loc lset.

    (* I removed the NO case for two reasons:
     * - To ensure that lset is "valid" (lr_valid), it needs inherit it from the rmap 
     * - there was no real reason to have a NO other than speculation of the future. *)
    Definition lockSet_in_juicyLocks (lset : lockMap) (juice: rmap):=
      forall loc, AMap.find loc lset -> 
	     (exists sh psh P, juice @ loc = YES sh psh (LK LKSIZE) P).

    
    
    Definition lockSet_in_juicyLocks' (lset : lockMap) (juice: rmap):=
      forall loc, AMap.find loc lset ->
             Mem.perm_order'' (Some Nonempty) (perm_of_res (juice @ loc)).
    Lemma lockSet_in_juic_weak: forall lset juice,
        lockSet_in_juicyLocks lset juice -> lockSet_in_juicyLocks' lset juice.
    Proof.
      intros lset juice HH loc FIND.
      apply HH in FIND.
      (*destruct FIND as [[sh [psh [P [z FIND]]]] | [sh0 FIND]]; rewrite FIND; simpl.*)
      destruct FIND as [sh [psh [P FIND]]]; rewrite FIND; simpl.
      - constructor.
      (*- destruct (eq_dec sh0 Share.bot); constructor.*)
    Qed.
           
    
    Definition lockSet_Writable (lset : lockMap) m :=
      forall b ofs, AMap.find (b,ofs) lset ->
               forall ofs0, Intv.In ofs0 (ofs, ofs + LKSIZE)%Z ->
             Mem.perm_order'' ((Mem.mem_access m)!! b ofs0 Max) (Some Writable) .

    (*This definition makes no sense. In fact if there is at least one lock in rmap, 
     *then the locks_writable is false (because perm_of_res(LK) = Some Nonempty). *)
    Definition locks_writable (juice: rmap):=
      forall loc sh psh P z, juice @ loc = YES sh psh (LK z) P  ->
                    Mem.perm_order'' (perm_of_res (juice @ loc)) (Some Writable).
    
    Record mem_compatible_with' tp m all_juice : Prop :=
      {   juice_join : join_all tp all_juice
        ; all_cohere : mem_cohere' m all_juice
        ; loc_writable : lockSet_Writable (lockGuts tp) m
        ; jloc_in_set : juicyLocks_in_lockSet (lockGuts tp) all_juice
        ; lset_in_juice: lockSet_in_juicyLocks  (lockGuts tp) all_juice
      }.

    Definition mem_compatible_with := mem_compatible_with'.
    
    Definition mem_compatible tp m := ex (mem_compatible_with tp m).
        
    Lemma jlocinset_lr_valid: forall ls juice,
        lockSet_in_juicyLocks ls juice ->
        lr_valid (AMap.find (elt:=lock_info)^~ (ls)).
    Proof.
      unfold lr_valid, lockSet_in_juicyLocks; intros.
      destruct (AMap.find (elt:=lock_info) (b, ofs) ls) eqn:MAP.
      - intros ofs0 ineq.
        destruct (AMap.find (elt:=lock_info) (b, ofs0) ls) eqn:MAP'; try reflexivity.
        assert (H':=H).
        specialize (H (b,ofs) ltac:(rewrite MAP; auto)).
        destruct H as [sh [psh [P H]]].
        specialize (H' (b,ofs0) ltac:(rewrite MAP'; auto)).
        destruct H' as [sh' [psh' [P' H']]].
        assert (VALID:=phi_valid juice).
        specialize (VALID b ofs). unfold "oo" in VALID.
        rewrite H in VALID; simpl in VALID.
        assert (ineq': (0< ofs0 - ofs < LKSIZE)%Z).
        { clear - ineq.
          unfold LKSIZE; simpl.
          unfold lksize.LKSIZE in ineq; simpl in ineq. xomega. }
        apply VALID in ineq'.
        replace (ofs + (ofs0 - ofs))%Z with ofs0 in ineq' by xomega.
        rewrite H' in ineq'. inversion ineq'.
        - auto.
    Qed.

    Lemma compat_lr_valid: forall js m,
        mem_compatible js m ->
        lr_valid (lockRes js).
    Proof. intros js m H.
           inversion H. 
           eapply jlocinset_lr_valid with (juice:=x).
           inversion H0; auto.
    Qed.
          
    
    
    Lemma mem_compatible_locks_ltwritable':
      forall js m, lockSet_Writable (lockGuts js) m ->
                permMapLt (lockSet js) (getMaxPerm m ).
    Proof.
      unfold permMapLt, lockSet_Writable. intros.
      rewrite getMaxPerm_correct.
      specialize (H b).
      
      (*0*)
      destruct (lockRes js (b, ofs)) eqn:H0.
      unfold lockRes in H0; specialize (H ofs ltac:(rewrite H0; auto) ofs).
      assert (ineq: Intv.In ofs (ofs, (ofs + LKSIZE)%Z)).
      unfold LKSIZE; hnf; simpl. omega.
      apply H in ineq.
      eapply po_trans; eauto.
      rewrite lockSet_spec_1. apply po_refl.
      unfold lockRes; rewrite H0; constructor.

      (* manual induction *)
      Local Ltac t H js b ofs n :=
        let H1 := fresh in
        destruct (lockRes js (b, (ofs-n)%Z)) eqn:H1;
        [ unfold lockRes in H1;
          specialize (H (ofs-n)%Z ltac:(rewrite H1; auto) (ofs));
          assert (ineq: Intv.In ofs (ofs-n, (ofs-n + LKSIZE))%Z)
            by (unfold LKSIZE; hnf; simpl; omega);
          assert (ineq':=ineq);
          apply H in ineq; eapply po_trans; eauto;
          erewrite lockSet_spec_2;
          [ apply po_refl
          | apply ineq'
          | unfold lockRes; rewrite H1; constructor ] | ].
      
      t H js b ofs 1%Z.
      t H js b ofs 2%Z.
      t H js b ofs 3%Z.
      (*t H js b ofs 4%Z.
      t H js b ofs 5%Z.
      t H js b ofs 6%Z.
      t H js b ofs 7%Z.
      t H js b ofs 8%Z.
      t H js b ofs 9%Z.
      t H js b ofs 10%Z.
      t H js b ofs 11%Z.
      t H js b ofs 12%Z.
      t H js b ofs 13%Z.
      t H js b ofs 14%Z.
      t H js b ofs 15%Z.*)
      
      pose (JuicyMachineShell.ThreadPool.lockSet_spec_3).
      assert (forall z, (z <= ofs < z + 4)%Z -> lockRes js (b, z) = None).
      intros.
      assert (O : (z = ofs \/ z = ofs-1 \/ z = ofs-2 \/ z = ofs-3 \/
                   z = ofs-4 (* \/ z = ofs-5 \/ z = ofs-6 \/ z = ofs-7 \/
                   z = ofs-8 \/ z = ofs-9 \/ z = ofs-10 \/ z = ofs-11 \/
                   z = ofs-12 \/ z = ofs-13 \/ z = ofs-14 \/ z = ofs-15 \/
                   z = ofs-16*))%Z) by omega.
      repeat (destruct O as [-> | O]; auto). omega.
      
      apply e in H4. rewrite H4.
      apply po_None.
    Qed.

    Lemma mem_compatible_locks_ltwritable:
      forall tp m, mem_compatible tp m ->
              permMapLt (lockSet tp) (getMaxPerm m ).
    Proof. intros. inversion H as [all_juice M]; inversion M. inversion all_cohere0.
           destruct tp.
           simpl in *.
           eapply mem_compatible_locks_ltwritable'; eassumption.
    Qed.
    (*
    Lemma mem_compatible_locks_lt:
      forall {tp m}, mem_compatible tp m -> forall i cnti,
              permMapLt (perm_of_res_lock (@getThreadR i tp cnti)) (getMaxPerm m ).
    Proof. intros. inversion H as [all_juice M]; inversion M. inversion all_cohere0.
           destruct tp.
           simpl in *.
           eapply mem_compatible_locks_ltwritable'; eassumption.
    Qed.*)

    Lemma compat_lt_m: forall m js,
        mem_compatible js m ->
        forall b ofs,
          Mem.perm_order'' ((getMaxPerm m) !! b ofs)
                           ((lockSet js) !! b ofs).
    Proof. intros. eapply mem_compatible_locks_ltwritable; auto. Qed.

    
    Lemma compatible_lockRes_join:
      forall js (m : mem),
        mem_compatible js m ->
        forall (l1 l2 : address) (phi1 phi2 : rmap),
          l1 <> l2 ->
          ThreadPool.lockRes js l1 = Some (Some phi1) ->
          ThreadPool.lockRes js l2 = Some (Some phi2) ->
          joins phi1 phi2.
    Proof. intros ? ? Hcompat; intros ? ? ? ? Hneq; intros.
           destruct Hcompat as [allj Hcompat].
           inversion Hcompat.
           inversion juice_join0; subst.
           unfold join_locks in H2.
           clear - Hneq H2 H H0. unfold lockRes,lockGuts in H, H0.
           apply AMap.find_2 in H. apply AMap.find_2 in H0.
  assert (forall x e, AMap.MapsTo x e (lset js) <->
               SetoidList.InA (eqA:=@AMap.eq_key_elt lock_info) (x,e) (AMap.elements (lset js))). {
    split; intros. apply AMap.elements_1; auto.  apply AMap.elements_2; auto.
  } forget (AMap.elements (elt:=lock_info) (lset js)) as el.
  assert (SetoidList.InA (eqA:=@AMap.eq_key_elt lock_info) (l1, Some phi1) el).
   apply H1; auto.
  assert (SetoidList.InA (eqA:=@AMap.eq_key_elt lock_info) (l2, Some phi2) el).
   apply H1; auto.
 clear - H2 H3 H4 Hneq.
 revert r1 H2 H3 H4; induction el; simpl; intros.
 inv H3.
 destruct H2 as [r2 [? ?]]. destruct a.
  assert (H8: joins (Some phi1) (Some phi2));
    [ | destruct H8 as [x H8]; destruct x; inv H8; eauto].
 inv H3; [ | inv H4].
 {  (* case 1: l1=k *)
  inv H2. simpl in *. subst. inv H4. inv H2. simpl in *; subst; congruence.
  clear - H2 H H0 Hneq.
  assert (exists r1', r1 = Some r1').
  destruct r1; inv H; eauto.
  destruct H1 as [r1' ?]. subst r1.
  assert (joins (Some phi1) r2) by eauto. clear H.
  eapply join_sub_joins'; try apply H1. apply join_sub_refl.
  clear - H0 H2.
  revert r2 H0; induction el; simpl in *; intros. inv H2.
  destruct H0 as [? [? ?]]. inv H2. destruct a; inv H3. simpl in *; subst.
  exists x; auto.
  apply IHel in H0; eauto. apply join_sub_trans with x; auto.
  eexists; eauto.
 }
 { (* case 2: l2 = k *)
  inv H3. simpl in *. subst.
  assert (joins r2 (Some phi2)) by eauto.
  clear - H1 H2 H0.
  eapply join_sub_joins'; try apply H1.
  clear  H1.
  revert r2 H0; induction el; simpl in *; intros. inv H2.
  destruct H0 as [? [? ?]]. inv H2. destruct a; inv H3. simpl in *; subst.
  exists x; auto. destruct a; simpl in *.
  apply IHel in H0; auto. apply join_sub_trans with x; auto. exists l; auto.
  apply join_sub_refl.
 }
 { (* case 3 *)
  apply IHel in H0; auto.
  destruct H0. exists (Some x); 
  constructor; auto.
 }
Qed.

    
    (** There is no inteference in the thread pool *)
    (* Per-thread disjointness definition*)
    Definition disjoint_threads tp :=
      forall i j (cnti : containsThread tp i)
        (cntj: containsThread tp j) (Hneq: i <> j),
        joins (getThreadR cnti)
              (getThreadR cntj).
    (* Per-lock disjointness definition*)
    Definition disjoint_locks tp :=
      forall loc1 loc2 r1 r2,
        lockRes tp loc1 = SSome r1 ->
        lockRes tp loc2 = SSome r2 ->
        joins r1 r2.
    (* lock-thread disjointness definition*)
    Definition disjoint_lock_thread tp :=
      forall i loc r (cnti : containsThread tp i),
        lockRes tp loc = SSome r ->
        joins (getThreadR cnti)r.
    
    Variant invariant' (tp:t) := True. (* The invariant has been absorbed my mem_compat*)
     (* { no_race : disjoint_threads tp
      }.*)

    Definition invariant := invariant'.

    (*Lemmas to retrive the ex-invariant properties from the mem-compat*)
    
    (** Steps*)

    (* What follows is the lemmas needed to construct a "personal" memory
       That is a memory with the juice and Cur of a particular thread. *)
    
    Definition mapmap {A B} (def:B) (f:positive -> A -> B) (m:PMap.t A): PMap.t B:=
      (def, PTree.map f m#2).
    (* You need the memory, to make a finite tree. *)
    Definition juice2Perm (phi:rmap)(m:mem): access_map:=
      mapmap (fun _ => None) (fun block _ => fun ofs => perm_of_res (phi @ (block, ofs)) ) (getMaxPerm m).
    Definition juice2Perm_locks (phi:rmap)(m:mem): access_map:=
      mapmap (fun _ => None) (fun block _ => fun ofs => perm_of_res_lock (phi @ (block, ofs)) ) (getMaxPerm m).
    Lemma juice2Perm_canon: forall phi m, isCanonical (juice2Perm phi m).
    Proof. unfold isCanonical; reflexivity. Qed.
    Lemma juice2Perm_locks_canon: forall phi m, isCanonical (juice2Perm_locks phi m).
          Proof. unfold isCanonical; reflexivity. Qed.
    Lemma juice2Perm_nogrow: forall phi m b ofs,
        Mem.perm_order'' (perm_of_res (phi @ (b, ofs)))
                         ((juice2Perm phi m) !! b ofs).
    Proof.
      intros. unfold juice2Perm, mapmap, PMap.get.
      rewrite PTree.gmap.
      destruct (((getMaxPerm m)#2) ! b) eqn: inBounds; simpl.
      - destruct ((perm_of_res (phi @ (b, ofs)))) eqn:AA; rewrite AA; simpl; try reflexivity.
        apply perm_refl.
      - unfold Mem.perm_order''.
        destruct (perm_of_res (phi @ (b, ofs))); trivial.
    Qed.
    Lemma juice2Perm_locks_nogrow: forall phi m b ofs,
        Mem.perm_order'' (perm_of_res_lock (phi @ (b, ofs)))
                         ((juice2Perm_locks phi m) !! b ofs).
    Proof.
      intros. unfold juice2Perm_locks, mapmap, PMap.get.
      rewrite PTree.gmap.
      destruct (((getMaxPerm m)#2) ! b) eqn: inBounds; simpl.
      - destruct ((perm_of_res_lock (phi @ (b, ofs)))) eqn:AA; rewrite AA; simpl; try reflexivity.
        apply perm_refl.
      - unfold Mem.perm_order''.
        destruct (perm_of_res_lock (phi @ (b, ofs))); trivial.
    Qed.
    Lemma juice2Perm_cohere: forall phi m,
        access_cohere' m phi ->
        permMapLt (juice2Perm phi m) (getMaxPerm m).
    Proof.
      unfold permMapLt; intros.
      rewrite getMaxPerm_correct; unfold permission_at.
      eapply (po_trans _ (perm_of_res (phi @ (b, ofs))) _) .
      - specialize (H (b, ofs)); simpl in H. apply H.
      - unfold max_access_at in H.
        apply juice2Perm_nogrow.
    Qed.
    Lemma juice2Perm_locks_cohere: forall phi m,
        max_access_cohere m phi ->
        permMapLt (juice2Perm_locks phi m) (getMaxPerm m).
    Proof.
      unfold permMapLt; intros.
      rewrite getMaxPerm_correct; unfold permission_at.
      eapply (po_trans _ (perm_of_res_lock (phi @ (b, ofs))) _) .
      - specialize (H (b, ofs)); simpl in H. eapply po_trans.
        + apply H.
        + apply perm_of_res_op2.
      - apply juice2Perm_locks_nogrow.
    Qed.

    Lemma Mem_canonical_useful: forall m loc k,
        (Mem.mem_access m)#1 loc k = None.
    Proof. intros. destruct m; simpl in *.
           unfold PMap.get in nextblock_noaccess.
           pose (b:= Pos.max (TreeMaxIndex (mem_access#2) + 1 )  nextblock).
           assert (H1:  ~ Plt b nextblock).
           { intros H. assert (HH:= Pos.le_max_r (TreeMaxIndex (mem_access#2) + 1) nextblock).
             clear - H HH. unfold Pos.le in HH. unfold Plt in H.
             apply HH. eapply Pos.compare_gt_iff.
             auto. }
           assert (H2 :( b > (TreeMaxIndex (mem_access#2)))%positive ).
           { assert (HH:= Pos.le_max_l (TreeMaxIndex (mem_access#2) + 1) nextblock).
             apply Pos.lt_gt. eapply Pos.lt_le_trans; eauto.
             xomega. }
           specialize (nextblock_noaccess b loc k H1).
           apply max_works in H2. rewrite H2 in nextblock_noaccess.
           assumption.
    Qed.
    
    Lemma juic2Perm_locks_correct:
      forall r m b ofs,
        max_access_cohere m r ->
        perm_of_res_lock (r @ (b,ofs)) = (juice2Perm_locks r m) !! b ofs.
    Proof.
        intros.
        unfold juice2Perm_locks, mapmap.
        unfold PMap.get; simpl.
        rewrite PTree.gmap. 
        rewrite PTree.gmap1; simpl.
        destruct ((snd (Mem.mem_access m)) ! b) eqn:search; simpl.
        - auto.
        - generalize (H (b, ofs)) => /po_trans.
          move =>  /(_ (perm_of_res_lock (r @ (b, ofs)))) /(_ (perm_of_res_op2 _)).
          unfold max_access_at. unfold access_at. unfold PMap.get; simpl.
          rewrite search. rewrite Mem_canonical_useful.
          unfold perm_of_res_lock. destruct ( r @ (b, ofs)); auto.
          destruct k; auto. simpl.
          destruct (perm_of_sh Share.bot (pshare_sh p) ) eqn: HH; auto.
          intros; exfalso; assumption.
          destruct (perm_of_sh t0 (pshare_sh p)); auto; intro HH;
          destruct (perm_of_sh Share.bot (pshare_sh p)); 
          inversion HH; reflexivity.
    Qed.

    Lemma juic2Perm_correct:
      forall r m b ofs,
        access_cohere' m r ->
        perm_of_res (r @ (b,ofs)) = (juice2Perm r m) !! b ofs.
    Proof.
        intros.
        unfold juice2Perm, mapmap.
        unfold PMap.get; simpl.
        rewrite PTree.gmap. 
        rewrite PTree.gmap1; simpl.
        destruct ((snd (Mem.mem_access m)) ! b) eqn:search; simpl.
        - auto.
        - generalize (H (b, ofs)).
          unfold max_access_at. unfold access_at. unfold PMap.get; simpl.
          rewrite search. rewrite Mem_canonical_useful.
          unfold perm_of_res. destruct ( r @ (b, ofs)).
          destruct (eq_dec t0 Share.bot); auto; simpl.
          intros HH. contradiction HH.
          destruct k;  try solve [intros HH;inversion HH].
          destruct (perm_of_sh t0 (pshare_sh p)); auto.
          intros HH;inversion HH.
          intros HH;inversion HH.
      Qed.
    
    Definition juicyRestrict {phi:rmap}{m:Mem.mem}(coh:access_cohere' m phi): Mem.mem:=
      restrPermMap (juice2Perm_cohere coh).
    Definition juicyRestrict_locks {phi:rmap}{m:Mem.mem}(coh:max_access_cohere m phi): Mem.mem:=
      restrPermMap (juice2Perm_locks_cohere coh).
    Lemma juicyRestrictContents: forall phi m (coh:access_cohere' m phi),
        forall loc, contents_at m loc = contents_at (juicyRestrict coh) loc.
    Proof. unfold juicyRestrict; intros. rewrite restrPermMap_contents; reflexivity. Qed.
    Lemma juicyRestrictMax: forall phi m (coh:access_cohere' m phi),
        forall loc, max_access_at m loc = max_access_at (juicyRestrict coh) loc.
    Proof. unfold juicyRestrict; intros. rewrite restrPermMap_max; reflexivity. Qed.
    Lemma juicyRestrictNextblock: forall phi m (coh:access_cohere' m phi),
        Mem.nextblock m = Mem.nextblock (juicyRestrict coh).
    Proof. unfold juicyRestrict; intros. rewrite restrPermMap_nextblock; reflexivity. Qed.
    Lemma juicyRestrictContentCoh: forall phi m (coh:access_cohere' m phi) (ccoh:contents_cohere m phi),
        contents_cohere (juicyRestrict coh) phi.
    Proof.
      unfold contents_cohere; intros. rewrite <- juicyRestrictContents.
      eapply ccoh; eauto.
    Qed.
    Lemma juicyRestrictMaxCoh: forall phi m (coh:access_cohere' m phi) (ccoh:max_access_cohere m phi),
        max_access_cohere (juicyRestrict coh) phi.
    Proof.
      unfold max_access_cohere; intros.
      repeat rewrite <- juicyRestrictMax.
      repeat rewrite <- juicyRestrictNextblock.
      apply ccoh.
    Qed.
    Lemma juicyRestrictAllocCoh: forall phi m (coh:access_cohere' m phi) (ccoh:alloc_cohere m phi),
        alloc_cohere (juicyRestrict coh) phi.
    Proof.
      unfold alloc_cohere; intros.
      rewrite <- juicyRestrictNextblock in H.
      apply ccoh; assumption.
    Qed.

    Lemma juicyRestrictCurEq:
      forall (phi : rmap) (m : mem) (coh : access_cohere' m phi)
     (loc : Address.address),
        (access_at (juicyRestrict coh) loc) Cur = (perm_of_res (phi @ loc)).
    Proof.
      intros. unfold juicyRestrict.
      unfold access_at.
      destruct (restrPermMap_correct (juice2Perm_cohere coh) loc#1 loc#2) as [MAX CUR].
      unfold permission_at in *.
      rewrite CUR.
      unfold juice2Perm.
      unfold mapmap. 
      unfold PMap.get.
      rewrite PTree.gmap; simpl.
      destruct ((PTree.map1
             (fun f : Z -> perm_kind -> option permission => f^~ Max)
             (Mem.mem_access m)#2) ! (loc#1)) as [VALUE|]  eqn:THING.
      - destruct loc; simpl.
        destruct ((perm_of_res (phi @ (b, z)))) eqn:HH; rewrite HH; reflexivity. 
      - simpl. rewrite PTree.gmap1 in THING.
        destruct (((Mem.mem_access m)#2) ! (loc#1)) eqn:HHH; simpl in THING; try solve[inversion THING].
        unfold access_cohere' in coh.
        unfold max_access_at, access_at in coh. unfold PMap.get in coh.
        generalize (coh loc).
        rewrite HHH; simpl.
        
        rewrite Mem_canonical_useful.
        destruct (perm_of_res (phi @ loc)); auto.
        intro H; inversion H.
    Qed.
    
    Lemma juicyRestrictAccCoh: forall phi m (coh:access_cohere' m phi),
        access_cohere (juicyRestrict coh) phi.
    Proof.
      unfold access_cohere; intros.
      rewrite juicyRestrictCurEq.
      destruct ((perm_of_res (phi @ loc))) eqn:HH; try rewrite HH; simpl; reflexivity.
    Qed.

    Lemma po_perm_of_res: forall r,
       Mem.perm_order''  (perm_of_res' r) (perm_of_res r). 
    Proof.
      rewrite /perm_of_res /perm_of_res' => r.
      destruct r; try solve[ apply po_refl].
      assert (Mem.perm_order'' (perm_of_sh t0 (pshare_sh p)) (Some Nonempty)).
      { destruct (perm_of_sh t0 (pshare_sh p)) eqn:HH; try solve[constructor].
        apply perm_of_empty_inv in HH; destruct HH as [AA BB].
        exfalso; apply (juicy_mem_ops.Abs.pshare_sh_bot _ BB). }
      destruct k; first[ apply po_refl | assumption].
    Qed.
      
      
    Lemma max_acc_coh_acc_coh: forall m phi,
        max_access_cohere m phi -> access_cohere' m phi.
    Proof.
      move=> m phi mac loc.
      move: mac => /(_ loc) mac.
      eapply po_trans; eauto.
      apply po_perm_of_res.
    Qed.

    Definition juicyRestrict':=
      fun phi m macoh => @juicyRestrict phi m (max_acc_coh_acc_coh macoh).

    Lemma juicyRestrictAccCoh': forall phi m (coh:max_access_cohere m phi),
        access_cohere (juicyRestrict' coh) phi.
    Proof.
      unfold access_cohere; intros.
      rewrite juicyRestrictCurEq.
      destruct ((perm_of_res (phi @ loc))) eqn:HH; try rewrite HH; simpl; reflexivity.
    Qed.

    (*Move this to veric.juicy_mem_lemmas.v *)
    Lemma po_join_sub': forall r1 r2 : resource,
       join_sub r2 r1 ->
       Mem.perm_order'' (perm_of_res' r1) (perm_of_res' r2).
         
         intros r1 r2[r J]; inversion J; subst; simpl.
         - if_tac.
           + subst.
             if_tac.
             * eauto with *.
             * exfalso.
               pose proof Share.lub_upper1 rsh1 rsh2.
               inversion RJ as [_ E].
               rewrite E in H0.
               eauto with *.
           + if_tac; constructor.
         - destruct k; try solve [constructor].
           + apply po_join_sub_sh.
             * eexists; eauto.
             * apply join_sub_refl.
           + apply po_join_sub_sh.
             * eexists; eauto.
             * apply join_sub_refl.
           + apply po_join_sub_sh.
             * eexists; eauto.
             * apply join_sub_refl.
           + apply po_join_sub_sh.
             * eexists; eauto.
             * apply join_sub_refl.
         - destruct k.
           + if_tac.
             * hnf. if_tac; apply I.
             * apply perm_order''_trans with (perm_of_sh rsh1 (pshare_sh sh)).
               -- apply po_join_sub_sh.
                  ++ eexists; eauto.
                  ++ apply join_sub_refl.
               -- destruct  (perm_of_sh rsh1 (pshare_sh sh)) eqn:E.
                  ++ constructor.
                  ++ pose proof @perm_of_empty_inv _ _ E. tauto.
                     
           + if_tac.
             * hnf. if_tac; apply I.
             * apply perm_order''_trans with (perm_of_sh rsh1 (pshare_sh sh)).
               -- apply po_join_sub_sh.
                  ++ eexists; eauto.
                  ++ apply join_sub_refl.
               -- destruct  (perm_of_sh rsh1 (pshare_sh sh)) eqn:E.
                  ++ constructor.
                  ++ pose proof @perm_of_empty_inv _ _ E. tauto.
                     
           + if_tac.
             * hnf. if_tac; apply I.
             * apply perm_order''_trans with (perm_of_sh rsh1 (pshare_sh sh)).
               -- apply po_join_sub_sh.
                  ++ eexists; eauto.
                  ++ apply join_sub_refl.
               -- destruct  (perm_of_sh rsh1 (pshare_sh sh)) eqn:E.
                  ++ constructor.
                  ++ pose proof @perm_of_empty_inv _ _ E. tauto.
                     
           + if_tac.
             * hnf. if_tac; apply I.
             * apply perm_order''_trans with (perm_of_sh rsh1 (pshare_sh sh)).
               -- apply po_join_sub_sh.
                  ++ eexists; eauto.
                  ++ apply join_sub_refl.
               -- destruct  (perm_of_sh rsh1 (pshare_sh sh)) eqn:E.
                  ++ constructor.
                  ++ pose proof @perm_of_empty_inv _ _ E. tauto.
                    
         - destruct k; try constructor.
           + apply po_join_sub_sh; eexists; eauto.
           + apply po_join_sub_sh; eexists; eauto.
           + apply po_join_sub_sh; eexists; eauto.
           + apply po_join_sub_sh; eexists; eauto.
         - constructor.
    Qed.
      
    Lemma mem_access_coh_sub: forall phi1 phi2 m,
          max_access_cohere m phi1 ->
          join_sub phi2 phi1 ->
          max_access_cohere m phi2.
    Proof.
      rewrite /max_access_cohere => phi1 phi2 m H H0 loc.
      eapply po_trans; eauto.
      eapply po_join_sub'.
      apply resource_at_join_sub; assumption.
    Qed.
    
    Lemma mem_cohere_sub: forall phi1 phi2 m,
          mem_cohere' m phi1 ->
          join_sub phi2 phi1 ->
          mem_cohere' m phi2.
    Proof.
      intros. constructor.
      - unfold contents_cohere; intros.
        eapply resource_at_join_sub with (l:= loc) in H0.
        rewrite H1 in H0.
        inversion H; clear - H0 cont_coh0.
        destruct H0 as [X H0].
        inversion H0; subst.
        + symmetry in H. apply cont_coh0 in H; assumption.
        + symmetry in H6; apply cont_coh0 in H6; assumption.
      (* - intros loc.
        eapply resource_at_join_sub with (l:= loc) in H0.
        eapply po_join_sub  in H0.
        eapply po_trans; eauto.
        inversion H; auto. *)
      - inversion H.
        eapply mem_access_coh_sub; eauto.
      - unfold alloc_cohere.
        inversion H. clear - H0 all_coh0.
        intros loc HH; apply all_coh0 in HH.
        apply resource_at_join_sub with (l:= loc) in H0.
        rewrite HH in H0.
        destruct H0 as [X H0].
        inversion H0; auto.
        apply split_identity in RJ; auto.
        apply identity_share_bot in RJ; subst; auto.
    Qed.

    Lemma compatible_threadRes_sub:
        forall js i (cnt:containsThread js i),
        forall all_juice,
          join_all js all_juice ->
          join_sub (ThreadPool.getThreadR cnt) all_juice.
      Proof.
        intros. inv H.
        assert (H9: join_sub (Some (getThreadR cnt)) (Some all_juice));
       [ | destruct H9 as [x H9]; inv H9; [apply join_sub_refl | eexists; eauto]].
       apply join_sub_trans with (Some r0); [ | eexists; eauto].
       clear - H0.
       assert (H9: join_sub (getThreadR cnt) r0);
       [ | destruct H9 as [x H9]; exists (Some x); constructor; auto].
       unfold getThreadR. unfold join_threads in H0.
       unfold getThreadsR in H0.
      destruct js; simpl in *.
      pose proof (mem_ord_enum (n:= n num_threads0)).
      
      specialize (H (Ordinal (n:=n num_threads0) (m:=i) cnt)) .
      unfold join_list in H0.
      
      simpl in H0.

      
      replace (enums_equality.enum num_threads0) with (ord_enum (n num_threads0)) in H0.
      forget (ord_enum (n num_threads0)) as el.
      forget ((Ordinal (n:=n num_threads0) (m:=i) cnt)) as j.
      revert H H0; clear; revert r0; induction el; intros. inv H.
      unfold in_mem in H. unfold pred_of_mem in H. simpl in H.
      pose proof @orP.
      specialize (H1 (j == a)(pred_of_eq_seq (T:=ordinal_eqType (n num_threads0)) el j)).
    destruct ((j == a)
              || pred_of_eq_seq (T:=ordinal_eqType (n num_threads0)) el j); inv H.
    inv H1. destruct H.
    pose proof (@eqP _ j a). destruct (j==a); inv H; inv H1.
    simpl in H0. destruct H0 as [? [? ?]].
    exists x; auto.
    unfold pred_of_eq_seq in H.
    destruct H0 as [? [? ?]].
    apply (IHel x) in H; auto. apply join_sub_trans with x; auto. eexists; eauto.

 (*   Lemma ord_enum_enum:
      forall n,
        ord_enum n = enum n.
          Set Printing All.
    Ad mitted.*)
    apply ord_enum_enum.
      Qed.

      
    Lemma mem_compat_thread_max_cohere {tp m} (compat: mem_compatible tp m):
      forall {i} cnti,
        max_access_cohere m (@getThreadR i tp cnti).
    Proof.
      destruct compat as [x compat] => i cnti loc.
      apply po_trans with (b:= perm_of_res' (x @ loc)). 
      - inversion compat. inversion all_cohere0. apply max_coh0.
      - (*This comes from *)
        apply po_join_sub'.
        apply resource_at_join_sub.
        eapply compatible_threadRes_sub.
        inversion compat; inversion all_cohere0; assumption.
    Qed.
      
    Lemma thread_mem_compatible: forall tp m,
        mem_compatible tp m ->
        mem_thcohere tp m.
    Proof. intros. destruct H as [allj H].
           inversion H.
           unfold mem_thcohere; intros.
           eapply compatible_threadRes_sub  with (cnt:=cnt)in juice_join0.
           eapply mem_cohere_sub; eauto.
    Qed.

    Lemma compatible_lockRes_sub: forall js l phi,
        ThreadPool.lockRes js l = Some (Some phi) ->
        forall all_juice,
          join_all js all_juice ->
          join_sub phi all_juice.
    Proof.
     intros.
     inv H0.
     assert (H9: join_sub (Some phi) (Some all_juice));
       [ | destruct H9 as [x H9]; inv H9; [apply join_sub_refl | eexists; eauto]].
     apply join_sub_trans with (b:=r1); [ | eexists; eauto].
     clear - H H2.
     hnf in H2. unfold lockRes in H.
     apply AMap.find_2 in H. unfold lockGuts in *.
     apply AMap.elements_1 in H. unfold lock_info in *.
     forget (AMap.elements (elt:= option rmap) (lset js)) as el.
     revert r1 H2; induction el; simpl; intros. inv H.
     destruct H2 as [? [? ?]]. destruct a; simpl in *. inv H. inv H3. simpl in *; subst.
     exists x; auto. apply IHel in H1; auto.
     apply join_sub_trans with x; auto. exists o; auto.
   Qed.
    
    Lemma lock_mem_compatible: forall tp m,
        mem_compatible tp m ->
        mem_lock_cohere (lockGuts tp) m.
    Proof. intros.  destruct H as [allj H].
           inversion H.
           unfold mem_thcohere; intros.
          unfold mem_lock_cohere; intros.
          eapply compatible_lockRes_sub in juice_join0; eauto.
          eapply mem_cohere_sub; eauto.
    Qed.
    
    
    (* PERSONAL MEM: Is the contents of the global memory, 
       with the juice of a single thread and the Cur that corresponds to that juice.*)
    Definition acc_coh:= fun m phi pr => @max_acc_coh_acc_coh m phi (max_coh pr).
    Definition personal_mem {m phi} (pr : mem_cohere' m phi) : juicy_mem:=
      mkJuicyMem
        (@juicyRestrict phi m (acc_coh pr))
        phi
        (juicyRestrictContentCoh (acc_coh pr) (cont_coh pr))
        (juicyRestrictAccCoh (acc_coh pr)) 
        (juicyRestrictMaxCoh (acc_coh pr) (max_coh pr))
        (juicyRestrictAllocCoh (acc_coh pr) (all_coh pr)).
    
    Definition juicy_sem := (FSem.F _ _ JuicyFSem.t) _ _ the_sem.
    (* Definition juicy_step := (FSem.step _ _ JuicyFSem.t) _ _ the_sem. *)
    
    Program Definition first_phi (tp : thread_pool) : rmap := (@getThreadR 0%nat tp _).
    Next Obligation.
      intros tp.
      unfold containsThread.
      destruct num_threads.
      simpl.
      ssromega.
    Defined.
    
    Program Definition level_tp (tp : thread_pool) := level (first_phi tp).
    
    Definition tp_level_is_above n tp :=
      (forall i (cnti : containsThread tp i), le n (level (getThreadR cnti))) /\
      (forall i phi, lockRes tp i = Some (Some phi) -> le n (level phi)).
    
    Definition tp_level_is n tp :=
      (forall i (cnti : containsThread tp i), level (getThreadR cnti) = n) /\
      (forall i phi, lockRes tp i = Some (Some phi) -> level phi = n).

    (*
    Lemma mem_compatible_same_level tp m :
      mem_compatible tp m -> tp_level_is (level_tp tp) tp.
    Proof.
      intros M.
      pose proof disjoint_threads_compat M as DT.
      pose proof disjoint_locks_t_hread_compat M as DLT.
      destruct M as [Phi M].
      unfold level_tp, first_phi.
      split.
      - intros i cnti.
        destruct (eq_dec i 0%nat).
        + subst.
          repeat f_equal.
          now apply cnt_irr.
        + apply rmap_join_eq_level.
          apply DT.
          auto.
      - intros i phi E.
        apply rmap_join_eq_level.
        rewrite joins_sym.
        eapply (DLT _); eauto.
    Qed. *)
    
    Definition cnt_from_ordinal tp : forall i : ordinal (pos.n (num_threads tp)), containsThread tp i.
      intros [i pr]; apply pr. Defined.
    
    Definition age_tp_to (k : nat) (tp : thread_pool) : thread_pool :=
      match tp with
        mk n pool maps lset =>
        mk n pool
           ((age_to k) oo maps)
           (AMap.map (option_map (age_to k)) lset)
      end.
    
    Lemma level_age_tp_to tp k : tp_level_is_above k tp -> tp_level_is k (age_tp_to k tp).
    Proof.
      intros [T L]; split.
      - intros i cnti.
        destruct tp.
        apply level_age_to.
        apply T.
      - intros i phi' IN. destruct tp as [n thds phis lset].
        simpl in IN.
        unfold lockRes in IN; simpl in IN.
        destruct (@AMap_find_map_inv lock_info _ _ _ _ _ IN) as [phi [IN' E]].
        destruct phi as [phi | ]. 2:inversion E.
        simpl in E. injection E as ->.
        apply level_age_to.
        eapply L, IN'.
    Qed.
    
    Lemma map_compose {A B C} (g : A -> B) (f : B -> C) l : map (f oo g) l = map f (map g l).
    Proof.
      induction l; simpl; auto. rewrite IHl. auto.
    Qed.

    Lemma join_list_age_to k l Phi :
      le k (level Phi) ->
      join_list l Phi ->
      join_list (map (age_to k) l) (age_to k Phi).
    Proof.
      revert Phi. induction l as [| phi l IHl]; intros Phi L; simpl.
      - apply age_to_identy.
      - intros [a [aphi la]].
        apply IHl in la.
        + exists (age_to k a); split; auto.
          apply age_to_join_eq; auto.
        + cut (level a = level Phi); [ intuition | ].
          eapply join_level; eauto.
    Qed.
    
    Lemma join_list'_age_to k (l : list (option res)) (Phi : option res) :
      (match Phi with None => Logic.True | Some phi => le k (level phi) end) ->
      join_list' l Phi ->
      join_list' (map (option_map (age_to k)) l) (option_map (age_to k) Phi).
    Proof.
      revert Phi. induction l as [| phi l IHl]; intros Phi L; simpl.
      - destruct Phi; simpl; auto. discriminate.
      - intros [[a | ] [aphi la]].
        + destruct Phi as [Phi|]; [|inversion aphi].
          apply IHl in la.
          * exists (Some (age_to k a)); split; auto.
            inversion aphi; subst; simpl; constructor.
            apply age_to_join_eq; auto.
          * cut (level a = level Phi); [ intuition | ]. 
            inversion aphi; subst; simpl; auto.
            eapply join_level; eauto.
        + apply IHl in la.
          * exists None; split; auto.
            inversion aphi; subst; simpl; constructor.
          * constructor.
    Qed.
    
    Lemma join_all_age_to k tp Phi :
      le k (level Phi) ->
      join_all tp Phi ->
      join_all (age_tp_to k tp) (age_to k Phi).
    Proof.
      intros L J. inversion J as [r rT rL r' JT JL JTL]; subst.
      pose (rL' := option_map (age_to k) rL).
      destruct tp as [N pool phis lset]; simpl in *.
      eapply AllJuice with (age_to k rT) rL'.
      - {
          hnf in *; simpl in *.
          unfold getThreadsR in *; simpl in *.
          rewrite map_compose.
          apply join_list_age_to; auto.
          assert (E : level rT = level Phi). {
            inversion JTL as [ | a H H0 H2 | a1 a2 a3 JJ H H1 H0]; subst. auto.
            pose proof join_level _ _ _ JJ. intuition. }
          rewrite E; auto.
        }
      - hnf. (simpl ThreadPool.lset).
        hnf in JL. simpl in JL.
        revert JL.
        rewrite AMap_map.
        apply join_list'_age_to.
        destruct rL as [rL|]; auto.
        assert (E : level rL = level Phi). {
          inversion JTL as [ | a H H0 H2 | a1 a2 a3 JJ H H1 H0]; subst. auto.
          pose proof join_level _ _ _ JJ. intuition. }
        rewrite E; auto.
      - destruct rL as [rL | ]; unfold rL'.
        + constructor. apply age_to_join_eq; eauto. inversion JTL; eauto.
        + inversion JTL. constructor.
    Qed.

    Lemma perm_of_age rm age loc :
      perm_of_res (age_to age rm @ loc) = perm_of_res (rm @ loc).
    Proof.
      apply age_to_ind; [ | reflexivity].
      intros x y A <- .
      destruct (x @ loc) as [sh | rsh sh k p | k p] eqn:E.
      - destruct (age1_NO x y loc sh A) as [[]_]; eauto.
      - destruct (age1_YES' x y loc rsh sh k A) as [[p' ->] _]; eauto.
      - destruct (age1_PURE x y loc k A) as [[p' ->] _]; eauto.
    Qed.

    Lemma perm_of_age_lock rm age loc :
      perm_of_res_lock (age_to age rm @ loc) = perm_of_res_lock (rm @ loc).
    Proof.
      apply age_to_ind; [ | reflexivity].
      intros x y A <- .
      destruct (x @ loc) as [sh | rsh sh k p | k p] eqn:E.
      - destruct (age1_NO x y loc sh A) as [[]_]; eauto.
      - destruct (age1_YES' x y loc rsh sh k A) as [[p' ->] _]; eauto.
      - destruct (age1_PURE x y loc k A) as [[p' ->] _]; eauto.
    Qed.
    
    Lemma almost_empty_perm: forall rm,
        almost_empty rm ->
        forall loc, Mem.perm_order'' (Some Nonempty) (perm_of_res (rm @ loc)).
    Proof.
      intros rm H loc.
      specialize (H loc).
      destruct (rm @ loc) eqn:res.
      - simpl (perm_of_res(NO t0)).
        destruct (eq_dec t0 Share.bot); auto; constructor.
      - destruct k;
          try (simpl; constructor).
        specialize (H t0 p (VAL m) p0 ltac:(reflexivity) m).
        contradict H; reflexivity.
      - simpl; constructor.
    Qed.

    Lemma cnt_age {js i age} :
        containsThread (age_tp_to age js) i ->
        containsThread js i.
    Proof.
      destruct js; auto.
    Qed.
    
    Lemma cnt_age' {js i age} :
        containsThread js i ->
        containsThread (age_tp_to age js) i.
    Proof.
      destruct js; auto.
    Qed.

    Lemma age_getThreadCode:
      forall i tp age cnt cnt',
        @getThreadC i tp cnt = @getThreadC i (age_tp_to age tp) cnt'.
    Proof.
      intros i tp age cnt cnt'.
      destruct tp; simpl.
      f_equal. f_equal.
      apply cnt_irr.
    Qed.
      
    Inductive juicy_step genv {tid0 tp m} (cnt: containsThread tp tid0)
      (Hcompatible: mem_compatible tp m) : thread_pool -> mem -> list mem_event -> Prop :=
    | step_juicy :
        forall (tp':thread_pool) c jm jm' m' (c' : code),
          forall (Hpersonal_perm:
               personal_mem (thread_mem_compatible Hcompatible cnt) = jm)
            (Hinv : invariant tp)
            (Hthread: getThreadC cnt = Krun c)
            (Hcorestep: corestep juicy_sem genv c jm c' jm')
            (Htp': tp' = @updThread tid0 (age_tp_to (level jm') tp) (cnt_age' cnt) (Krun c') (m_phi jm'))
            (Hm': m_dry jm' = m'),
            juicy_step genv cnt Hcompatible tp' m' [::].

    Definition pack_res_inv (R: pred rmap) := SomeP rmaps.Mpred (fun _ => R) .

    Notation Kblocked := (threadPool.Kblocked).
    Open Scope Z_scope.
    Inductive syncStep' {isCoarse: bool} genv {tid0 tp m}
              (cnt0:containsThread tp tid0)(Hcompat:mem_compatible tp m):
      thread_pool -> mem -> sync_event -> Prop :=
    | step_acquire :
        forall (tp' tp'' tp''':thread_pool) c m0 m1 b ofs d_phi psh phi phi' m' pmap_tid',
          forall
            (Hinv : invariant tp)
            (Hthread: getThreadC cnt0 = Kblocked c)
            (Hat_external: at_external the_sem c =
                           Some (LOCK, Vptr b ofs::nil))
            (Hcompatible: mem_compatible tp m)
            (*Hpersonal_perm: 
               personal_mem cnt0 Hcompatible = jm*)
            (Hpersonal_juice: getThreadR cnt0 = phi)
            (sh:Share.t)(R:pred rmap)
            (HJcanwrite: phi@(b, Int.intval ofs) = YES sh psh (LK LKSIZE) (pack_res_inv R))
            (Hrestrict_map0: juicyRestrict_locks
                              (mem_compat_thread_max_cohere Hcompat cnt0) = m0)
            (Hload: Mem.load Mint32 m0 b (Int.intval ofs) = Some (Vint Int.one))
            (*Hrestrict_pmap:
               permissions.restrPermMap
                 (mem_compatible_locks_ltwritable Hcompatible)
                  = m1*)
            (Hset_perm: setPermBlock (Some Writable)
                                       b (Int.intval ofs) (juice2Perm_locks phi m) LKSIZE_nat = pmap_tid')
            (Hlt': permMapLt pmap_tid' (getMaxPerm m))
            (* This following condition is not needed:
               It should follow from the mem_compat statement... somehow... *)
            (Hrestrict_pmap: restrPermMap Hlt' = m1)
            (Hstore: Mem.store Mint32 m1 b (Int.intval ofs) (Vint Int.zero) = Some m')
            (His_unlocked: lockRes tp (b, Int.intval ofs) = SSome d_phi )
            (Hadd_lock_res: join phi d_phi  phi')  
            (Htp': tp' = updThread cnt0 (Kresume c Vundef) phi')
            (Htp'': tp'' = updLockSet tp' (b, Int.intval ofs) None )
            (Htp''': tp''' = age_tp_to (level phi - 1)%coq_nat tp''),
            syncStep' genv cnt0 Hcompat tp''' m' (acquire (b, Int.intval ofs) None)                
    | step_release :
        forall  (tp' tp'' tp''':thread_pool) c m0 m1 b ofs psh  (phi d_phi :rmap) (R: pred rmap) phi' m' pmap_tid',
          forall
            (Hinv : invariant tp)
            (Hthread: getThreadC cnt0 = Kblocked c)
            (Hat_external: at_external the_sem c =
                           Some (UNLOCK, Vptr b ofs::nil))
            (Hcompatible: mem_compatible tp m)
            (* Hpersonal_perm: 
               personal_mem cnt0 Hcompatible = jm *)
            (Hpersonal_juice: getThreadR cnt0 = phi)
            (sh:Share.t)
            (HJcanwrite: phi@(b, Int.intval ofs) = YES sh psh (LK LKSIZE) (pack_res_inv R))
            (Hrestrict_map0: juicyRestrict_locks
                              (mem_compat_thread_max_cohere Hcompat cnt0) = m0)
            (Hload: Mem.load Mint32 m0 b (Int.intval ofs) = Some (Vint Int.zero))
            (*Hrestrict_pmap:
               permissions.restrPermMap
                 (mem_compatible_locks_ltwritable Hcompatible)
                  = m1*)
            (Hset_perm: setPermBlock (Some Writable)
                                       b (Int.intval ofs) (juice2Perm_locks phi m) LKSIZE_nat = pmap_tid')
            (Hlt': permMapLt pmap_tid' (getMaxPerm m))
            (* This following condition is not needed:
               It should follow from the mem_compat statement... somehow... *)
            (Hrestrict_pmap: restrPermMap Hlt' = m1)
            (Hstore: Mem.store Mint32 m1 b (Int.intval ofs) (Vint Int.one) = Some m')
            (His_locked: lockRes tp (b, Int.intval ofs) = SNone )
            (Hsat_lock_inv: R (age_by 1 d_phi))
            (Hrem_lock_res: join d_phi phi' phi)
            (Htp': tp' = updThread cnt0 (Kresume c Vundef) phi')
            (Htp'': tp'' =
                    updLockSet tp' (b, Int.intval ofs) (Some d_phi))
            (Htp''': tp''' = age_tp_to (level phi - 1)%coq_nat tp''),
            syncStep' genv cnt0 Hcompat tp''' m' (release (b, Int.intval ofs) None)      
    | step_create :
        forall  (tp_upd tp':thread_pool) c c_new vf arg jm (d_phi phi': rmap) b ofs (* P Q *),
          forall
            (Hinv : invariant tp)
            (Hthread: getThreadC cnt0 = Kblocked c)
            (Hat_external: at_external the_sem c =
                           Some (CREATE, vf::arg::nil))
            (Hinitial: initial_core the_sem genv vf (arg::nil) = Some c_new)
            (Hfun_sepc: vf = Vptr b ofs)
            (Hcompatible: mem_compatible tp m)
            (Hpersonal_perm: 
               personal_mem (thread_mem_compatible Hcompatible cnt0) = jm)
            (Hrem_fun_res: join d_phi phi' (m_phi jm))
            (Htp': tp_upd = updThread cnt0 (Kresume c Vundef) phi')
            (Htp'': tp' = age_tp_to (level (m_phi jm) - 1)%coq_nat (addThread tp_upd vf arg d_phi)),
            syncStep' genv cnt0 Hcompat tp' m (spawn (b, Int.intval ofs) None None)
    | step_mklock :
        forall  (tp' tp'': thread_pool)  jm c b ofs R ,
          let: phi := m_phi jm in
          forall
            phi' m'
            (Hinv : invariant tp)
            (Hthread: getThreadC cnt0 = Kblocked c)
            (Hat_external: at_external the_sem c =
                           Some (MKLOCK, Vptr b ofs::nil))
            (Hcompatible: mem_compatible tp m)
            (*Hright_juice:  m = m_dry jm*)
            (Hpersonal_perm: 
               personal_mem (thread_mem_compatible Hcompatible cnt0) = jm)
            (Hpersonal_juice: getThreadR cnt0 = phi)
            (*Check I have the right permission to mklock and the right value (i.e. 0) *)
            (*Haccess: address_mapsto LKCHUNK (Vint Int.zero) sh Share.top (b, Int.intval ofs) phi*)
            (Hstore:
               Mem.store Mint32 (m_dry jm) b (Int.intval ofs) (Vint Int.zero) = Some m')
            (* [Hrmap] replaced: [Hct], [Hlock], [Hj_forward] and [levphi'].
               This says that phi and phi' coincide everywhere except in adr_range,
               and specifies how phi and phi' should differ in adr_range
               (in particular, they have equal shares, pointwise) *)
            (Hrmap : rmap_makelock phi phi' (b, Int.unsigned ofs) R LKSIZE)
            (Htp': tp' = updThread cnt0 (Kresume c Vundef) phi')
            (Htp'': tp'' = age_tp_to (level phi - 1)%coq_nat 
                    (updLockSet tp' (b, Int.intval ofs) None )),
            syncStep' genv cnt0 Hcompat tp'' m' (mklock (b, Int.intval ofs))
    | step_freelock :
        forall  (tp' tp'': thread_pool) c b ofs phi R phi',
          forall
            (Hinv : invariant tp)
            (Hthread: getThreadC cnt0 = Kblocked c)
            (Hat_external: at_external the_sem c =
                           Some (FREE_LOCK, Vptr b ofs::nil))
            (Hcompatible: mem_compatible tp m)
            (Hpersonal_juice: getThreadR cnt0 = phi)
            (*First check the lock is acquired:*)
            (His_acq: lockRes tp (b, (Int.intval ofs)) = SNone)
            (*Relation between rmaps:*)
            (Hrmap : rmap_freelock phi phi' m (b, Int.unsigned ofs) R LKSIZE)
            (Htp': tp' = updThread cnt0 (Kresume c Vundef) phi')
            (Htp'': tp'' = age_tp_to (level phi - 1)%coq_nat 
                    (remLockSet tp' (b, Int.intval ofs) )),
            syncStep' genv cnt0 Hcompat  tp'' m (freelock (b, Int.intval ofs))
                      
    | step_acqfail :
        forall  c b ofs jm psh m1,
          let: phi := m_phi jm in
          forall
            (Hinv : invariant tp)
            (Hthread: getThreadC cnt0 = Kblocked c)
            (Hat_external: at_external the_sem c =
                           Some (LOCK, Vptr b ofs::nil))
            (Hcompatible: mem_compatible tp m)
            (Hpersonal_perm: 
               personal_mem (thread_mem_compatible Hcompatible cnt0) = jm)
            (Hrestrict_map: juicyRestrict_locks
                              (mem_compat_thread_max_cohere Hcompat cnt0) = m1)
            (sh:Share.t)(R:pred rmap)
            (HJcanwrite: phi@(b, Int.intval ofs) = YES sh psh (LK LKSIZE) (pack_res_inv R))
            (Hload: Mem.load Mint32 m1 b (Int.intval ofs) = Some (Vint Int.zero)),
            syncStep' genv cnt0 Hcompat tp m (failacq (b,Int.intval ofs)).
    
    Definition threadStep (genv:G): forall {tid0 ms m},
        containsThread ms tid0 -> mem_compatible ms m ->
        thread_pool -> mem -> list mem_event -> Prop:=
      @juicy_step genv.

    Lemma threadStep_equal_run:
    forall g i tp m cnt cmpt tp' m' tr, 
      @threadStep g i tp m cnt cmpt tp' m' tr ->
      forall j,
        (exists cntj q, @getThreadC j tp cntj = Krun q) <->
        (exists cntj' q', @getThreadC j tp' cntj' = Krun q').
    Proof.
      intros. split.
      - intros [cntj [ q running]].
        inversion H; subst.
        assert (cntj':=cntj).
        eapply cnt_age' in cntj'.
        eapply (cntUpdate (Krun c') (m_phi jm') (cnt_age' cntj)) in cntj'.
        exists cntj'.
        destruct (NatTID.eq_tid_dec i j).
        + subst j; exists c'.
          rewrite gssThreadCode; reflexivity.
        + exists q.
          rewrite gsoThreadCode; auto.
          generalize running; destruct tp; simpl.
          intros RUN; rewrite <- RUN.
          f_equal. f_equal.
          apply cnt_irr.
      - intros [cntj' [ q' running]].
        inversion H; subst.
        assert (cntj:=cntj').
        eapply cnt_age in cntj.
        eapply cntUpdate' with(c0:=Krun c')(p:=m_phi jm') in cntj; eauto.
        exists cntj.
        destruct (NatTID.eq_tid_dec i j).
        + subst j; exists c.
          rewrite <- Hthread.
          f_equal.
          apply cnt_irr.
        + exists q'.
          rewrite gsoThreadCode in running; auto.
          rewrite <- running.
          destruct tp; simpl.
          f_equal. f_equal.
          apply cnt_irr.
    Qed.
          
    Definition syncStep (isCoarse:bool) (genv:G):
      forall {tid0 ms m}, containsThread ms tid0 -> mem_compatible ms m ->
                     thread_pool -> mem -> sync_event ->  Prop:=
      @syncStep' isCoarse genv.

    
  Lemma syncstep_equal_run:
    forall b g i tp m cnt cmpt tp' m' tr, 
      @syncStep b g i tp m cnt cmpt tp' m' tr ->
      forall j,
        (exists cntj q, @getThreadC j tp cntj = Krun q) <->
        (exists cntj' q', @getThreadC j tp' cntj' = Krun q').
  Proof.
    intros b g i tp m cnt cmpt tp' m' tr H j; split.
    - intros [cntj [ q running]].
      destruct (NatTID.eq_tid_dec i j).
      + subst j. generalize running; clear running.
        inversion H; subst;
          match goal with
          | [ H: getThreadC ?cnt = Kblocked ?c |- _ ] =>
            replace cnt with cntj in H by apply cnt_irr;
              intros HH; rewrite HH in H; inversion H
          end.
      + (*this should be easy to automate or shorten*)
        inversion H; subst.
        * exists (cnt_age' (cntUpdateL _ _ (cntUpdate (Kresume c Vundef) phi' _ cntj))), q.
          erewrite <- age_getThreadCode.
          rewrite gLockSetCode.
          rewrite gsoThreadCode; assumption.
        * exists (cnt_age' (cntUpdateL _ _ (cntUpdate (Kresume c Vundef) phi' _ cntj))), q.
          erewrite <- age_getThreadCode.
          rewrite gLockSetCode.
          rewrite gsoThreadCode; assumption.
        * exists (cnt_age' (cntAdd _ _ _ (cntUpdate (Kresume c Vundef) phi' _ cntj))), q.
          erewrite <- age_getThreadCode.
          erewrite gsoAddCode . (*i? *)
          rewrite gsoThreadCode; assumption.
          eapply cntUpdate. eauto.
        * exists (cnt_age' (cntUpdateL _ _ (cntUpdate (Kresume c Vundef) phi' _ cntj))), q.
          erewrite <- age_getThreadCode.
          rewrite gLockSetCode.
          rewrite gsoThreadCode; assumption.
        * exists (cnt_age' (cntRemoveL _ (cntUpdate (Kresume c Vundef) phi' _ cntj))), q.
          erewrite <- age_getThreadCode.
          rewrite gRemLockSetCode.
          rewrite gsoThreadCode; assumption.
        * exists cntj, q; assumption.
    - intros [cntj [ q running]].
      destruct (NatTID.eq_tid_dec i j).
      + subst j. generalize running; clear running.
        inversion H; subst;
        try erewrite <- age_getThreadCode;
          try rewrite gLockSetCode;
          try rewrite gRemLockSetCode;
          try rewrite gssThreadCode;
          try solve[intros HH; inversion HH].
        { (*addthread*)
          assert (cntj':=cntj).
          eapply cnt_age in cntj'.
          eapply cntAdd' in cntj'. destruct cntj' as [ [HH HHH] | HH].
          * erewrite gsoAddCode; eauto.
            subst; rewrite gssThreadCode; intros AA; inversion AA.
          * erewrite gssAddCode . intros AA; inversion AA.
            assumption. }
          { (*AQCUIRE*)
            replace cntj with cnt by apply cnt_irr;
            rewrite Hthread; intros HH; inversion HH. }
      + generalize running; clear running.
        inversion H; subst;
        try erewrite <- age_getThreadCode;
          try rewrite gLockSetCode;
          try rewrite gRemLockSetCode;
          try (rewrite gsoThreadCode; [|auto]);
        try (intros HH;
        match goal with
        | [ H: getThreadC ?cnt = Krun ?c |- _ ] =>
          exists cntj, c; exact H
        end).
      (*Add thread case*) 
        assert (cntj':=cntj).
        eapply cnt_age in cntj'.
        eapply cntAdd' in cntj'; destruct cntj' as [ [HH HHH] | HH].
        * erewrite gsoAddCode; eauto.
          destruct (NatTID.eq_tid_dec i j);
            [subst; rewrite gssThreadCode; intros AA; inversion AA|].
          rewrite gsoThreadCode; auto.
          exists HH, q; assumption.
        * erewrite gssAddCode . intros AA; inversion AA.
          assumption.


          
          Grab Existential Variables.
          eauto. eauto. eauto. eauto. eauto. eauto.
          eauto. eauto. eauto. eauto. eauto. eauto.
          eauto. eauto. eauto. apply cntAdd. eauto.
          eauto. eauto. 
  Qed.

  
  Lemma syncstep_not_running:
    forall b g i tp m cnt cmpt tp' m' tr, 
      @syncStep b g i tp m cnt cmpt tp' m' tr ->
      forall cntj q, ~ @getThreadC i tp cntj = Krun q.
  Proof.
    intros.
    inversion H;
      match goal with
      | [ H: getThreadC ?cnt = _ |- _ ] =>
        erewrite (cnt_irr _ cnt);
          rewrite H; intros AA; inversion AA
      end.
  Qed.
  
  Inductive threadHalted': forall {tid0 ms},
      containsThread ms tid0 -> Prop:=
  | thread_halted':
      forall tp c tid0
        (cnt: containsThread tp tid0),
      forall
        (Hthread: getThreadC cnt = Krun c)
        (Hcant: halted the_sem c),
        threadHalted' cnt. 


  Definition threadHalted: forall {tid0 ms},
      containsThread ms tid0 -> Prop:= @threadHalted'.

    
  Lemma threadHalt_update:
    forall i j, i <> j ->
      forall tp cnt cnti c' cnt',
        (@threadHalted j tp cnt) <->
        (@threadHalted j (@updThreadC i tp cnti c') cnt') .
  Proof.
    intros; split; intros HH; inversion HH; subst;
    econstructor; eauto;
    [ erewrite <- (gsoThreadCC H) |  erewrite (gsoThreadCC H)]; exact Hthread.
  Qed.
  
  Lemma syncstep_equal_halted:
    forall b g i tp m cnti cmpt tp' m' tr, 
      @syncStep b g i tp m cnti cmpt tp' m' tr ->
      forall j cnt cnt',
        (@threadHalted j tp cnt) <->
        (@threadHalted j tp' cnt').
  Proof.
    intros; split; intros HH; inversion HH; subst;
    econstructor; subst; eauto.
    - destruct (NatTID.eq_tid_dec i j).
      + subst j.
        inversion H;
          match goal with
          | [ H: getThreadC ?cnt = Krun ?c,
                 H': getThreadC ?cnt' = Kblocked ?c' |- _ ] =>
            replace cnt with cnt' in H by apply cnt_irr;
              rewrite H' in H; inversion H
          end.
      + inversion H; subst;
        try erewrite <- age_getThreadCode;
          try rewrite gLockSetCode;
          try rewrite gRemLockSetCode;
          try erewrite gsoAddCode; eauto;
          try rewrite gsoThreadCode; try eassumption.
        { (*AQCUIRE*)
            replace cnt' with cnt0 by apply cnt_irr;
          exact Hthread. }
    - destruct (NatTID.eq_tid_dec i j).
      + subst j.
        inversion H; subst;
        match goal with
          | [ H: getThreadC ?cnt = Krun ?c,
                 H': getThreadC ?cnt' = Kblocked ?c' |- _ ] =>
            try erewrite <- age_getThreadCode in H;
              try rewrite gLockSetCode in H;
              try rewrite gRemLockSetCode in H;
              try erewrite gsoAddCode in H; eauto;
              try rewrite gssThreadCode in H;
              try solve[inversion H]
        end.
        { (*AQCUIRE*)
            replace cnt with cnt0 by apply cnt_irr;
          exact Hthread. }
      +
        inversion H; subst;
        match goal with
          | [ H: getThreadC ?cnt = Krun ?c,
                 H': getThreadC ?cnt' = Kblocked ?c' |- _ ] =>
            try erewrite <- age_getThreadCode in H;
              try rewrite gLockSetCode in H;
              try rewrite gRemLockSetCode in H;
              try erewrite gsoAddCode in H; eauto;
              try rewrite gsoThreadCode in H;
              try solve[inversion H]; eauto
        end.
        { (*AQCUIRE*)
            replace cnt with cnt0 by apply cnt_irr;
          exact Hthread. }
        

          
          Grab Existential Variables.
          eauto. eauto. eauto. eauto. eauto. eauto.
          eauto. eauto. eauto. eauto. eauto. eauto.
          eauto. eauto. eauto. eapply cntAdd. eauto.
          eauto. eauto.
  Qed.
          
  Lemma threadStep_not_unhalts:
    forall g i tp m cnt cmpt tp' m' tr, 
      @threadStep g i tp m cnt cmpt tp' m' tr ->
      forall j cnt cnt',
        (@threadHalted j tp cnt) ->
        (@threadHalted j tp' cnt') .
  Proof.
    intros; inversion H; inversion H0; subst.
    destruct (NatTID.eq_tid_dec i j).
    - subst j.
      eapply corestep_not_halted in Hcorestep.
      unfold halted, j_halted in Hcorestep; simpl in Hcorestep.
      unfold j_halted in Hcorestep.
      replace cnt1 with cnt in Hthread0 by apply cnt_irr.
      rewrite Hthread0 in Hthread; inversion Hthread;
      subst c0.
      rewrite Hcorestep in Hcant; inversion Hcant.
    - econstructor; eauto.
      Set Printing Implicit.
      rewrite gsoThreadCode; auto;
      erewrite <- age_getThreadCode; eauto.
  Qed.
    
    (* The initial machine has to be redefined.
       Right now its build by default with empty maps,
       but it should be built with the correct juice,
       corresponding to global variables, arguments
       and function specs. *)

    Lemma onePos: (0<1)%coq_nat. auto. Qed.
    Definition initial_machine rmap c:=
      mk
        (mkPos onePos)
        (fun _ => (Krun c))
        (fun _ => rmap)
        (AMap.empty (option res)).
    
    Definition init_mach rmap (genv:G)(v:val)(args:list val) : option thread_pool:=
      match initial_core the_sem genv v args with
      | Some c =>
        match rmap with
        | Some rmap => Some (initial_machine rmap c)
        | None => None
        end
      | None => None
      end.

    
    Module JuicyMachineLemmas.


      Lemma compat_lockLT': forall js m,
        mem_compatible js m ->
        forall l r,
          ThreadPool.lockRes js l = Some (Some r) ->
          forall b ofs,
            Mem.perm_order'' ((getMaxPerm m) !! b ofs) (perm_of_res' (r @ (b, ofs))).
      Proof.
        intros. destruct H as [allj H].
        inversion H.
        cut (Mem.perm_order'' (perm_of_res' (allj @ (b,ofs))) (perm_of_res' (r @ (b, ofs)))).
      {intros AA. eapply po_trans; eauto.
       inversion all_cohere0.
       rewrite getMaxPerm_correct.
       specialize (max_coh0 (b,ofs)).
       eapply max_coh0. }
      { apply po_join_sub'.
        apply resource_at_join_sub. eapply compatible_lockRes_sub; eauto. }
      Qed.
      

      Lemma compat_lockLT: forall js m,
             mem_compatible js m ->
             forall l r,
             ThreadPool.lockRes js l = Some (Some r) ->
             forall b ofs,
               Mem.perm_order'' ((getMaxPerm m) !! b ofs) (perm_of_res (r @ (b, ofs))).
    Proof.
      intros. destruct H as [allj H].
      inversion H.
      cut (Mem.perm_order'' (perm_of_res (allj @ (b,ofs))) (perm_of_res (r @ (b, ofs)))).
      {intros AA. eapply po_trans; eauto.
       inversion all_cohere0.
       rewrite getMaxPerm_correct.
       eapply max_acc_coh_acc_coh in max_coh0.
       specialize (max_coh0 (b,ofs)).
       apply max_coh0. }
      { apply po_join_sub.
        apply resource_at_join_sub. eapply compatible_lockRes_sub; eauto. }
    Qed.
    
    Lemma access_cohere_sub': forall phi1 phi2 m,
        access_cohere' m phi1 ->
        join_sub phi2 phi1 ->
        access_cohere' m phi2.
    Proof.
      unfold access_cohere'; intros.
      eapply po_trans.
        - apply H.
        - apply po_join_sub.
          apply resource_at_join_sub; assumption.
    Qed.
      
      
      
      Lemma mem_cohere'_juicy_mem jm : mem_cohere' (m_dry jm) (m_phi jm).
      Proof.
        destruct jm as [m phi C A M L]; simpl.
        constructor; auto.
      Qed.
      
      
      
      Lemma compatible_threadRes_join:
        forall js m,
          mem_compatible js m ->
          forall i (cnti: containsThread js i) j (cntj: containsThread js j),
            i <> j ->
            sepalg.joins (getThreadR cnti) (getThreadR cntj).
      Proof.
        intros.
        unfold getThreadR. 
       destruct H. destruct H as [JJ _ _ _ _].
       inv JJ. clear H1 H2. unfold join_threads in H.
       unfold getThreadsR in H.
       assert (H1 :=mem_ord_enum (n:= n (num_threads js))).
       generalize (H1 (Ordinal (n:=n (num_threads js)) (m:=j) cntj)); intro.
       specialize (H1 (Ordinal (n:=n (num_threads js)) (m:=i) cnti)).
    assert ((Ordinal (n:=n (num_threads js)) (m:=i) cnti) <> 
              (Ordinal (n:=n (num_threads js)) (m:=j) cntj)).
    contradict H0. inv H0. auto.

    unfold join_list in H.
    replace (enums_equality.enum (num_threads js)) with (ord_enum (num_threads js)) in H by apply ord_enum_enum.
    forget (Ordinal (n:=n (num_threads js)) (m:=j) cntj) as j'.
    forget (Ordinal (n:=n (num_threads js)) (m:=i) cnti) as i'.
    forget (ord_enum (num_threads js)) as el.
    clear - H2 H1 H3 H.
    revert r0 H1 H2 H; induction el; simpl; intros. inv H1.
    
    destruct H as [r' [? ?]].
    unfold in_mem, pred_of_mem in H1, H2. simpl in H1, H2.
    match type of H1 with is_true (?A || ?B) =>
      assert (H1' := @orP A B); inv H1';
      [ | destruct (A || B); inv H1; discriminate]
    end. clear H4.
    match type of H2 with is_true (?A || ?B) =>
      assert (H2' := @orP A B); inv H2';
      [ | destruct (A || B); inv H2; discriminate]
    end. clear H4 H2.
    destruct H5.
    pose proof (@eqP _ i' a); destruct (i'==a); inv H2. clear H1. inv H4.
    pose proof (@eqP _ j' a); destruct (j'==a); inv H1. contradiction H3; auto.
    destruct H6. inv H1.
    clear IHel. change (is_true (j' \in el)) in H1.
    clear - H1 H0 H.
    assert (joins (perm_maps js a) r'). eexists; eauto. clear H; rename H2 into H.
    revert r' H0 H1 H; induction el; simpl; intros. inv H1.
    destruct H0 as [? [? ?]].
    unfold in_mem, pred_of_mem in H1. simpl in H1.
    match type of H1 with is_true (?A || ?B) =>
      assert (H1' := @orP A B); inv H1';
      [ | destruct (A || B); inv H1; discriminate]
    end. clear H3 H1. destruct H4.
    pose proof (@eqP _ j' a0); destruct (j'==a0); inv H1.
    inv H3. 
    eapply join_sub_joins'; try eassumption.
    apply join_sub_refl. 
    exists x.  eassumption.
    apply (IHel _ H2 H1).
    eapply join_sub_joins'; try eassumption. 
    apply join_sub_refl. eexists;  eauto.
    clear H1. specialize (IHel r' H2).
    destruct H6.
    pose proof (@eqP _ j' a); destruct (j'==a); inv H1.  inv H4.
    clear IHel.
    assert (joins r' (perm_maps js a)). eexists; eauto. clear H; rename H1 into H.
    clear H3.
    eapply join_sub_joins'; try eassumption; try apply join_sub_refl. 
    clear - H2 H0.
    revert r' H2 H0; induction el; simpl; intros. inv H2.
    destruct H0 as [? [? ?]].
    rename H2 into H1.
    match type of H1 with is_true (?A || ?B) =>
      assert (H1' := @orP A B); inv H1';
      [ | destruct (A || B); inv H1; discriminate]
    end. clear H2 H1. destruct H3.
    pose proof (@eqP _ i' a); destruct (i'==a); inv H1.
    inv H2. eexists; eauto.
    apply IHel in H0; auto.
    apply join_sub_trans with x; auto. eexists; eauto.
    apply IHel in H0; auto.

      Qed. 

      Lemma compatible_threadRes_lockRes_join:
        forall js m,
          mem_compatible js m ->
          forall i (cnti: containsThread js i) l phi,
            ThreadPool.lockRes js l = Some (Some phi) ->
            sepalg.joins (getThreadR cnti) phi.
      Proof.
       intros.
        unfold getThreadR. 
       destruct H. destruct H as [JJ _ _ _ _].
       inv JJ. unfold join_locks, join_threads in H1.
       unfold lockRes in H0.
       apply AMap.find_2 in H0. unfold lockGuts in H0.
       apply AMap.elements_1 in H0. unfold lock_info in H1.

       unfold join_threads, join_list, getThreadsR in H.
       replace (enums_equality.enum (num_threads js)) with (ord_enum (num_threads js)) in H by apply ord_enum_enum.
       forget  (AMap.elements (elt:=option rmap) (lset js)) as el.
       match goal with |- joins ?A ?B => assert (H3: joins (Some A) (Some B)) end.
      Focus 2. destruct H3; inv H3; eexists; eauto.
       eapply join_sub_joins'. 2: instantiate (1:=r1). instantiate (1:= Some r0).
       assert (join_sub (perm_maps js (Ordinal (n:=n (num_threads js)) (m:=i) cnti)) r0).
       Focus 2. destruct H3 as [xx H3];  exists (Some xx); constructor; auto.
       3: eauto.
       { clear - H.
           unfold join_threads in H. unfold getThreadsR in H.
           pose proof (mem_ord_enum (n:= n (num_threads js))).
           specialize (H0 (Ordinal (n:=n (num_threads js)) (m:=i) cnti)) .
           forget (ord_enum (n (num_threads js))) as el.
           forget ((Ordinal (n:=n (num_threads js)) (m:=i) cnti)) as j.
           rename H into H'; rename H0 into H; rename H' into H0.
           revert H H0; clear; revert r0; induction el; intros. inv H.
            unfold in_mem in H. unfold pred_of_mem in H. simpl in H.
           pose proof @orP.
           specialize (H1 (j == a)(pred_of_eq_seq (T:=ordinal_eqType (n (num_threads js))) el j)).
        destruct ((j == a)
       || pred_of_eq_seq (T:=ordinal_eqType (n (num_threads js))) el j); inv H.
    inv H1. destruct H.
    pose proof (@eqP _ j a). destruct (j==a); inv H; inv H1.
    simpl in H0.
 destruct H0 as [? [? ?]].
    exists x; auto.
    unfold pred_of_eq_seq in H.
    destruct H0 as [? [? ?]].
    apply (IHel x) in H. apply join_sub_trans with x; auto. eexists; eauto.
    auto.
         }   
       { clear - H0 H1.
           revert r1 H1 H0; induction el; intros. inv H0.
           destruct H1 as [? [? ?]].
           inv H0. inv H3. destruct a; simpl in *; subst. eexists; eauto.
           apply IHel in H1; auto. apply join_sub_trans with x; auto.
           eexists; eauto.
         }   
    Qed.
               
      Lemma compatible_lockRes_cohere: forall js m l phi,
          ThreadPool.lockRes js l = Some (Some phi) ->
          mem_compatible js m ->
          mem_cohere' m phi .
      Proof.         
        intros.
        inversion H0 as [all_juice M]; inversion M.
        apply (compatible_lockRes_sub _ H ) in juice_join0.
        apply (mem_cohere_sub all_cohere0) in juice_join0.
        assumption.
      Qed.

      Lemma compatible_threadRes_cohere:
        forall js m i (cnt:containsThread js i),
          mem_compatible js m ->
          mem_cohere' m (ThreadPool.getThreadR cnt) .
      Proof.
        intros.
        inversion H as [all_juice M]; inversion M.
        eapply mem_cohere_sub.
        - eassumption.
        - apply compatible_threadRes_sub. assumption.
      Qed.
      
      (** *Lemmas about aging*)
      Lemma cnt_age {js i n} :
          containsThread js i <->
          containsThread (age_tp_to n js) i.
      Proof.
        destruct js; split; auto.
      Qed.
      
      Lemma gtc_age : forall js i n,
          forall (cnt: containsThread js i)
            (cnt': containsThread (age_tp_to n js) i),
            getThreadC cnt= getThreadC cnt'.
      Proof.
        intros []. intros; simpl.
        repeat f_equal; apply proof_irr.
      Qed.
      
      Lemma getThreadR_age: forall js i age,
          forall (cnt: containsThread js i)
            (cnt': containsThread (age_tp_to age js) i),
            age_to age (getThreadR cnt) = getThreadR cnt'.
      Proof.
        intros. unfold getThreadR; destruct js; simpl.
        unfold containsThread in cnt, cnt'.
        simpl in cnt, cnt'.
        unfold "oo"; 
          do 3 f_equal. apply proof_irrelevance.
      Qed.
      
      Lemma LockRes_age: forall js age a,
          isSome (lockRes (age_tp_to age js) a) = isSome(lockRes js a).
      Proof.
        destruct js.
        intros; unfold lockRes; simpl.
        destruct (AMap.find (elt:=lock_info) a
                            (AMap.map (option_map (age_to age)) lset0)) eqn:AA;
          destruct (AMap.find (elt:=lock_info) a lset0) eqn:BB;
          try (reflexivity).
        - apply AMap_find_map_inv in AA. destruct AA as [x [BB' rest]].
          rewrite BB' in BB; inversion BB.
        - apply AMap_find_map with (f:=(option_map (age_to age))) in BB.
          rewrite BB in AA; inversion AA.
      Qed.
      
      Lemma LockRes_age_content1: forall js age a,
          lockRes (age_tp_to age js) a = Some None ->
          lockRes js a = Some None.
        intros js age a. unfold lockRes; destruct js.
        simpl.
        intros AA.
            apply AMap_find_map_inv in AA. destruct AA as [x [map rest]].
            rewrite map. f_equal.
            destruct x; inversion rest; try reflexivity.
      Qed.

      Lemma LockRes_age_content2: forall js age a rm,
          lockRes (age_tp_to age js) a = Some (Some rm) ->
          exists r, lockRes js a = Some (Some r) /\ rm = age_to age r.
      Proof.
        intros js age a rm. unfold lockRes; destruct js.
        simpl.
        intros AA.
        apply AMap_find_map_inv in AA. destruct AA as [x [map rest]].
        destruct x; inversion rest.
        exists r; rewrite map; auto.
      Qed.

      Lemma access_cohere'_age m : hereditary age (access_cohere' m).
      Proof.
        intros x y E B.
        intros addr.
        destruct (age1_levelS _ _ E) as [n L].
        eapply (age_age_to n) in E; auto.
        rewrite <-E.
        rewrite perm_of_age.
        apply B.
      Qed.
      
      Lemma access_cohere'_unage m : hereditary unage (access_cohere' m).
      Proof.
        intros x y E B.
        intros addr.
        destruct (age1_levelS _ _ E) as [n L].
        eapply (age_age_to n) in E; auto.
        rewrite <-E in B.
        spec B addr.
        rewrite perm_of_age in B.
        apply B.
      Qed.
      
      Lemma mem_cohere'_age m : hereditary age (mem_cohere' m).
      Proof.
        intros x y E.
        intros [A B C]; constructor.
        - eapply contents_cohere_age; eauto.
       (* - eapply access_cohere'_age; eauto.*)
        - eapply max_access_cohere_age; eauto.
        - eapply alloc_cohere_age; eauto.
      Qed.
      
      Lemma mem_cohere'_unage m : hereditary unage (mem_cohere' m).
      Proof.
        intros x y E.
        intros [A B C]; constructor.
        - eapply contents_cohere_unage; eauto.
        - eapply max_access_cohere_unage; eauto.
        - eapply alloc_cohere_unage; eauto.
      Qed.
      
      Lemma mem_cohere_age_to n m phi :
        mem_cohere' m phi ->
        mem_cohere' m (age_to n phi).
      Proof.
        apply age_to_ind, mem_cohere'_age.
      Qed.
      
      Lemma mem_cohere_age_to_opp n m phi :
        mem_cohere' m (age_to n phi) ->
        mem_cohere' m phi.
      Proof.
        apply age_by_ind_opp.
        intros x y A. apply mem_cohere'_unage, A.
      Qed.
      
    End JuicyMachineLemmas.
    
  End JuicyMachineShell.
  
  (*
This is how you would instantiate a module (though it might be out of date

Declare Module SEM:Semantics.
  Module JuicyMachine:= JuicyMachineShell SEM.
  Module myCoarseSemantics :=
    CoarseMachine mySchedule JuicyMachine.
  Definition coarse_semantics:=
    myCoarseSemantics.MachineSemantics.*)
  
End Concur.

(*Erase everything below*)
