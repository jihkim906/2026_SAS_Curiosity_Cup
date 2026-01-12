# Detection of Aggressive Driving Events Using Smartphone Sensor Data (SAS)

## Project Overview
This project demonstrates how frequency-domain features derived from smartphone motion sensors can effectively detect aggressive driving behavior using classical statistical modeling in SAS. While machine learning approaches such as decision trees, random forests, and support vector machines have been shown to achieve higher classification performance (AUC ≈ 0.98; Ferreira et al., 2017), these models often offer limited interpretability regarding how individual features contribute to driving risk.

In this project, frequency-domain information is extracted from time-domain sensor signals using the Fast Fourier Transform (FFT). Spectral features are then derived to capture both the intensity and dominant frequency characteristics of motion. These features are used as covariates in a logistic regression model, allowing direct interpretation of covariate effects through estimated coefficients and odds ratios.

The final model achieves an AUC of approximately 0.94, with all retained covariates statistically significant. This approach demonstrates that strong predictive performance can be achieved while maintaining interpretability, providing clearer insight into how accelerometer and gyroscope signals are associated with the risk of aggressive driving behavior.

---

## Data Description
- **Dataset**: [Driver Behavior Dataset](https://github.com/jair-jr/driverBehaviorDataset) 
- **Events**: 69 total (aggresive vs non-aggresive) 
- **Sensors**:
  - 3-axis accelerometer (x, y, z)
  - 3-axis gyroscope (x, y, z)
- **Sampling rate**: ~ 50 Hz
- **Observation unit**: Event-level time windows
---

## Frequency-Domain Feature Engineering

Each sensor asix is transformed from time-domain to frequency-domain using the **Fast Fourier Transform (FFT)**. The FFT represents motion in terms of its frequency content, which is informative for distinguishing aggressive maneuvers such as hard braking, sharp turns, and lane changes.

For each axis, two features are extracted:

- **Spectral energy**: captures overall motion intensity
- **Spectral centroid**: captures the dominant frequency of motion, indicating whether movement is slow and sustained or rapid and oscillatory

Axis-level features are aggregated to form four event-level predictors:

- Total accelerometer spectral energy
- Total gyroscope spectral energy
- Dominant accelerometer spectral centroid
- Dominant gyroscope spectral centroid

---



---

## Statistical Modeling

Driving behavour (aggressive vs non-aggresive) is modelled using binary logistic regression.

The final model includes:
- Log gyroscope spectral energy
- Log accelerometer spectral centroid
- Log gyroscope spectral centroid

### SAS outputs

#### Response Profile

| Outcome | is_aggressive_num | Frequency |
|------|------------------|-----------|
| Aggressive | 1 | 55 |
| Non-aggressive | 0 | 14 |


#### Model Fit Statistics

| Criterion | Intercept Only | Intercept + Covariates |
|---------|----------------|------------------------|
| AIC | 71.606 | **41.633** |
| SC | 73.841 | **50.569** |
| −2 Log Likelihood | 69.606 | **33.633** |


#### Testing Global Null Hypothesis: BETA=0

| Test | Chi-Square | DF | p-value |
|----|-----------|----|--------|
| Likelihood Ratio | 35.97 | 3 | <0.0001 |
| Score | 33.23 | 3 | <0.0001 |
| Wald | 14.12 | 3 | 0.0027 |


#### Analysis of Maximum Likelihood Estimates

| Predictor | Estimate | Std. Error | Wald χ² | p-value |
|--------|---------|------------|--------|--------|
| Intercept | −5.09 | 2.88 | 3.12 | 0.077 |
| $\log(E_{\text{gyro}})$ | **1.46** | 0.44 | 10.84 | **0.0010** |
| $\log(C_{\text{accel}})$ | **−3.22** | 0.92 | 12.27 | **0.0005** |
| $\log(C_{\text{gyro}})$ | **1.93** | 0.86 | 5.03 | **0.0249** |

The fitted model is:

$$ \log \left( \frac{P(\text{Aggressive})}{1 - P(\text{Aggressive})} \right) = -5.09 + 1.46 \cdot \log(E_{\text{gyro}}) - 3.22 \cdot \log(C_{\text{accel}}) + 1.93 \cdot \log(C_{\text{gyro}}) $$

where:
- $E_{\text{gyro}}$ = total gyroscope FFT energy  
- $C_{\text{accel}}$ = accelerometer spectral centroid (Hz)  
- $C_{\text{gyro}}$ = gyroscope spectral centroid (Hz)

#### Odds Ratio Estimates

| Predictor | Odds Ratio | 95% CI |
|--------|-----------|-------|
| $\log(E_{\text{gyro}})$ | **4.29** | (1.80, 10.22) |
| $\log(C_{\text{accel}})$ | **0.04** | (0.007, 0.24) |
| $\log(C_{\text{gyro}})$ | **6.92** | (1.28, 37.46) |


#### ROC Association Statistics

| ROC Model | AUC (Area) | Std. Error | 95% CI (Lower) | 95% CI (Upper) | Somers' D | Gamma | Tau-a |
|----------|------------|------------|---------------|---------------|----------|--------|-------|
| Model    | 0.9377     | 0.0291     | 0.8806        | 0.9947        | 0.8753   | 0.8753 | 0.2873 |
| ROC1     | 0.5000     | 0.0000     | 0.5000        | 0.5000        | 0.0000   | .      | 0.0000 |


---

## Key Results
- Despite a relatively small sample size (n = 64), the model clearly distinguishes between aggressive and non-aggressive driving events
- **Global model significance**: the logistic regression model is statistically significant at the 5% level
- **Classification performation** : strong discriminative ability with an Area Under the ROC Curve (AUC) of approximately 0.94
    

---

## Interpretation

- **Gyroscope spectral energy**: Higher rotational energy strongly increases the odds of aggressive driving, reflecting abrupt steering or rotational movements.
- **Accelerometer spectral centroid**: Aggressive events are associated with lower dominant acceleration frequencies, consistent with large, sustained motion rather than rapid oscillations.
- **Gyroscope spectral centroid**: Higher dominant rotational frequencies substantially increase aggression odds, consistent with sharp turns and lane changes.

---
## Applications
This framework is applicable to:
- Usage-based insurance and telematics  
- Safety monitoring and driver risk scoring

---


---

## Future Work
---

---

## References

1. Ferreira Júnior, J., Carvalho, E., Ferreira, B. V., de Souza, C., Suhara, Y., Pentland, A., & Pessin, G. (2017).  
   *Driver behavior profiling: An investigation with different smartphone sensors and machine learning.*  
   PLOS ONE, 12(4), e0174959.  
   https://doi.org/10.1371/journal.pone.0174959

2. Driver Behavior Dataset.  
   https://github.com/jair-jr/driverBehaviorDataset

