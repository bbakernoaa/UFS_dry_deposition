subroutine Vd_Gas_Wesely(ilu,istress,iwet,iso2,io3,z0,deltaz,psih,ustar,diffrat,henry,henso2,f0,rscale,ts,dstress,  &
                         solflux,ri,rlu,rac,rlcs,rlco,rgss,rgso,icdocn,vd)

!developed by Dr.Beiming Tang based on CAMx code
!NOAA ARL UFS project
!05/01/2023

!Modifications:

!Input arguments:
!    ilu        land use index                                               (unit = 1)
!               urban =1, agricultural =2, range =3, deciduous forest =4
!               coniferous forest =5, mixed forest include wetland =6
!               water = 7, barren land mostly dessert = 8, nonforest wetland = 9
!               mixed agricultural and range land = 10, 
!               rocky open area with low-growing shrubs = 11
!  
!    istress    vegetation drout stress index                                (unit = 1)
!    iwet       surface wetness index, 0=dry, 1=dew wetted, 2=rain wetted    (unit = 1)
!    iso2       SO2 species flag (1=SO2,0=other)                             (unit = 1)
!    io3        O3 species flag (1=O3,0=other)                               (unit = 1)
!    z0         surface roughness lenth                                      (unit = m)
!    deltaz     Layer 1 midpoint height(where the Vd is evaluated)           (unit = m)
!    psih       similarity stability correction term                         (unit = 1)
!    ustar      friction velocity                                            (unit = m/s)
!    diffrat    ratio of molecular diffusivity of water to species           (unit = 1)
!    henry      Henry's Law constant                                         (unit = M/atm)
!    henso2     Henry's Law constant for SO2                                 (unit = M/atm)
!    f0         normalized reactivity parameter                              (unit = 1)
!    rscale     user-defined surface resistance scalling factor              (unit = 1)
!    ts         surface temperature                                          (unit = C NOT K)
!    dstress    adjustment factors for drought stress                        (unit = matrix)
!    solflux    Solar radiation flux                                         (unit = W/m^2)
!    ri         baseline minimum stomatal resistance                         (unit = s/m)
!    rlu        baseline upper canopy (cuticle) resistance                   (unit = s/m)
!    rac        baseline canopy height/density resistance                    (unit = s/m)
!    rlcs       baseline SO2 lower canopy resistance                         (unit = s/m)
!    rlco       baseline O3 lower canopy resistance                          (unit = s/m)
!    rgss       baseline SO2 ground surface resistance                       (unit = s/m)
!    rgso       baseline O3 ground surface resistance                        (unit = s/m)
!    icdocn     flag indicating an over-ocean cell                           (unit = 1)

!Output arguments:
!    vd         deposition velocity                                          (unit = m/s)

!Routines called:
!    none

!Called by:
!    should be part of dry deposition code

!Step 0. Define variables type & constant values
    integer :: ilu
    integer :: istress
    integer :: iwet
    integer :: iso2
    integer :: io3
    real    :: z0
    real    :: deltaz
    real    :: psih
    real    :: ustar
    real    :: diffrat
    real    :: henry
    real    :: henso2
    real    :: f0
    real    :: rscale
    real    :: ts
    real    :: dstress(0:5)
    real*8  :: solflux
    real    :: ri
    real    :: rlu
    real    :: rac
    real    :: rlcs
    real    :: rlco
    real    :: rgss
    real    :: rgso
    integer :: icdocn
    real    :: vd
 
    real    :: vk = 0.4                             !karman constant
    real    :: rmin = 1.0, rmax = 1.e5
    real    :: d1 = 2., d2 = 0.667                  !0.667 = 2/3
    real    :: vair = 1.5e-5, diffh2o = 2.3e-5

!
!Main program start
!

!Step 1. Calculate atmospheric resistance (due to turbulence diffusion), Ra
    ra = (log(deltaz/z0)-psih)/(vk * ustar)
    ra = amax1(ra,rmin)

!Step 2. Calulate deposition layer resistance (due to molecular diffusion), Rd
    schmidt = vair * diffrat/diffh2o
    rd = d1 * schmidt**d2/(vk * ustar)
    rd = amax1(rd,rmin)

!Step 3. Calculate surface layer resistance, Rs
!!Step 3-1. special case surface layer over water
    if (ilu == 7) then
        if (io3 == 1 .and. icdocn == 1) then
            rs = 1./(1.e-4 + 5.e-6 * henry *ustar * ts **3)                                   !Follow Helmig et al (2012)
            rs = amax1(rs,1500.)
        else
            rs = 1./ (3.9e-5*henry*ustar*(ts+273.14))                                         !Follow Kumar et al (1996) and Sehmel (1980)
            rs = amax1(rs,rmin)
        endif
        goto 100
    endif 

!!Step 3-2. normal case, surface layer over land 
!!!Step 3-2-1.stomatal and mesophyll resistance,Rst & Rm
    rst = rmax
    if (ts>0 .and. ts<40) then
        rst = diffrat*ri*(1.+(200./(solflux + 0.1))**2)*(400./(ts*(40.-ts)))                  !Follow Wesely et al.,(1989) eqn (3)&(4)   
        rst = rst * dstress(istress)
    endif
    
    if (iwet >0) then
        rst = 3.* rst                                                                         !Effect of dew and rain,increased by a factor of 3, as leafs are covered
    endif
    
    rst = amin1(rmax,rst)

    rm = 1./(henry/3000.+100.*f0)                                                             !Follow Wesely et al., (1989) eqn (6)
    rm = amax1(rmin,rm)
    rm = amin1(rmax,rm)

!!!Step 3-2-2.upper canopy resistance,Ruc
    if (iwet == 0) then                     !dry surface
        ruc = rlu/(henry/henso2+f0)
        ruc = amin1(rmax,ruc)
    else
        if (iwet == 1) then                 !dew surface
            rlus = 100.
            if (ilu == 1) then
                rlus = 50.
            endif
!            rluo = 1./(1./3000.+1./(3.*rlu))                                                   !Follow Wesely et al.,(1989) eqn (11)
            rluo = 1000 + rlu
        else                                !rain surface
!            rlus = 1./(1./5000. + 1./(3.*rlu))                                                 !Follow Wesely et al.,(1989) eqn (12)
            rlus = 2000.+rlu
            if (ilu == 1.) then
                rlus = 50.
            endif
            rluo = 1./(1./1000. + 1./(3.*rlu))                                                 !Follow Wesely et al.,(1989) eqn (13)
        endif
        
        if (iso2 == 1) then
            ruc = rlus
        elseif (io3 == 1) then
            ruc = rluo
        else
!            ruc = 1./(1./(3.*rlu) + 1.e-7*henry + f0/rluo)                                     !Follow Wesely et al.,(1989) eqn (14)
            ruc = 1./(henry/(henso2*rlus) + f0/rluo)
        endif
    endif

!!!Step 3-2-3.buyant convection and lower canopy resistance, Rdc & Rlc
    rdc = 100.*(1. +1000./(solflux +10.))                  !Follow Wesely (1989) eqn (5),but set terrain slope factor to be 1. 
    rdc = amin1(rmax, rdd)

    rlc = 1./(henry/(henso2*rlcs)+f0/rlco)                 !Follow Wesely et al. (1989) eqn (8)
    rlc = amin1(rmax,rlc)

!!!Step 3-2-4.ground surface resistance, Rgs
!!!Rac was read-in ???
    rgs = 1./(henry/(henso2*rgss) * f0/rgso)               !Follow Wesely et al., (1989) eqn (9)
    rgs = amin1(rmax,rgs)

!Step 4. Calculate total resistance
    rs = 1./ (rst + rm) + 1./ruc + 1./(rdc + rlc) + 1./(rac +rgs) 
    rs = amax1(rmin, 1./rs)


100 continue
    rs = rs * rscale
       
!Step 5. Calculate output deposition velocity
    vd = 1./(ra + rd + rs)

    return
    end






























