(*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

(** Terms *)

type arith

(** Terms, built from variables and applications of function symbols from
    various theories. Denote functions from structures to values. *)
type t = private
  (* variables *)
  | Var of {id: int; name: string [@ignore]}
  (* arithmetic *)
  | Z of Z.t
  | Q of Q.t
  | Arith of arith
  (* sequences (of flexible size) *)
  | Splat of t
  | Sized of {seq: t; siz: t}
  | Extract of {seq: t; off: t; len: t}
  | Concat of t array
  (* uninterpreted *)
  | Apply of Funsym.t * t array
[@@deriving compare, equal, sexp]

(** Arithmetic terms *)
module Arith : Arithmetic.S with type trm := t with type t = arith

module Set : sig
  include Set.S with type elt := t

  val t_of_sexp : Sexp.t -> t
  val pp : t pp
  val pp_diff : (t * t) pp
end

module Map : sig
  include Map.S with type key := t

  val t_of_sexp : (Sexp.t -> 'a) -> Sexp.t -> 'a t
end

(** Variable terms, represented as a subtype of general terms *)
module Var : sig
  type trm := t

  include
    Var_intf.S with type t = private trm with type Set.t = private Set.t

  val of_trm : trm -> t option
end

val ppx : Var.strength -> t pp
val pp : t pp
val pp_diff : (t * t) pp

include Invariant.S with type t := t

(** Classification *)

type kind = InterpApp | NonInterpAtom | InterpAtom | UninterpApp
[@@deriving compare, equal]

val classify : t -> kind

val is_noninterpreted : t -> bool
(** Test if a term is either a variable ({!Var}) or an uninterpreted
    function symbol application ({!Apply} or {!Arith} when
    [{!Arith.classify} a = Uninterpreted]). That is, is not an interpreted
    function symbol application (including constants and nullary
    applications). *)

val is_interpreted : t -> bool
val is_uninterpreted : t -> bool

val solvables : t -> t iter
(** The maximal noninterpreted terms (according to {!is_noninterpreted})
    occurring in a term. Note that for noninterpreted terms, this is the
    single term itself. *)

val solvable_trms : t -> t iter
(** The solvables of immediate subterms. That is, maximal noninterpreted
    strict subterms. *)

val transitive_solvables : t -> t iter
(** The noninterpreted transitive and not necessarily proper subterms
    occurring in a term. *)

(** Construct *)

(** Construction functions perform semantics-preserving simplifications.
    This means that [t] can not be considered as a term algebra generated by
    the constructor functions. That is, for a constructor
    [cons : t -> t -> t], [cons a b] need not have [a] as a proper subterm,
    need not have principal constructor [Cons], etc. It is guaranteed,
    however, that the constructor functions do not create new solvable
    proper subterms. That is, each subterm in [solvable_trms (cons a b)] is
    in either [transitive_solvables a] or [transitive_solvables b]. This
    property is required by the equality solver, see {!Context}. *)

(* variables *)
val var : Var.t -> t

(* arithmetic *)
val zero : t
val one : t
val integer : Z.t -> t
val rational : Q.t -> t
val neg : t -> t
val add : t -> t -> t
val sub : t -> t -> t
val mulq : Q.t -> t -> t
val mul : t -> t -> t
val div : t -> t -> t
val pow : t -> int -> t
val arith : Arith.t -> t

(* sequences (of flexible size) *)
val splat : t -> t
val sized : seq:t -> siz:t -> t
val extract : seq:t -> off:t -> len:t -> t
val concat : t array -> t

(* uninterpreted *)
val apply : Funsym.t -> t array -> t

(** Destruct *)

val get_z : t -> Z.t option
val get_q : t -> Q.t option

(** Query *)

val seq_size_exn : t -> t
val seq_size : t -> t option
val is_atomic : t -> bool
val height : t -> int

(** Traverse *)

val vars : t -> Var.t iter
(** The variables that occur in a term. *)

val fv : t -> Var.Set.t

val trms : t -> t iter
(** The immediate subterms. *)

val atoms : t -> t iter
(** The atomic reflexive-transitive subterms. *)

(** Transform *)

val map_vars : t -> f:(Var.t -> Var.t) -> t
(** Map over the {!vars}. *)

val map : t -> f:(t -> t) -> t
(** Map over the {!trms}. *)

val map_solvables : t -> f:(t -> t) -> t
(** Map over the {!solvables}. *)

val fold_map : t -> 's -> f:(t -> 's -> t * 's) -> t * 's
(** Fold while mapping over the {!trms}. *)
