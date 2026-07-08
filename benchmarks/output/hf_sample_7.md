# hf_sample_7

In [7] we described a layered software architecture for a

sparse eigenvalue solver library with applications in quantum

physics. The kernel interface we proposed (see also the PHIST

software, [8]) allows the algorithms and applications layers

### to work with multiple backends, among which are large

open source libraries optimized for portability (e.g. Trilinos)

and hand-optimized hardware-specific ones like GHOST [9].

PHIST provides both unit tests for the backends and perfor-

mance models for all operations used in its algorithms. That

way, a new development on the hardware side can be met

by either the extension of an existing implementation or a

completely new one, and the new component can be readily

tested in terms of correctness and performance. The algorithms

and applications layers only have to be modified or extended

if new needs arise on their respective level. The significantly

larger HPC software project Trilinos [10] takes the approach

of offering a large number of interoperable ‘packages’ which

may have different life cycles. While this also results in a

achieved by using more processes to solve the same prob-

lem (strong scalability), or the parallel efficiency when in-

creasing the problem size with the number of processes

(weak scalability). Such results are not necessarily helpful for

comparing the performance on different machines. A better

way is to identify the bottleneck in the computation and

to report resource utilization with respect to that bottleneck:

In the vast majority of HPC codes, the bottleneck is either

floating point arithmetic (‘compute bound’ applications), or

data movement (‘memory bound’ or ‘communication bound’).

This allows estimating the attainable performance by the

roofline performance model [12]. With some measurements of

cache/memory/network bandwidths and counting of operations

and data volumes, one can calculate the achieved performance

relative to the (modeled) attainable performance. This relative

roofline performance provides a criterion that is independent

of the underlying hardware.

Unfortunately, tools cannot easily compute this automatimanageable overall software, it may incur smaller or larger

cally as it requires high-level insight into the algorithms. For interface adaptations for users from time to time. The package

instance, an unfavorable memory access pattern may or may concept is taken to the next level by the xSDK project

not be avoidable by code or algorithm restructuring. A perfor(https://xsdk.info), which aims at gradually improving the

mance model can be formulated to predict the optimal runtime software quality and interoperability of a whole landscape of

of the bad access pattern (labelling a good implementation as HPC libraries and applications by defining common rules and

efficient). Alternatively, a model can predict the runtime of the recommendations.

inefficient). We therefore decided to build the roofline model Above, we mentioned the potentially large amount of (gen-

actual amount of data traffic needed to perform the operation in an ideal setting (highlighting this part of the algorithm as IV. TESTING

manually into the timing functionality for all basic operations erated) code that needs to be covered by unit testing. In

of the PHIST software, giving the user a choice of these addition, HPC software often employs multiple parallelization

two variants (realistic vs. idealized) [7], [8]. When running levels at once (e.g., OpenMP for CPU multi-threading, MPI

the same application on two different machines, one can then for communication between nodes and CUDA for GPUs). This

compare the overall roofline performance, or the performance can lead to functionality that is available but not well-tested.

achieved by individual operations, even for different hardware We propose to anticipate typical bugs in HPC codes and to

design unit tests specifically to trigger them (similar to whitebox testing but with multiple different possible implementa-

tions in mind). In PHIST, for instance, all basic linear algebra tests are executed for aligned and unaligned memory cases to

and/or backends.

- VI. SUMMARY
In this overview of software engineering challenges specific locate invalid use of SIMD operations. Other typical ‘parallel

to HPC, we argued that HPC applications are particularly bugs’ include race conditions and deadlocks. Beyond such

vulnerable to poor software engineering because their develHPC-specific tests, one needs to explore the space of available

opment and use typically outlasts several generations of HPC combinations of hardware features with a finite test-matrix by

hardware. Basic functionality needs to be implemented ‘close selecting a hopefully representative subset.

to the hardware’, so that supporting (combinations of) multiple A practical problem is that test frameworks typically lack

architectures and programming models leads to additional support for MPI applications, as well as for other paralleliza-

complexity and to a large amount of (generated) code which tion techniques such as OpenMP or CUDA. At least MPI

has to be tested. And finally, as the hardware develops rapidly, support is crucial to run the tests on current supercomputers.

it is difficult to compare performance results on different An exception is pFUnit [11] for Fortran which supports MPI

and OpenMP. For C++ we provide an extended version of

machines and hardware architectures.

We illustrated some aspects of software design, unit testing GoogleTest with MPI support at https://github.com/DLR-SC/

and of the portability of performance results with a practical googletest_mpi. It features correct I/O and handling of test

solution from our own field of research, (sparse) linear algebra. results in parallel, as well as collective assertions.

The points we would like to highlight are separation of V. PERFORMANCE PORTABILITY

In many papers, performance results are reported in terms

of ‘scalability’ of a parallel program: either the speed-up

concerns when designing the software, anticipating HPC-

specific bugs, and using performance models to validate the

efficiency of an implementation across different hardware.

---

