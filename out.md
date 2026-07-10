# sample

# 1226

Rajpreet Chahal et al.

substudy of precursors of depression, where half the participants displayed elevated depressive symptoms and half did not (Appendix S1). Written assent/consent was obtained for all participants and their parents, and monetary compensation

was provided. Study procedures were approved by the Human Protections Committee and Institutional Review Board of the study sites.

Measures Depressive symptom severity. Self-reported depressive symptoms were collected using the Child, Adolescent, and Adult Symptom Inventories– 4th Edition beginning when the girls were age 10 and continuing annually through age 19 (Gadow, 2015). All 9 symptoms of DSM-IV major depressive disorder were assessed with these inventories, which demonstrate high validity, reliability, and clinical utility (Salcedo et al., 2017). Symptom severity, a dimensional measure, provides a significant advantage in identifying youth with mood disorders (Salcedo et al., 2017). Items were rated 0 (never), 1 (sometimes), 2 (often), or 3 (very often) and summed; yes or no items (e.g., change in appetite) were recoded

distribution of maximal component size obtained under the (yes= 2.5, no = 0.5) following the scoring criteria. Reliability

at ages 10–19 ranged from a = .72–.86. Research shows that youth self-reported depression, compared with parent-report or multi-informant report, best predicts concurrent depressive episodes as assessed by a clinical diagnostic interview (Cohen, So, Young, Hankin, & Lee, 2019). See Appendix S2 for information about estimated major depressive disorder occurrence. White matter diffusion-weighted imaging. At approximately age 19, girls underwent diffusion-weighted imaging on a 3.0T Siemens Tim Trio scanner (Siemens Medical Solutions, Erlangen, Germany). A pulsed-gradient spin-echo sequence was applied in 68 directions, with posterior-to-

anterior phase encoding. Scan parameters included repetition time (TR)= 8,500 ms, echo time (TE)= 91 ms, and field of view (FOV)= 256 mm2. Sixty-four contiguous slices were acquired

with an isotropic voxel size of 2.0 mm3 and a b-value of 1,000 s/mm2 (see Appendix S3 for preprocessing steps). A high-resolution T1-weighted anatomical image was acquired with the following parameters: TR= 2,300 ms; TE= 2.98 ms; flip angle= 9°; 160 slices; FOV= 256 mm; acquisition voxel size= 1.0 9 1.0 9 1.2 mm. Tractography and graph construction. Anatomical images were coregistered to diffusion native space and parcellated into 94 contiguous regions of interest based on the automatic anatomical labeling atlas 2 (AAL2; Rolls, Joliot, & Tzourio-Mazoyer, 2015), currently the most widely used atlas in connectivity studies (Hallquist & Hillary, 2018). Whole-brain probabilistic tractography was run using FSL’s BEDPOSTX and PROBTRACKX (Behrens, Berg, Jbabdi, Rushworth, & Woolrich, 2007); 5,000 streamlines/voxel were sampled for each of the 94 regions. The maximum connective values between pairs of regions were taken to compute per-person connectivity matrices representing the probabilities of connec-

### better than the linear model; however, there were no matrices; additional detail in Appendix S3).

tions among regions (i.e., 94 9 94 undirected and weighted

Data analysis Depressive symptom severity course. Unconditional multilevel growth modeling (Hedeker & Gibbons, 2012) in R Statistical Software version 3.4.0 (R Core Team, 2017) was used to measure within- and between-individual change in

depressive severity across the ten time-points (e.g., annual

### participants decreased an average of 0.51 unit in assessments from ages 10 to 19). The Level 1 model estimated

J Child Psychol Psychiatr 2020; 61(11): 1224–33

yearly, within-individual changes in depressive severity during the 10-year period; the Level 2 model estimated the sample’s average growth trajectory. Linear and quadratic models were fit to the data. The intercept of time was coded as beginning at age 10, and each time-point was coded as integers from 0 to 9 (age 10–19). The linear and quadratic models’ fit criteria were compared for model selection. Per-person estimates of intercept and slope, derived from multilevel modeling, were extracted for connectivity analyses. Structural connectivity analysis. Network-based

statistic (NBS) analyses (Zalesky, Fornito, & Bullmore, 2010), a robust method to control family-wise error rate during mass

univariate testing, were used to test associations between interregional connectivity matrices and depression course

variables. NBS analyses identified clusters (i.e., subnetworks) of brain regions where the strength of edges between them was associated with depression course variables. A primary component-forming threshold (p < .001, uncorrected) was applied to form suprathreshold edges of these subnetworks. Size of remaining connected components was computed and its statistical significance evaluated against an empirical null

null hypothesis of random group membership (1,000 permu-

tations). Subnetworks significant at a corrected level of p < .01

were reported (see Appendix S4 for additional details on NBS and Appendix S5 for a list of included brain regions and abbreviations). Resulting p-values were adjusted for multiple comparisons using Bonferroni correction (a = .05). Depressive severity intercept, linear slope, and their interaction were included as predictor variables in one regression model. Given the following variables have been associated with depression and brain connectivity, we included covariates of head motion during the scan (mean frame-wise displacement) (Yendiki, Koldewyn, Kakunoori, Kanwisher, & Fischl, 2014), age 10 verbal IQ (Li et al., 2009), race (Nyquist et al., 2014), and socioeconomic status (SES; number of years receiving public assistance from ages 10 to 19) (Ursache & Noble, 2016). Given that anxiety may co-occur with depression (e.g., Yaroslavsky

et al., 2013), the main effect of anxiety symptoms at age 10 was tested in the presence of depressive symptom intercept; however, given the focus of this study on depression and that different neural systems may be implicated in depression, anxiety, and comorbid depression–anxiety, main analyses focused on depressive symptom course. Results Table 1 presents means, standard deviations, and correlations among depression measures, race, verbal IQ, head motion, and SES. The distributions of depressive severity scores at all time-points are presented in Figure S1. Depressive symptom severity course The quadratic model fit the longitudinal data slightly

### differences in model fit between quadratic models

with or without freely estimated quadratic terms (Table S1). Based on these results, we selected the quadratic model without the freely estimated quadratic term to parsimoniously conduct structural connectivity analyses. At time 0 (age 10), average depressive severity score was 7.27, t(114)= 18.72, p < .0001. With each one year increase in age,

---

