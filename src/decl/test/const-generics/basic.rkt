#lang racket
(require redex/reduction-semantics
         "../../decl-to-clause.rkt"
         "../../decl-ok.rkt"
         "../../grammar.rkt"
         "../../prove.rkt"
         "../../../util.rkt")

(module+ test
  ;; Program:
  ;;
  ;; struct Foo;
  ;; trait Bar<const N: usize> {}
  ;; impl<const M: usize> Bar<M> for Foo {}
  (redex-let*
   formality-decl
   ((KindedVarId_M (term ((CtKind (scalar-ty usize)) M)))
    (TraitDecl (term (Bar (trait ((TyKind Self) ((CtKind (scalar-ty usize)) N)) () ()))))
    (AdtDecl_Foo (term (Foo (struct () () ((Foo ()))))))
    (CtKind_M (term M))
    (Ct_M (term ((scalar-ty usize) CtKind_M)))
    (TraitRef_Bar (term (Bar ((TyRigid Foo ()) Ct_M))))
    (TraitImplDecl (term (impl (KindedVarId_M) TraitRef_Bar () ())))
    (CrateDecl (term (TheCrate (crate (TraitDecl AdtDecl_Foo TraitImplDecl)))))
    (Env (term (env-for-crate-decl CrateDecl)))

    ;; `TheCrate` can prove `forall<const M: usize> Bar<M>: Foo`
    (Goal (term (ForAll (KindedVarId_M) (Implemented TraitRef_Bar))))
    )
    (traced '()
            (decl:test-can-prove Env Goal)))
  )
