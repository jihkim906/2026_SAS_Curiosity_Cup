/* Modeling with PROC GLIMMIX */

/* Ensure ordering for repeated structure */
proc sort data=work.model_fft_4feature_win;
  by event_id window_index;
run;

/* Create numeric outcome and log-scaled features */
data work.model_fft_4feature_win_glm;
  set work.model_fft_4feature_win;

  /* binary numeric */
  is_aggressive_num = (is_aggressive=1);

  /* log-scaled energies */
  log_accel_fft_energy = log(1 + accel_fft_energy_total);
  log_gyro_fft_energy  = log(1 + gyro_fft_energy_total);

  /* non-positive centroids */
  if accel_fft_centroid_hz > 0 then log_accel_fft_centroid = log(accel_fft_centroid_hz);
  else log_accel_fft_centroid = .;

  if gyro_fft_centroid_hz > 0 then log_gyro_fft_centroid = log(gyro_fft_centroid_hz);
  else log_gyro_fft_centroid = .;
run;


ods output SolutionF = work.glmm_log_solutionf
           FitStatistics = work.glmm_log_fit;


proc glimmix data=work.model_fft_4feature_win_glm method=laplace;
  class event_id;

  model is_aggressive(event='1') =
      log_accel_fft_energy
      log_gyro_fft_energy
      log_accel_fft_centroid
      log_gyro_fft_centroid
    / dist=binomial link=logit solution;

  random intercept / subject=event_id;

  /* Predicted probability of event='1' */
  output out=work.glmm_pred pred(ilink)=p_glmm;
run;


/* AUC / ROC using predicted probabilities */
proc logistic data=work.glmm_pred;
  model is_aggressive(event='1') = p_glmm / nofit;
  roc 'GLIMMIX score' pred=p_glmm;
  ods output ROCAssociation=work.auc_glmm;
run;

/* Print AUC */
proc print data=work.auc_glmm noobs; run;




