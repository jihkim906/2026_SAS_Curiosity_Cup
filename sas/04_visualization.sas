/* One-event demo: raw signal -> resampled signal -> FFT spectrum */

options nodate nonumber;
dm log 'clear';

/* Settings */
%let fs   = 50;                      /* resampling rate (Hz) */
%let N    = 128;                     /* fixed window length (samples) */
%let axis = accel_x;                 /* accel_x accel_y accel_z gyro_x gyro_y gyro_z */
%let demo_event_id = T1_C0_S2_E6.5;  /* exact event_id */

%let window_sec = %sysevalf(&N / &fs);

/* Sort for consistent event ordering */
proc sort data=work.master_event_data;
  by event_id seconds_from_start;
run;

/* t0 = event start time */
proc sql;
  create table work._demo_t0 as
  select
    event_id,
    min(seconds_from_start) as t0
  from work.master_event_data
  where event_id="&demo_event_id"
  group by event_id;
quit;

/* Plot A: raw signal in the analysis window */
data work.demo_raw;
  if _n_=1 then set work._demo_t0;
  set work.master_event_data;
  where event_id="&demo_event_id";

  time_sec = seconds_from_start - t0;
  signal   = &axis;

  if 0 <= time_sec <= &window_sec;

  keep time_sec signal;
run;

title "Raw Smartphone Signal During a Single Driving Event";
footnote "Fixed analysis window used for resampling and FFT";

proc sgplot data=work.demo_raw;
  series x=time_sec y=signal;
  xaxis label="Time since event onset (seconds)"
        min=0 max=&window_sec;
  yaxis label="Sensor signal (&axis)";
run;

title; footnote;

/* Resample: bin-average to a uniform grid (0..N-1), zero-fill missing bins */
data work._raw_with_bins;
  if _n_=1 then set work._demo_t0;
  set work.master_event_data;
  where event_id="&demo_event_id";

  time_sec = seconds_from_start - t0;
  signal   = &axis;

  idx = floor(time_sec * &fs);
  if 0 <= idx < &N;

  keep idx signal;
run;

proc sql;
  create table work._bin_mean as
  select
    idx,
    mean(signal) as bin_mean
  from work._raw_with_bins
  group by idx
  order by idx;
quit;

data work._grid;
  do idx=0 to %eval(&N-1);
    time_sec = idx / &fs;
    output;
  end;
run;

proc sql;
  create table work.demo_processed as
  select
    g.idx,
    g.time_sec,
    coalesce(m.bin_mean, 0) as bin_mean
  from work._grid g
  left join work._bin_mean m
    on g.idx = m.idx
  order by g.idx;
quit;

/* Plot B: resampled signal */
title "Resampled and Bin-Averaged Signal";
footnote "Uniform grid at &fs Hz (N=&N), zero-filled bins";

proc sgplot data=work.demo_processed;
  series x=time_sec y=bin_mean / lineattrs=(thickness=2);
  xaxis label="Time since event onset (seconds)"
        min=0 max=&window_sec;
  yaxis label="Resampled signal (&axis)";
run;

title; footnote;

/* FFT: power spectrum (demean; k=1..N/2) */
proc transpose data=work.demo_processed
               out=work._demo_wide(drop=_name_)
               prefix=x_;
  id idx;
  var bin_mean;
run;

data work.demo_fft;
  set work._demo_wide;

  array x[0:%eval(&N-1)] x_0 - x_%eval(&N-1);

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

  do k=1 to kmax;
    re = 0; im = 0;

    do n=0 to %eval(&N-1);
      ang = twopi*k*n/&N;
      re + x[n]*cos(ang);
      im + (-x[n]*sin(ang));
    end;

    frequency_hz   = k*&fs/&N;
    spectral_power = re*re + im*im;

    output;
  end;

  keep frequency_hz spectral_power;
run;

/* Plot C: FFT spectrum */
title "Frequency-Domain Representation of the Resampled Signal";
footnote "Power spectrum from the fixed-length resampled vector";

proc sgplot data=work.demo_fft;
  series x=frequency_hz y=spectral_power;
  xaxis label="Frequency (Hz)";
  yaxis label="Spectral power";
run;

title; footnote;
