/* Logistic models (raw 4 features + log-scale) */

/* Model 1: raw 4-feature set */
ods output
  ParameterEstimates = work.parms_fft4;

proc logistic data=work.model_fft_4feature descending;
  model is_aggressive_num =
      accel_fft_energy_total
      gyro_fft_energy_total
      accel_fft_centroid_hz
      gyro_fft_centroid_hz;
  roc;
run;

/* Create log-scaled features */
data work.model_fft_4feature_log;
  set work.model_fft_4feature;

  log_accel_fft_energy = log(1 + accel_fft_energy_total);
  log_gyro_fft_energy  = log(1 + gyro_fft_energy_total);

  log_accel_fft_centroid = log(accel_fft_centroid_hz);
  log_gyro_fft_centroid  = log(gyro_fft_centroid_hz);

  label
    log_accel_fft_energy   = "Log total acceleration spectral energy"
    log_gyro_fft_energy    = "Log total gyroscope spectral energy"
    log_accel_fft_centroid = "Log acceleration spectral centroid (Hz)"
    log_gyro_fft_centroid  = "Log gyroscope spectral centroid (Hz)";
run;


/* Model 2: log-scaled 4-feature set */
ods output
  ParameterEstimates = work.parms_fft4_log;

proc logistic data=work.model_fft_4feature_log descending;
  model is_aggressive_num =
      log_accel_fft_energy
      log_gyro_fft_energy
      log_accel_fft_centroid
      log_gyro_fft_centroid;
  roc;
run;


/* Model 3: reduced log model */
ods output
  ParameterEstimates = work.parms_fft4_log_red;

proc logistic data=work.model_fft_4feature_log descending;
  model is_aggressive_num =
      log_gyro_fft_energy
      log_accel_fft_centroid
      log_gyro_fft_centroid;
  roc;
run;

