# Detection of Aggressive Driving Using Smartphone Sensor Data

## Overview

This project was developed for **The Curiosity Cup 2026 – A Global SAS Student Competition**.  
**Full paper:** [SAS Curiosity Cup 2026 Final Report](./SAS_Curiosity_Cup_2026_Final_Report.pdf)

This project is exclusively implemented in SAS, including data processing, statistical modelling, and performance evaluation.

We proposed an interpretable statistical framework for detecting aggressive driving behavior using smartphone motion sensors. While the study by Ferreira et al. (2017), [*Driver Behavior Profiling: An Investigation with Different Smartphone Sensors and Machine Learning*](https://doi.org/10.1371/journal.pone.0174959), demonstrates strong performance using machine learning, many approaches operate as black-box classifiers.

Our objective is to retain strong predictive performance while explicitly quantifying how motion dynamics contribute to aggressive driving risk.

---

## Method Summary

Using the [*Driver Behavior Dataset*](https://github.com/jair-jr/driverBehaviorDataset), we analyzed 69 labeled driving events (aggressive vs. non-aggressive) collected from smartphone accelerometer and gyroscope sensors (~50–200 Hz sampling), which were segmented into overlapping windows to generate window-level samples.

Time-series signals were transformed into the frequency domain using the **Fast Fourier Transform (FFT)**. From each window, we derived:

- **Spectral energy** (motion intensity)
- **Spectral centroid** (dominant oscillation frequency)

Window-level features were analyzed using a **mixed-effects logistic regression model (PROC GLIMMIX, Laplace estimation)** in SAS to account for within-event correlation.

---

## Key Results

### Significant Predictors (Log-Odds Scale)
- Gyroscope spectral energy: β = 23.91 (95% CI: 8.10–39.71), p = 0.0033  
- Gyroscope spectral centroid: β = 47.26 (95% CI: 23.36–71.16), p = 0.0001  
- Accelerometer spectral centroid: β = −19.27 (95% CI: −37.54 to −1.00), p = 0.0397  

### Interpretation
Aggressive driving is primarily characterized by **strong and abrupt rotational motion**, reflecting sharp steering inputs and rapid directional changes.

### Model Performance
- **AUC = 0.973** (95% CI: 0.945–1.000)  
- Strong discrimination between aggressive and non-aggressive windows  

---

## Contribution

This project demonstrates that **frequency-domain modelling combined with mixed-effects logistic regressionS** can effectively translate raw smartphone sensor data into interpretable driving risk indicators.

Unlike purely machine learning approaches, this framework provides direct interpretation of how rotational intensity and oscillatory dynamics influence aggressive driving probability, while maintaining strong predictive performance.

---

## References

- [Driver Behavior Dataset](https://github.com/jair-jr/driverBehaviorDataset)
- [Driver Behavior Profiling: An Investigation with Different Smartphone Sensors and Machine Learning](https://doi.org/10.1371/journal.pone.0174959)

