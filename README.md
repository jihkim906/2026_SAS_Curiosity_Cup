# Detection of Aggressive Driving Events Using Smartphone Sensor Data (SAS)

## Background and Motivation
Smartphone-based motion sensors have been widely studied for characterizing driving behavior, with applications in road safety, telematics, and risk monitoring. Accelerometers and gyroscopes capture distinctive motion patterns during aggressive maneuvers such as hard braking, rapid acceleration, sharp turns, and lane changes.

Prior research has shown that smartphone sensor data can reliably capture aggressive driving behavior when combined with appropriate signal processing and modeling techniques (e.g., Ferreira et al., 2017). These studies demonstrate that short time windows of accelerometer and gyroscope signals contain strong discriminative information for driver behavior profiling.

Many existing approaches rely on complex machine-learning models that can be difficult to interpret or audit. This project focuses instead on principled signal processing and interpretable statistical modeling, demonstrating that frequency-domain features derived from short sensor windows can effectively distinguish aggressive from non-aggressive driving using logistic regression implemented in SAS.

---

## Data Description
The analysis uses a publicly available smartphone driving dataset collected during four real-world driving trips. The dataset contains high-frequency inertial sensor recordings paired with manually annotated driving events, and has been used in prior research on driver behavior profiling.

- **Total events**: 69  
- **Aggressive events**: braking, acceleration, turns, lane changes  
- **Non-aggressive events**: baseline driving  
- **Sensors**:
  - Accelerometer (x, y, z)
  - Gyroscope (x, y, z)
- **Sampling rate**: approximately 50 Hz (standardized during preprocessing)

Each event is labeled using ground-truth start and end times and is treated as an independent observation. A detailed description of the data collection protocol, sensor characteristics, and event definitions is available in the original dataset repository:

- **Driver Behavior Dataset**: https://github.com/jair-jr/driverBehaviorDataset

---

## Methods

### Event Alignment and Signal Resampling
Raw accelerometer and gyroscope signals are first aligned to ground-truth event intervals. For each event:

- Signals are resampled to a fixed grid of **128 samples at 50 Hz** (~2.56 seconds)
- Bin-averaging is used to regularize the sampling
- Missing bins are zero-filled to ensure equal-length signals

This standardization enables consistent frequency-domain analysis across events.

---

### Frequency-Domain Feature Engineering

To characterize driving behavior beyond raw time-domain signals, sensor data are transformed into the frequency domain using the Fast Fourier Transform (FFT). The FFT decomposes a time-series signal into a set of frequency components, allowing motion patterns to be described in terms of their dominant frequencies and overall intensity. This representation is particularly useful for distinguishing aggressive maneuvers, which often exhibit characteristic low- to mid-frequency motion with large amplitudes.

For each sensor axis, the resampled signal is demeaned and transformed to the frequency domain using a discrete Fourier transform.

From the FFT output, two summary features are computed:

- **Total spectral energy**:  
  Defined as the sum of squared magnitudes of the Fourier coefficients across frequencies. This feature captures the overall intensity of dynamic motion during an event.

- **Spectral centroid**:  
  Defined as the power-weighted average frequency, representing the dominant frequency content of the signal. Lower centroid values correspond to slower, sustained movements, while higher values indicate more rapid oscillatory motion.

Axis-level features are then aggregated to create four event-level predictors:
1. Total accelerometer spectral energy  
2. Total gyroscope spectral energy  
3. Dominant accelerometer spectral centroid  
4. Dominant gyroscope spectral centroid  

Log transformations are applied to these features to stabilize scale differences and improve model fit in subsequent logistic regression analyses.

---

## Statistical Modeling
Binary logistic regression is used to model the probability that an event is aggressive. Three models are evaluated:
1. Raw frequency-domain features  
2. Log-scaled frequency-domain features  
3. **Reduced log-scaled model**

Model performance is assessed using likelihood-based statistics and ROC analysis.

---

## Results

### Outcome Distribution
The final modeling dataset contains 69 events with the following class distribution:

| Outcome | is_aggressive_num | Frequency |
|------|------------------|-----------|
| Aggressive | 1 | 55 |
| Non-aggressive | 0 | 14 |

---

### Model Fit and Global Significance
The reduced log-scaled model provides a substantial improvement over the intercept-only model.

| Criterion | Intercept Only | Intercept + Covariates |
|---------|----------------|------------------------|
| AIC | 71.606 | **41.633** |
| SC | 73.841 | **50.569** |
| −2 Log Likelihood | 69.606 | **33.633** |

Global hypothesis tests indicate strong overall significance:

| Test | Chi-Square | DF | p-value |
|----|-----------|----|--------|
| Likelihood Ratio | 35.97 | 3 | <0.0001 |
| Score | 33.23 | 3 | <0.0001 |
| Wald | 14.12 | 3 | 0.0027 |

---

### Final Reduced Logistic Regression Model
The final model includes three predictors:

- Log gyroscope spectral energy  
- Log accelerometer spectral centroid  
- Log gyroscope spectral centroid  

The fitted model is:

$$ \log \left( \frac{P(\text{Aggressive})}{1 - P(\text{Aggressive})} \right) = -5.09 + 1.46 \cdot \log(E_{\text{gyro}}) - 3.22 \cdot \log(C_{\text{accel}}) + 1.93 \cdot \log(C_{\text{gyro}}) $$

where:
- $E_{\text{gyro}}$ = total gyroscope FFT energy  
- $C_{\text{accel}}$ = accelerometer spectral centroid (Hz)  
- $C_{\text{gyro}}$ = gyroscope spectral centroid (Hz)

---

### Parameter Estimates

| Predictor | Estimate | Std. Error | Wald χ² | p-value |
|--------|---------|------------|--------|--------|
| Intercept | −5.09 | 2.88 | 3.12 | 0.077 |
| $\log(E_{\text{gyro}})$ | **1.46** | 0.44 | 10.84 | **0.0010** |
| $\log(C_{\text{accel}})$ | **−3.22** | 0.92 | 12.27 | **0.0005** |
| $\log(C_{\text{gyro}})$ | **1.93** | 0.86 | 5.03 | **0.0249** |

---

### Odds Ratios and Interpretation

| Predictor | Odds Ratio | 95% CI |
|--------|-----------|-------|
| $\log(E_{\text{gyro}})$ | **4.29** | (1.80, 10.22) |
| $\log(C_{\text{accel}})$ | **0.04** | (0.007, 0.24) |
| $\log(C_{\text{gyro}})$ | **6.92** | (1.28, 37.46) |

**Interpretation**:
- **Gyroscope spectral energy**: Higher rotational energy strongly increases the odds of aggressive driving, reflecting abrupt steering or rotational movements.
- **Accelerometer spectral centroid**: Aggressive events are associated with lower dominant acceleration frequencies, consistent with large, sustained motion rather than rapid oscillations.
- **Gyroscope spectral centroid**: Higher dominant rotational frequencies substantially increase aggression odds, consistent with sharp turns and lane changes.

---

### Classification Performance
The reduced model demonstrates strong discriminative ability:
- **Area Under the ROC Curve (AUC): ~0.94**
- Clear separation between aggressive and non-aggressive events despite a small sample size

---

## Applications
This framework is applicable to:
- Usage-based insurance and telematics  
- Safety monitoring and driver risk scoring

## References

1. Ferreira Júnior, J., Carvalho, E., Ferreira, B. V., de Souza, C., Suhara, Y., Pentland, A., & Pessin, G. (2017).  
   *Driver behavior profiling: An investigation with different smartphone sensors and machine learning.*  
   PLOS ONE, 12(4), e0174959.  
   https://doi.org/10.1371/journal.pone.0174959

2. Driver Behavior Dataset.  
   https://github.com/jair-jr/driverBehaviorDataset

