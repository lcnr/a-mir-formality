#lang racket
(require redex/reduction-semantics
         "../grammar.rkt"
         "../substitution.rkt"
         "../env.rkt"
         )

(provide test-equate-predicates
         test-relate-parameters
         unify        ; just for testing by unify-test.rkt
         occurs-check ; just for testing by unify-test.rkt
         )

(define-metafunction formality-logic
  test-equate-predicates : Env Predicate Predicate -> (Env Goals) or Error

  [(test-equate-predicates Env Predicate_1 Predicate_2)
   (Env_out ())
   (where Env_out (unify Env ((Predicate_1 Predicate_2))))]

  [(test-equate-predicates Env Predicate_1 Predicate_2)
   Error
   (where Error (unify Env ((Predicate_1 Predicate_2))))]
  )

(define-metafunction formality-logic
  test-relate-parameters : Env Relation -> (Env Goals) or Error

  [(test-relate-parameters Env (Parameter_1 == Parameter_2))
   (Env_out ())
   (where Env_out (unify Env ((Parameter_1 Parameter_2))))]

  [(test-relate-parameters Env (Parameter_1 == Parameter_2))
   Error
   (where Error (unify Env ((Parameter_1 Parameter_2))))]
  )

(define-metafunction formality-logic
  ;; Given an environment `Env` and a set `TermPairs` of `(Term Term)` pairs,
  ;; computes a new environment `Env_out` whose substitution maps variables
  ;; from `VarIds` as needed to ensure that each `(Term Term)` pair is
  ;; equal. Yields `Error` if there is no such set. As a side-effect of this process,
  ;; existential variables may also be moved to smaller universes (because `?X = ?Y` requires
  ;; that `?X` and `?Y` be in the same universe).
  ;;
  ;; The algorithm is a variant of the classic unification algorithm adapted for
  ;; universes. It is described in "A Proof Procedure for the Logic of Hereditary Harrop Formulas"
  ;; publishd in 1992 by Gopalan Nadathur at Duke University.
  unify : Env TermPairs -> Env or Error

  [(unify Env TermPairs)
   (unify-pairs Env (apply-substitution-from-env Env TermPairs))]

  )

(define-metafunction formality-logic
  unify-pairs : Env TermPairs -> Env or Error
  [; base case, all done, but we have to apply the substitution to itself
   (unify-pairs Env ())
   Env_1
   (where/error Substitution_1 (substitution-fix (env-substitution Env)))
   (where/error Env_1 (apply-substitution-to-env Substitution_1 Env))
   ]

  [; unify the first pair ===> if that is an error, fail
   (unify-pairs Env (TermPair_first TermPair_rest ...))
   Error
   (where Error (unify-pair Env TermPair_first))]

  [; unify the first pair ===> if that succeeds, apply resulting substitution to the rest
   ; and recurse
   (unify-pairs Env (TermPair_first TermPair_rest ...))
   (unify-pairs Env_u TermPairs_all)

   (where (Env_u (TermPair_u ...)) (unify-pair Env TermPair_first))
   (where/error (TermPair_v ...) (apply-substitution-from-env Env_u (TermPair_rest ...)))
   (where/error TermPairs_all (TermPair_u ... TermPair_v ...))
   ]
  )

(define-metafunction formality-logic
  unify-pair : Env TermPair -> (Env TermPairs) or Error

  [; X = X ===> always ok
   (unify-pair Env (Term Term))
   (Env ())
   ]

  [; X = P ===> occurs check ok, return `[X => P]`
   (unify-pair Env (VarId Parameter))
   ((env-with-var-mapped-to Env_out VarId Parameter) ())

   (where #t (env-contains-existential-var Env VarId))
   (where Env_out (occurs-check Env VarId Parameter))
   ]

  [; X = P ===> but occurs check fails, return Error
   (unify-pair Env (VarId Parameter))
   Error

   (where #t (env-contains-existential-var Env VarId))
   (where Error (occurs-check Env VarId Parameter))
   ]

  [; P = X ===> just reverse order
   (unify-pair Env (Parameter VarId))
   (unify-pair Env (VarId Parameter))

   (where #t (env-contains-existential-var Env VarId))
   ]

  [; (L ...) = (R ...) ===> true if Li = Ri for all i and the lengths are the same
   (unify-pair Env ((Term_l ..._0)
                    (Term_r ..._0)))
   (Env ((Term_l Term_r) ...))]

  [; any other case fails to unify
   (unify-pair Env (Term_1 Term_2))
   Error
   ]

  )

(define-metafunction formality-logic
  ;; Checks whether `VarId` can be assigned the value of `Parameter`.
  ;;
  ;; Fails if:
  ;;
  ;; * `VarId` appears in `Parameter`
  ;; * `Parameter` mentions a placeholder that `VarId` cannot name because of its universe
  ;;
  ;; Returns a fresh environment which contains adjust universes for each
  ;; variable `V` that occur in `Parameter`. The universe of `V` cannot
  ;; be greater than the universe of `VarId` (since whatever value `V` ultimately
  ;; takes on will become part of `VarId`'s value).
  occurs-check : Env VarId Parameter -> Env or Error

  [(occurs-check Env VarId Parameter)
   Env_1

   ; can't have X = Vec<X> or whatever, that would be infinite in size
   (where #f (appears-free VarId Parameter))

   ; find the universe of `VarId`
   (where/error Universe_VarId (universe-of-var-in-env Env VarId))

   ; can't have `X = T<>` if `X` cannot see the universe of `T`
   (where/error (VarId_placeholder ...) (placeholder-variables Env Parameter))
   (where #t (all? (universe-includes Universe_VarId (universe-of-var-in-env Env VarId_placeholder)) ...))

   ; for each `X = ... Y ...`, adjust universe of Y so that it can see all values of X
   (where/error VarIds_free (free-variables Env Parameter))
   (where/error Env_1 (env-with-vars-limited-to-universe Env VarIds_free Universe_VarId))
   ]

  [(occurs-check Env VarId Parameter)
   Error
   ]

  )
