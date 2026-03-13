#!/bin/sh
date
/usr/bin/time -v r.sim.water -t elevation=leasburg_dem_3m_mod dx=leasburg_dx_mod dy=leasburg_dy_mod rain_value=23 man=leasburg_n_post depth=leasburg_depth_2y1h_mod discharge=leasburg_q_2y1h_mod niterations=60 output_step=10 nwalker=10000000 nprocs=4 --o&

/usr/bin/time -v r.sim.water -t elevation=leasburg_dem_3m dx=leasburg_dx dy=leasburg_dy rain_value=23 man=n_low_leasburg depth=leasburg_depth_2y1h discharge=leasburg_q_2y1h niterations=60 output_step=10 nwalker=10000000 nprocs=4 --o&

/usr/bin/time -v r.sim.water -t elevation=leasburg_dem_3m_mod dx=leasburg_dx_mod dy=leasburg_dy_mod rain_value=5 man=leasburg_n_post depth=leasburg_depth_500y24h_mod discharge=leasburg_q_500y24h_mod niterations=1440 output_step=60 nwalker=10000000 nprocs=4 --o&

/usr/bin/time -v r.sim.water -t elevation=leasburg_dem_3m dx=leasburg_dx dy=leasburg_dy rain_value=5 man=n_low_leasburg depth=leasburg_depth_500y24h discharge=leasburg_q_500y24h niterations=1440 output_step=60 nwalker=10000000 nprocs=4 --o&

date
