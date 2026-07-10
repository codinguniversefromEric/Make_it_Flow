# hf_sample_0

# 1226

Rajpreet Chahal et al.

J Child Psychol Psychiatr 2020; 61(11): 1224–33

yearly, within-individual changes in depressive severity during substudy of precursors of depression, where half the partici-

the 10-year period; the Level 2 model estimated the sample’s pants displayed elevated depressive symptoms and half did not

average growth trajectory. Linear and quadratic models were fit (Appendix S1). Written assent/consent was obtained for all

to the data. The intercept of time was coded as beginning at age participants and their parents, and monetary compensation

10, and each time-point was coded as integers from 0 to 9 (age was provided. Study procedures were approved by the Human

10–19). The linear and quadratic models’ fit criteria were Protections Committee and Institutional Review Board of the

compared for model selection. Per-person estimates of interstudy sites.

# Measures

cept and slope, derived from multilevel modeling, were extracted for connectivity analyses.

Structural connectivity analysis. Network-based Depressive symptom severity. Self-reported depres-

statistic (NBS) analyses (Zalesky, Fornito, & Bullmore, 2010), sive symptoms were collected using the Child, Adolescent, and

a robust method to control family-wise error rate during mass Adult Symptom Inventories– 4th Edition beginning when the

univariate testing, were used to test associations between girls were age 10 and continuing annually through age 19

interregional connectivity matrices and depression course (Gadow, 2015). All 9 symptoms of DSM-IV major depressive

variables. NBS analyses identified clusters (i.e., subnetworks) disorder were assessed with these inventories, which demon-

of brain regions where the strength of edges between them was strate high validity, reliability, and clinical utility (Salcedo

associated with depression course variables. A primary comet al., 2017). Symptom severity, a dimensional measure,

ponent-forming threshold (p < .001, uncorrected) was applied provides a significant advantage in identifying youth with

to form suprathreshold edges of these subnetworks. Size of mood disorders (Salcedo et al., 2017). Items were rated 0

remaining connected components was computed and its (never), 1 (sometimes), 2 (often), or 3 (very often) and summed;

statistical significance evaluated against an empirical null yes or no items (e.g., change in appetite) were recoded

distribution of maximal component size obtained under the (yes= 2.5, no = 0.5) following the scoring criteria. Reliability

null hypothesis of random group membership (1,000 permuat ages 10–19 ranged from a = .72–.86. Research shows that

tations). Subnetworks significant at a corrected level of p < .01 youth self-reported depression, compared with parent-report

were reported (see Appendix S4 for additional details on NBS or multi-informant report, best predicts concurrent depressive

and Appendix S5 for a list of included brain regions and episodes as assessed by a clinical diagnostic interview (Cohen,

abbreviations). Resulting p-values were adjusted for multiple So, Young, Hankin, & Lee, 2019). See Appendix S2 for

comparisons using Bonferroni correction (a = .05). Depressive information about estimated major depressive disorder

severity intercept, linear slope, and their interaction were occurrence.

included as predictor variables in one regression model. Given the following variables have been associated with depression White matter diffusion-weighted imaging. At

and brain connectivity, we included covariates of head motion during the scan (mean frame-wise displacement) (Yendiki, approximately age 19, girls underwent diffusion-weighted

Koldewyn, Kakunoori, Kanwisher, & Fischl, 2014), age 10 imaging on a 3.0T Siemens Tim Trio scanner (Siemens Medical

verbal IQ (Li et al., 2009), race (Nyquist et al., 2014), and Solutions, Erlangen, Germany). A pulsed-gradient spin-echo

socioeconomic status (SES; number of years receiving public sequence was applied in 68 directions, with posterior-to-

assistance from ages 10 to 19) (Ursache & Noble, 2016). Given anterior phase encoding. Scan parameters included repetition time (TR)= 8,500 ms, echo time (TE)= 91 ms, and field of view

that anxiety may co-occur with depression (e.g., Yaroslavsky (FOV)= 256 mm2. Sixty-four contiguous slices were acquired

et al., 2013), the main effect of anxiety symptoms at age 10 was with an isotropic voxel size of 2.0 mm3 and a b-value of

tested in the presence of depressive symptom intercept; 1,000 s/mm2 (see Appendix S3 for preprocessing steps). A

however, given the focus of this study on depression and that different neural systems may be implicated in depression, high-resolution T1-weighted anatomical image was acquired

anxiety, and comorbid depression–anxiety, main analyses with the following parameters: TR= 2,300 ms; TE= 2.98 ms; flip angle= 9°; 160 slices; FOV= 256 mm; acquisition voxel

size= 1.0 9 1.0 9 1.2 mm.

focused on depressive symptom course.

Tractography and graph construction. Anatomical

images were coregistered to diffusion native space and parcel-

### Results

### Table 1 presents means, standard deviations, and lated into 94 contiguous regions of interest based on the

### correlations among depression measures, race, verautomatic anatomical labeling atlas 2 (AAL2; Rolls, Joliot, &

### bal IQ, head motion, and SES. The distributions of Tzourio-Mazoyer, 2015), currently the most widely used atlas

depressive severity scores at all time-points are in connectivity studies (Hallquist & Hillary, 2018). Whole-brain probabilistic tractography was run using FSL’s BEDPOSTX

and PROBTRACKX (Behrens, Berg, Jbabdi, Rushworth, & Woolrich, 2007); 5,000 streamlines/voxel were sampled for

# presented in Figure S1.

Depressive symptom severity course each of the 94 regions. The maximum connective values between pairs of regions were taken to compute per-person

The quadratic model fit the longitudinal data slightly connectivity matrices representing the probabilities of connections among regions (i.e., 94 9 94 undirected and weighted

better than the linear model; however, there were no matrices; additional detail in Appendix S3).

differences in model fit between quadratic models with or without freely estimated quadratic terms (Table S1). Based on these results, we selected the Data analysis

quadratic model without the freely estimated quadDepressive symptom severity course. Unconditional

ratic term to parsimoniously conduct structural multilevel growth modeling (Hedeker & Gibbons, 2012) in R

connectivity analyses. At time 0 (age 10), average Statistical Software version 3.4.0 (R Core Team, 2017) was

depressive severity score was 7.27, t(114)= 18.72, used to measure within- and between-individual change in

p < .0001. With each one year increase in age, depressive severity across the ten time-points (e.g., annual

participants decreased an average of 0.51 unit in assessments from ages 10 to 19). The Level 1 model estimated

---

