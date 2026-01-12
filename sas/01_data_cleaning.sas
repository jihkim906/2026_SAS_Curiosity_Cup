/* Data cleaning + event labeling (trips 1–4) */
%let curiosity_path = /home/u64244912/curiosity;

options validvarname=v7 nodate nonumber;

/* Event class labels */
proc format;
  value evfmt
    0 = "Non-Aggressive Event"
    1 = "Aggressive Right Turn"
    2 = "Aggressive Left Turn"
    3 = "Aggressive Braking"
    4 = "Aggressive Right Lane Change"
    5 = "Aggressive Left Lane Change"
    6 = "Aggressive Acceleration"
    other = "Other/Unknown";
run;

%macro ProcessTrip(trip_num);

  /* Read ground truth + accel + gyro */
  proc import datafile="&curiosity_path./data/&trip_num._groundTruth.csv"
    out=work.gt_&trip_num._raw dbms=csv replace;
    getnames=yes;
  run;

  proc import datafile="&curiosity_path./data/&trip_num._acelerometro_terra.csv"
    out=work.acc_&trip_num._raw dbms=csv replace;
    getnames=yes;
  run;

  proc import datafile="&curiosity_path./data/&trip_num._giroscopio_terra.csv"
    out=work.gyr_&trip_num._raw dbms=csv replace;
    getnames=yes;
  run;

  /* Standardize GT times + map event labels */
  data work.gt_&trip_num.;
    set work.gt_&trip_num._raw;

    length start_sec end_sec 8;
    if not missing(_inicio) then start_sec=_inicio;
    else if not missing(inicio) then start_sec=_inicio;

    if not missing(_fim) then end_sec=_fim;
    else if not missing(fim) then end_sec=fim;

    length event_type $35 evento_clean $60;
    evento_clean = lowcase(strip(evento));

    if evento_clean = 'evento_nao_agressivo' then do;
      event_type='Non-Aggressive Event'; event_classifier=0;
    end;
    else if evento_clean = 'curva_direita_agressiva' then do;
      event_type='Aggressive Right Turn'; event_classifier=1;
    end;
    else if evento_clean = 'curva_esquerda_agressiva' then do;
      event_type='Aggressive Left Turn'; event_classifier=2;
    end;
    else if evento_clean = 'freada_agressiva' then do;
      event_type='Aggressive Braking'; event_classifier=3;
    end;
    else if evento_clean = 'troca_faixa_direita_agressiva' then do;
      event_type='Aggressive Right Lane Change'; event_classifier=4;
    end;
    else if evento_clean = 'troca_faixa_esquerda_agressiva' then do;
      event_type='Aggressive Left Lane Change'; event_classifier=5;
    end;
    else if evento_clean in ('aceleracao_agressiva','aceleracao','aceleracao_agressivo','aceleracao_agressiva ') then do;
      event_type='Aggressive Acceleration'; event_classifier=6;
    end;
    else do;
      event_type=cats('UNMAPPED: ',evento_clean);
      event_classifier=99;
    end;

    is_aggressive = (event_classifier in (1,2,3,4,5,6));
    trip_id = &trip_num.;

    keep trip_id start_sec end_sec event_type event_classifier is_aggressive evento_clean;
  run;

  /* Sort by timestamp for merge */
  proc sort data=work.acc_&trip_num._raw out=work.acc_&trip_num.;
    by timestamp;
  run;

  proc sort data=work.gyr_&trip_num._raw out=work.gyr_&trip_num.;
    by timestamp;
  run;

  /* Merge accel+gyro and compute seconds_from_start */
  data work.sensors_&trip_num.;
    merge
      work.acc_&trip_num.(rename=(x=accel_x y=accel_y z=accel_z uptimeNanos=uptimeNanos_acc))
      work.gyr_&trip_num.(rename=(x=gyro_x  y=gyro_y  z=gyro_z  uptimeNanos=uptimeNanos_gyr));
    by timestamp;

    if not missing(uptimeNanos_acc) then uptimeNanos=uptimeNanos_acc;
    else uptimeNanos=uptimeNanos_gyr;

    retain trip_start_nanos;
    if _n_=1 then trip_start_nanos = uptimeNanos;

    seconds_from_start = (uptimeNanos - trip_start_nanos) / 1e9;
    format seconds_from_start 10.4;

    keep timestamp seconds_from_start accel_x accel_y accel_z gyro_x gyro_y gyro_z;
  run;

  /* Label sensor rows using GT intervals */
  proc sql;
    create table work.events_&trip_num. as
    select
      g.trip_id,
      cats('T',g.trip_id,'_C',g.event_classifier,'_S',put(g.start_sec,best.),'_E',put(g.end_sec,best.)) as event_id length=60,
      g.event_classifier,
      g.event_type,
      g.is_aggressive,
      s.seconds_from_start,
      s.accel_x, s.accel_y, s.accel_z,
      s.gyro_x,  s.gyro_y,  s.gyro_z
    from work.sensors_&trip_num. s
    inner join work.gt_&trip_num. g
      on s.seconds_from_start between g.start_sec and g.end_sec
    where g.event_classifier ne 99
    order by event_id, seconds_from_start;
  quit;

%mend;

/* Trips 1–4 -> master dataset */
%ProcessTrip(1);
%ProcessTrip(2);
%ProcessTrip(3);
%ProcessTrip(4);

data work.master_event_data;
  set work.events_1 work.events_2 work.events_3 work.events_4;
run;
