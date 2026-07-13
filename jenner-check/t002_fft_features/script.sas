/* FFT feature engineering from work.longitudinal_fft_long
   (from sas/02_feature_engineering.sas)

   In the pipeline this dataset is produced by 01_data_cleaning.sas from the
   trip CSVs. Here we synthesize a small, deterministic longitudinal_fft_long
   with the same schema so the FFT macros below run standalone: one labeled
   event with one window, built from fixed-frequency sinusoids so the spectral
   energy and centroid are reproducible. The window length N is set to 64 here
   (a compact power of 2) rather than the pipeline's 128 so a full window fits
   in the captured run; the transpose / hand-coded DFT / centroid logic below is
   the feature-engineering code unchanged. */

%let fs = 50;      /* target sampling rate (Hz) */
%let N  = 64;      /* fixed length (power of 2) */

data work.longitudinal_fft_long;
  length event_id $60 event_type $35;
  event_id = 'T2_C3_S141_E143'; event_type = 'Aggressive Braking'; is_aggressive = 1;
  window_index = 1;
  do idx = 0 to %eval(&N-1);
    t = idx / &fs;
    /* fixed-frequency sinusoids: strong, higher-frequency rotation */
    accel_x = sin(2*constant('pi')*3*t) + 0.5;
    accel_y = 0.7*sin(2*constant('pi')*5*t + 0.3);
    accel_z = 9.6 + 0.2*sin(2*constant('pi')*2*t);
    gyro_x  = 1.1*sin(2*constant('pi')*10*t);
    gyro_y  = 0.2*sin(2*constant('pi')*7*t + 1.1);
    gyro_z  = 0.85*sin(2*constant('pi')*8*t + 0.5);
    output;
  end;
  keep event_id window_index idx event_type is_aggressive
       accel_x accel_y accel_z gyro_x gyro_y gyro_z;
run;

/* Sort */
proc sort data=work.longitudinal_fft_long;
  by event_id window_index idx;
run;

/* Transpose each axis to wide: one row per (event_id, window_index) */
%macro ToWideEW(var=, out=);
proc transpose data=work.longitudinal_fft_long out=&out(drop=_name_) prefix=&var._;
  by event_id window_index;
  id idx;
  var &var;
run;
%mend;

%ToWideEW(var=accel_x, out=work.w_accel_x);
%ToWideEW(var=accel_y, out=work.w_accel_y);
%ToWideEW(var=accel_z, out=work.w_accel_z);
%ToWideEW(var=gyro_x,  out=work.w_gyro_x);
%ToWideEW(var=gyro_y,  out=work.w_gyro_y);
%ToWideEW(var=gyro_z,  out=work.w_gyro_z);

/* Create window-level metadata (one row per event_id, window_index) */
proc sql;
  create table work.win_meta as
  select distinct
    event_id,
    window_index,
    event_type,
    is_aggressive
  from work.longitudinal_fft_long;
quit;

proc sort data=work.win_meta;   by event_id window_index; run;
proc sort data=work.w_accel_x;  by event_id window_index; run;
proc sort data=work.w_accel_y;  by event_id window_index; run;
proc sort data=work.w_accel_z;  by event_id window_index; run;
proc sort data=work.w_gyro_x;   by event_id window_index; run;
proc sort data=work.w_gyro_y;   by event_id window_index; run;
proc sort data=work.w_gyro_z;   by event_id window_index; run;

/* Merge wide axes + window labels */
data work.win_wide;
  merge work.win_meta(in=a)
        work.w_accel_x work.w_accel_y work.w_accel_z
        work.w_gyro_x  work.w_gyro_y  work.w_gyro_z;
  by event_id window_index;
  if a;
run;

/* FFT energy + spectral centroid per axis */
%macro ComputeFFTEnergyCentroidEW(axis=);

data work.win_wide;
  set work.win_wide;

  array x[0:%eval(&N-1)] &axis._0 - &axis._%eval(&N-1);

  pi    = constant('pi');
  twopi = 2*pi;
  kmax  = %eval(&N/2);

  mean_x = 0;
  do n=0 to %eval(&N-1);
    mean_x + x[n];
  end;
  mean_x = mean_x / &N;

  do n=0 to %eval(&N-1);
    x[n] = x[n] - mean_x;
  end;

  total_power = 0;
  sumFP       = 0;

  do k=0 to kmax;
    re = 0; im = 0;

    do n=0 to %eval(&N-1);
      ang = twopi*k*n/&N;
      re + x[n]*cos(ang);
      im + (-x[n]*sin(ang));
    end;

    power = re*re + im*im;

    if k >= 1 then do;
      f = k*&fs/&N;
      total_power + power;
      sumFP + f*power;
    end;
  end;

  &axis._fft_energy = total_power;

  if total_power > 0 then &axis._fft_centroid_hz = sumFP / total_power;
  else &axis._fft_centroid_hz = .;

  drop pi twopi kmax mean_x n k re im ang power f total_power sumFP;
run;

%mend;

/* Apply to all 6 axes */
%ComputeFFTEnergyCentroidEW(axis=accel_x);
%ComputeFFTEnergyCentroidEW(axis=accel_y);
%ComputeFFTEnergyCentroidEW(axis=accel_z);

%ComputeFFTEnergyCentroidEW(axis=gyro_x);
%ComputeFFTEnergyCentroidEW(axis=gyro_y);
%ComputeFFTEnergyCentroidEW(axis=gyro_z);

/* Final 4 feature analytical dataset */
data work.model_fft_4feature_win;
  set work.win_wide;

  /* total energies */
  accel_fft_energy_total =
    sum(accel_x_fft_energy, accel_y_fft_energy, accel_z_fft_energy);

  gyro_fft_energy_total  =
    sum(gyro_x_fft_energy,  gyro_y_fft_energy,  gyro_z_fft_energy);

  /* centroid from dominant energy axis */
  if accel_x_fft_energy >= accel_y_fft_energy and accel_x_fft_energy >= accel_z_fft_energy then
    accel_fft_centroid_hz = accel_x_fft_centroid_hz;
  else if accel_y_fft_energy >= accel_x_fft_energy and accel_y_fft_energy >= accel_z_fft_energy then
    accel_fft_centroid_hz = accel_y_fft_centroid_hz;
  else
    accel_fft_centroid_hz = accel_z_fft_centroid_hz;

  if gyro_x_fft_energy >= gyro_y_fft_energy and gyro_x_fft_energy >= gyro_z_fft_energy then
    gyro_fft_centroid_hz = gyro_x_fft_centroid_hz;
  else if gyro_y_fft_energy >= gyro_x_fft_energy and gyro_y_fft_energy >= gyro_z_fft_energy then
    gyro_fft_centroid_hz = gyro_y_fft_centroid_hz;
  else
    gyro_fft_centroid_hz = gyro_z_fft_centroid_hz;

  /* Keep only relevant variables for modeling */
  keep event_id window_index event_type
       is_aggressive
       accel_fft_energy_total
       gyro_fft_energy_total
       accel_fft_centroid_hz
       gyro_fft_centroid_hz;
run;

/* Summary */
proc sql;
  select count(*) as n_rows_in_model
  from work.model_fft_4feature_win;
quit;

proc sql;
  select count(*) as n_distinct_windows
  from (select distinct event_id, window_index from work.model_fft_4feature_win);
quit;

/* Show the derived features (small enough to print in full) */
proc print data=work.model_fft_4feature_win noobs;
run;
