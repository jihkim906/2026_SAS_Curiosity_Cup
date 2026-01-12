/* Feature engineering from work.master_event_data (resample -> FFT -> 4 features) */

/* FFT settings */
%let fs = 50;      /* target sampling rate (Hz) */
%let N  = 128;     /* fixed length (power of 2) */


/* Event-level metadata (t0 = event start) */
proc sort data=work.master_event_data; by event_id; run;

proc sql;
  create table work.event_meta as
  select
    event_id,
    max(trip_id) as trip_id,
    max(event_classifier) as event_classifier,
    max(event_type) as event_type length=35,
    max(is_aggressive) as is_aggressive,
    min(seconds_from_start) as t0
  from work.master_event_data
  group by event_id;
quit;


/* Bin-average onto uniform grid: idx = 0..N-1 */
data work.binned_long;
  merge work.master_event_data(in=a)
        work.event_meta(in=b keep=event_id t0);
  by event_id;
  if a and b;

  idx = floor((seconds_from_start - t0) * &fs);
  if 0 <= idx < &N;

  keep event_id idx accel_x accel_y accel_z gyro_x gyro_y gyro_z;
run;

proc sql;
  create table work.binned_mean as
  select
    event_id,
    idx,
    mean(accel_x) as accel_x,
    mean(accel_y) as accel_y,
    mean(accel_z) as accel_z,
    mean(gyro_x)  as gyro_x,
    mean(gyro_y)  as gyro_y,
    mean(gyro_z)  as gyro_z
  from work.binned_long
  group by event_id, idx
  order by event_id, idx;
quit;


/* Full grid per event + zero-fill missing bins */
data work.event_grid;
  set work.event_meta(keep=event_id);
  do idx = 0 to %eval(&N-1);
    output;
  end;
run;

proc sql;
  create table work.grid_join as
  select
    g.event_id,
    g.idx,
    coalesce(b.accel_x,0) as accel_x,
    coalesce(b.accel_y,0) as accel_y,
    coalesce(b.accel_z,0) as accel_z,
    coalesce(b.gyro_x,0)  as gyro_x,
    coalesce(b.gyro_y,0)  as gyro_y,
    coalesce(b.gyro_z,0)  as gyro_z
  from work.event_grid g
  left join work.binned_mean b
    on g.event_id=b.event_id and g.idx=b.idx
  order by g.event_id, g.idx;
quit;


/* Transpose each axis to wide (one row per event_id) */
%macro ToWide(var=, out=);
proc transpose data=work.grid_join out=&out(drop=_name_) prefix=&var._;
  by event_id;
  id idx;
  var &var;
run;
%mend;

%ToWide(var=accel_x, out=work.w_accel_x);
%ToWide(var=accel_y, out=work.w_accel_y);
%ToWide(var=accel_z, out=work.w_accel_z);
%ToWide(var=gyro_x,  out=work.w_gyro_x);
%ToWide(var=gyro_y,  out=work.w_gyro_y);
%ToWide(var=gyro_z,  out=work.w_gyro_z);


/* Merge wide axes + event labels */
proc sort data=work.event_meta; by event_id; run;
proc sort data=work.w_accel_x;  by event_id; run;
proc sort data=work.w_accel_y;  by event_id; run;
proc sort data=work.w_accel_z;  by event_id; run;
proc sort data=work.w_gyro_x;   by event_id; run;
proc sort data=work.w_gyro_y;   by event_id; run;
proc sort data=work.w_gyro_z;   by event_id; run;

data work.event_wide;
  merge work.event_meta
        work.w_accel_x work.w_accel_y work.w_accel_z
        work.w_gyro_x  work.w_gyro_y  work.w_gyro_z;
  by event_id;
run;


/* FFT energy + spectral centroid per axis (demean; exclude DC only) */
%macro ComputeFFTEnergyCentroid(axis=);

data work.event_wide;
  set work.event_wide;

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

/* apply to all 6 axes */
%ComputeFFTEnergyCentroid(axis=accel_x);
%ComputeFFTEnergyCentroid(axis=accel_y);
%ComputeFFTEnergyCentroid(axis=accel_z);

%ComputeFFTEnergyCentroid(axis=gyro_x);
%ComputeFFTEnergyCentroid(axis=gyro_y);
%ComputeFFTEnergyCentroid(axis=gyro_z);


/* Final 4-feature dataset */
data work.model_fft_4feature;
  set work.event_wide;

  is_aggressive_num = (is_aggressive=1);

  accel_fft_energy_total =
    sum(accel_x_fft_energy, accel_y_fft_energy, accel_z_fft_energy);

  gyro_fft_energy_total  =
    sum(gyro_x_fft_energy,  gyro_y_fft_energy,  gyro_z_fft_energy);

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

  keep event_id trip_id event_classifier event_type
       is_aggressive_num
       accel_fft_energy_total
       gyro_fft_energy_total
       accel_fft_centroid_hz
       gyro_fft_centroid_hz;
run;

