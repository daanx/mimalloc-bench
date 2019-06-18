
(declare-fun x () (_ BitVec 16))
(declare-fun y () (_ BitVec 16))
(declare-fun z () (_ BitVec 16))
(declare-fun GCD () (_ BitVec 16))

(assert (= (bvmul ((_ zero_extend 16) x) ((_ zero_extend 16) GCD)) (_ bv300 32)))
(assert (= (bvmul ((_ zero_extend 16) y) ((_ zero_extend 16) GCD)) (_ bv900 32)))
(assert (= (bvmul ((_ zero_extend 16) z) ((_ zero_extend 16) GCD)) (_ bv333 32)))
(maximize GCD)

(check-sat)
(get-model)
