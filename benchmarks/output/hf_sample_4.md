# hf_sample_4

# (R)SE challenges in HPC

Jonas Thies∗, Melven Röhrig-Zöllner†, and Achim Basermann†

∗Delft High Performance Computing Center, Delft University of Technology,

j.thies@tudelft.nl

†Institute for Software Technology, German Aerospace Center (DLR), Cologne, Germany

melven.roehrig-zoellner@dlr.de, achim.basermann@dlr.de

Second challenge: The number of possible code paths Abstract—We discuss some specific software engineering challenges in the field of high-performance computing, and argue

grows exponentially in order to provide high performance. A that the slow adoption of SE tools and techniques is at least

user’s call to a simple basic linear algebra subroutine (BLAS) in part caused by the fact that these do not address the HPC

may trigger any of dozens of implementations, differing in challenges ‘out-of-the-box’. By giving some examples of solutions

arithmetic (real, complex), precision (half/single/double/quad, for designing, testing and benchmarking HPC software, we intend

or vendor-specific variants thereof), data layout (e.g. row- or to bring software engineering and HPC closer together.

This leads to an explosion of combinations of (possibly generated) code paths. In some cases the testing responsibility It is a common observation that in the field of high-

column major matrix storage), threading mechanisms or GPU programming model, SIMD hardware (SSE/AVX/ARM/...). I. INTRODUCTION

is with hardware-specific vendor libraries (like the Intel MKL performance computing (HPC) scientists only slowly adopt

or CUBLAS), but ‘hand-optimized’ code for special purposes new software engineering techniques that are already suc-

must still be tested efficiently and comprehensively. cessful in e.g., web development or commercial applications.

Third challenge: It is difficult to reproduce performance This was described from the software engineer’s point of view

results. Due to the fast pace at which the hardware develops, in [1]. We approach the topic from the HPC engineer’s point

another user of a code or algorithm may not have a comof view.

parable machine in terms of speed, memory, parallelism, or In our opinion, improved training of HPC developers is

even architecture. Simple and general machine models allow an important step, but it needs to address specific challenges

assessing the efficiency of an implementation across platforms, inherent to HPC software. In contrast to other fields, HPC

as we will discuss in Section V. They can also ensure that the software always has the design goal of achieving high hard-

system’s hardware and software are configured appropriately ware efficiency, which in turn ensures energy efficiency [2] and

as even small changes can reduce the performance by a factor makes extreme-scale applications feasible in the first place. In

addition to training, tools for programming and testing must be adjusted to work correctly in an HPC environment. In this

of two or more.

- III. DESIGNING HPC SOFTWARE paper, we present key aspects of software design, testing and
In order to meet the challenge of the mismatched softperformance engineering for HPC software.

ware/hardware life-cycle it is crucial to achieve separation of concerns in HPC applications. The climate scientist who II. CHALLENGES IN HPC SOFTWARE DEVELOPMENT

develops a new model component, or the numerical mathematician who develops a new algorithm, cannot port the We identify three key challenges that seem to be invariant

software to the next few generations of hardware in the with respect to circumstances such as the actual application,

life-cycle of the code. Instead, they need robust interfaces hardware or programming skills of the developers.

mentations (kernels) are separated. For decades, the libraries significantly shorter than that of HPC software, while at the

through which the application, algorithms and low-level impleFirst challenge: The life-cycle of HPC hardware is

BLAS and LAPACK [3] provide a commonly used interface same time software must be tailored to the hardware in order

to linear algebra building blocks. However, the choice of the to achieve optimal performance. In the course of a decade

granularity of the building blocks as well as their interfaces are the supercomputer hardware evolves dramatically (e.g. from

architectural decisions. In particular, to obtain high efficiency, vector processors to clusters of CPUs, from single to multi-

one needs to optimize the node-level performance as well as core processors, from commodity hardware to graphics or

the communication. Both of these optimizations often affect tensor processing units). In contrast, much of the code base in

the code globally e.g., through the memory-layout and the use is at least twenty or thirty years old, and developing e.g.

distribution of data. So new advances such as communicationa new aerodynamics code for industrial use may take decades

avoiding algorithms (or better: data-transfer avoiding algoeven with a large team and modern software engineering

rithms, see [4]) cannot always be implemented just under the technology.

hood, see [5], [6] for examples.

---

