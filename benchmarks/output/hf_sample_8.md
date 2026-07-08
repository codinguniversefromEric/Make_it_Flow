# hf_sample_8

- A. Leporati et al. / Tissue P Systems with Small Cell Volume
1005

adds one to the value of register rand jumps to instruction j; the decrement instruction subtracts one to the value of register rand jumps to j1 if r >0, and jumps to j2 without changing the register if r = 0. Register machines will be simulated by place/transition Petri nets, where places may contain an (a priori)

unbounded number of tokens [3], using a construction described by Frisco [4].

# 3.

# Universality with Constant Cell Volume

We define the volume of a cell as the amount of bits of information it encodes, both in terms of the objects

it contains and its label.

Definition 3.1.

The volume of a cell of a tissue P system (with alphabet Γ and set of labels Λ) containing multiset w ∈Γ⋆ is given by log2 |Λ| + |w|× log2 |Γ|. We say that a tissue P system has limited cell volume v if none of its cells ever exceeds volume v in any computation starting from its initial configuration. Finally, we say that a family of tissue P systems Π= {Πx : x∈Σ⋆}has cell volume v(n) if all Πx with |x|= nhave limited cell volume v(n).

Notice that the volume bound v(or v(n)) in this definition does not represent a limit imposed on the volume of cells, i.e., blocking the entering of further objects in a cell, but a measured upper bound across all computations. As a consequence, there is no change in the semantics of the application of rules from

the standard definition.

We focus our analysis on tissue P systems with small cell volume, that is, sub-polynomial cell volume (with a particular interest for constant and logarithmic cell volume). We begin by proving that even the restriction to constant volume does not affect the universality of tissue P systems with cell division, if we allow multiple cells to share the same label in the initial configuration. Furthermore, all communication rules required have length 2, meaning that only two objects per rule are involved. This proof exploits the fact that register machines can be simulated by place/transition Petri nets operating in the maximally parallel way, as shown by Frisco [4] based on the zero-test proposed by Burkhard [2].

Theorem 3.2. For each register machine R there exists an exponential-time semi-uniform family of tissue P systems with constant cell volume simulating Rusing only communication rules of length 2 and division rules, assuming that multiple cells with the same label are allowed in the initial configuration.

### Proof:

---

