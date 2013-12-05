	SUBROUTINE IM_DPNIDH  ( imgfil, ihdr, iret )
C************************************************************************
C* IM_DPNIDH								*
C*									*
C* This subroutine parses the header information from a raw dual        *
C* polarization NIDS file and sets the navigation.			*
C*									*
C* IM_DPNIDH  ( IMGFIL, IHDR, IRET )					*
C*									*
C* Input parameters:							*
C*	IMGFIL		CHAR		Image file name			*
C*	IHDR (39)	INTEGER		HR NIDS header information	*
C*									*
C* Output parameters:							*
C*	IRET		INTEGER		Return code			*
C*					  0 = normal return		*
C*					 -4 = Invalid image product	*
C*					 -5 = Invalid image navigation	*
C**									*
C* Log:									*
C* M. James/Unidata           09/11   Modified from IM_HRNIDH           *
C************************************************************************
	INCLUDE		'GEMPRM.PRM'
	INCLUDE		'IMGDEF.CMN'
	INCLUDE		'AREAFL.CMN'
C*
	CHARACTER*(*)	imgfil
	INTEGER 	ihdr (39)
C*
	BYTE     	ibarr (36)
	INTEGER		idtarr (3), idlvls (16), dhci
	INTEGER*2	iarr2 (78), ivtim2 (2),  ibzsiz2 (2)
	INTEGER*4	inhead (39), ivtim4, ibzsiz4, bzarr(9)
        REAL*4          fphead (39), amin, ainc, val
	CHARACTER       prdnam*8, units*8, desc*20, dhc(16)*4
        DATA            dhc  / 'ND', 'BI', 'GC', 'IC',
     +                         'DS', 'WS', 'RA', 'HR',
     +                         'BD', 'GR', 'HA', '',
     +                         '', '', 'UK', 'RF' /

C*
        EQUIVALENCE     (inhead, iarr2)
	EQUIVALENCE	(ivtim4, ivtim2)
	EQUIVALENCE	(ibzsiz4, ibzsiz2)
	EQUIVALENCE	(bzarr, ibarr)
C------------------------------------------------------------------------
	iret = 0
C
C*	Get the header array into the local array variable.
C
        DO  i = 1, 39
            inhead (i) = ihdr (i)
        END DO
C
C*      Determine whether file needs bytes flipped. If so, swap and save
C*      the four byte data values before flipping each two-byte pair.
C*      The time variable crosses a word boundary, so treat it specially.
C
        IF ( (iarr2 (1) .gt. 255) .or. (iarr2 (1) .lt. 0) ) THEN
            CALL MV_SWP4 ( 1, inhead (3), imlenf )
            CALL MV_SWP4 ( 1, inhead (6), iradlt )
            CALL MV_SWP4 ( 1, inhead (7), iradln )
            CALL MV_SWP4 ( 1, inhead (28), isymof )
            CALL MV_SWP4 ( 1, inhead (29), igrfof )
            CALL MV_SWP4 ( 1, inhead (30), itabof )
            CALL MV_SWP4 ( 1, inhead (34), idllen )
            CALL MV_SWP4 ( 39, inhead, fphead )
            CALL MV_SWP2 ( 39, inhead, inhead )
            ivtim2 (1) = iarr2 (23)
            ivtim2 (2) = iarr2 (22)
            ivtime = ivtim4
            ibzsiz2 (1) = iarr2 (53)
            ibzsiz2 (2) = iarr2 (52)
            ibzsiz = ibzsiz4
            imbswp = 1
        ELSE
            iradlt = inhead (6)
            iradln = inhead (7)
            isymof = inhead (28)
            idllen = inhead (34)
            ivtim2 (1) = iarr2 (22)
            ivtim2 (2) = iarr2 (23)
            ivtime = ivtim4
            imbswp = 0
        END IF
C
C*      Fill 2-byte variables
C
        iprod  = iarr2 (16)
	immode = iarr2 (17)
C
C*      If equal 0 (maintenance mode), do not need to process
C
        IF ( immode .eq. 0 ) THEN 
            iret = -4
            RETURN
        END IF
        ivdate = iarr2 (21)
        ipd3   = iarr2 (30)
        ipd8   = iarr2 (51)

        IF ( ipd8 .eq. 1 ) THEN
           nbret = 36
           CALL IM_BZSEC ( imgfil, ibzsiz, imprsz, isymof, ibarr,
     +       nbret, ier)
           IF ( ier .eq. 0 ) THEN
              DO i=1,9
                 inhead(30+i) = bzarr(i)
              END DO
              IF ( imbswp .eq. 1 ) THEN
                  CALL MV_SWP4 ( 1, inhead (34), idllen )
                  CALL MV_SWP2 ( 9, inhead(31), inhead(31) )
              ELSE
                  idllen = inhead(34)
              END IF
           END IF
        END IF
       
        SELECT CASE (iprod)
           CASE (170, 172, 173, 174, 175) 
              idlvls (1) = 100 * fphead (16)
              idlvls (2) = 100 * fphead (17)
              idlvls (3) = iarr2 (36)
           CASE DEFAULT
              idlvls (1) = fphead (16)
              idlvls (2) = fphead (17)
              idlvls (3) = iarr2 (36)
        END SELECT 
C
        ipkcd1 = iarr2 (69)
C
C*	Radial product-specific variables
C
	nrbins = iarr2 (71) 
C
        imnpix = nrbins * 2
        imnlin = imnpix
        imrdfl = -1
        imdoff = isymof * 2
        imldat = idllen
C        imldat = idllen - 14
C
C*	Set product info
C
	imsorc = 7
	imdpth = 1
	imtype = iprod
	isrc   = iarr2 (7)
	CALL TB_NIDS  ( isrc, imtype, prdnam, nlev, units, res, desc,
     +			ierr )
	IF  ( ierr .ne. 0 )  THEN
	    CALL ER_WMSG ( 'TB', ierr, ' ', ier )
	    iret = -4
	    RETURN
	END IF
	CALL ST_RNUL(prdnam, prdnam, lens, ier )
	CALL ST_RNUL(units, units, lens, ier )
	CALL ST_RNUL(desc, desc, lens, ier )
C
C*	Set image calibration (units)
C
	cmcalb = 'RAW '
C
C*	Save radar beam elevation angle for base products
C
	IF ( ( iprod .ge. 159 ) .and. ( iprod .le. 177) ) THEN 
	    rmbelv = ipd3 * 0.1
	ELSE
	    rmbelv = RMISSD
	END IF
C
C*	Determine date. Date stored with the raw data is the number of
C*	days from 1/1/70. Put it into YYYYMMDD form.
C
	nyear = (ivdate - 1 + .5) / 365.25	    
	jyear = 1970 + nyear
	jday  = ivdate - INT (nyear * 365.25 + .25)
	CALL TI_JTOI ( jyear, jday, idtarr, ier )
	imdate =  idtarr (1) * 10000 + idtarr (2) * 100 + idtarr (3)
C
C*	Time stored is number of seconds past UTC midnight. Put it into
C*	HHMMSS form. Use volume scan time.
C
	imtime = (10000 * (ivtime / 3600)) + (100 * MOD (ivtime/60,60)) 
     +		 + MOD (ivtime,60)
C	 
C*	Build data level values
C
	imndlv = nlev
	cmbunt = units
C
	IF ( ( iprod .ge. 159 ) .and. ( iprod .le. 177) ) THEN
           SELECT CASE (iprod)
              CASE (170, 172, 173)
                 amin = ( 1 - real( idlvls (2)) / 10. )
     +		 / ( real( idlvls (1)) / 10. )
	         ainc = 1 / ( real( idlvls (1)) / 10. )
              CASE (174, 175)
                 amin = ( 1 - real( idlvls (2)) / 100. )
     +		 / ( real( idlvls (1)) / 100. )
	         ainc = 1 / ( real( idlvls (1)) / 100. )
              CASE DEFAULT  
	         amin = ( 1 - real( idlvls (2) )  ) 
     +		 / real( idlvls (1) )   
	         ainc = 1 / real( idlvls (1) )  
           END SELECT
	ELSE
	   amin = idlvls ( 1 ) / 10.
	   ainc = idlvls ( 2 ) / 10.
	END IF
	imndlv = idlvls ( 3 )
        iinc = imndlv / 8 

        SELECT CASE (iprod)
C
C* 159 - Digital Differential Reflectivity
C
           CASE (159)
              iinc = imndlv / 16
	      DO idl = 1, imndlv
                 val = amin + ( idl - 1 ) * ainc
                 IF ( idl .eq. 1 ) THEN
                    cmblev ( idl ) = 'ND' 
                 ELSE IF ( MOD ( val, 1. ) .eq. 0 ) THEN 
                    CALL ST_RLCH ( val, 1, cmblev ( idl ), ier )
                 ELSE
                    cmblev ( idl ) = ' '
                 END IF
	      END DO
              cmblev ( imndlv ) = 'RF'
C
C* 161 - Digital Correlation Coefficient
C
           CASE (161)
              DO idl = 1, imndlv
                 val = amin + ( idl - 1 ) * ainc
                 IF ( idl .eq. 1 ) THEN
                    cmblev ( idl ) = 'ND'
                 ELSE IF ( MOD ( ( idl - 1 ), iinc ) .eq. 0 ) THEN 
                    CALL ST_RLCH ( val, 1, cmblev ( idl ), ier )
                 ELSE
                    cmblev ( idl ) = ' '
                 END IF
              END DO
              cmblev ( imndlv ) = 'RF'
C
C* 163 - Digital Specific Differential Phase
C
           CASE (163)
              iinc =  10 
              DO idl = 1, imndlv
                 val = amin + ( idl - 1 ) * ainc
                 IF ( idl .eq. 1 ) THEN
                    cmblev ( idl ) = 'ND'
                 ELSE IF ( ( MOD ( ( idl - 2 ), iinc ) .eq. 0 ) .and. 
     +                     ( val .ge. -2.0 ) .and.
     +                     ( val .le. 9.5 ) ) THEN
                    CALL ST_RLCH ( val, 1, cmblev ( idl ), ier )
                 ELSE
                    cmblev ( idl ) = ' '
                 END IF
              END DO
              cmblev ( imndlv ) = 'RF'
C
C* 165 - Digital Hydrometeor Classification
C* 177 - Hybrid Hydrometeor Classification
C 
           CASE (165, 177)
              DO idl = 1, imndlv
                 cmblev ( idl ) = ''
              END DO 
              dhci = 1 
              DO idl = 1, imndlv, 17 
                 cmblev ( idl ) = dhc ( dhci )
                 dhci = dhci + 1
              END DO
C       now fill last with RF
              cmblev ( imndlv ) = 'RF'
C
C* 170 - Digital Accumulation Array
C* 172 - Digital Storm Total Accumulation
C* 173 - Digital User-Selectable Accumulation
C
           CASE (170, 172, 173)
              DO idl = 1, imndlv
                 val = ( amin + ( idl - 1 ) * ainc ) / 10
                 IF ( idl .eq. 1 ) THEN
                    cmblev ( idl ) = 'ND'
                 ELSE IF ( MOD ( ( idl - 1 ), iinc ) .eq. 0 ) THEN
                    CALL ST_RLCH ( val, 1, cmblev ( idl ), ier )
                 ELSE
                    cmblev ( idl ) = ' '
                 END IF
              END DO
C 
C* 174 - Digital One-Hour Difference Accumulation
C* 175 - Digital Storm Total Difference Accumulation
C* Physical Units: 0.01 inches, requiring scaling by 100
C* for display in inches 
C        
           CASE (174, 175)
              iinc = 11
              DO idl = 1,imndlv 
                 val = ( amin + ( idl - 1 ) * ainc ) / 100. 
                 IF ( MOD ( ( idl - 1 ), iinc ) .eq. 0 ) THEN
                    CALL ST_RLCH ( val, 1, cmblev ( idl ), ier )
                 ELSE
                    cmblev ( idl ) = ' '
                 END IF
              END DO
        END SELECT
C
C*	Set image subset bound to whole image right now.
C
	imleft = 1
	imtop  = 1
	imrght = imnpix
	imbot  = imnlin
C
	iadir (6)  = 1
	iadir (7)  = 1
	iadir (12) = 1
	iadir (13) = 1
	    
	CALL ST_CTOI ( 'RADR', 1, ianav (1), ier )
	ianav (2)  = imnlin / 2
	ianav (3)  = imnpix / 2
C
C*	Convert floating point lat/lon to DDDMMSS format
C
	deg = ABS ( iradlt * .001)
	ideg = INT ( deg * 100000 )
	idec = MOD ( ideg, 100000 )
	irem = (idec * 3600 + 50000 ) / 100000
 	
	idms = ( ideg / 100000 + irem / 3600 ) * 10000 +
     +	         MOD (irem, 3600) / 60 * 100 + MOD (irem, 60)
	IF ( iradlt .lt. 0 ) idms = -idms
	ianav (4)  = idms

	deg = ABS ( iradln * .001)
	ideg = INT ( deg * 100000 )
	idec = MOD ( ideg, 100000 )
	irem = (idec * 3600 + 50000 ) / 100000
 	
	idms = ( ideg / 100000 + irem / 3600 ) * 10000 +
     +		MOD (irem, 3600) / 60 * 100 + MOD (irem, 60)
C
C*	Set west lon (neg) to match MCIDAS west lon (pos)
C
	IF ( iradln .gt. 0 ) idms = -idms
	ianav (5)  = idms

	ianav (6)  = res * 1000
	ianav (7)  = 0
	ianav (8)  = 0

	CALL GSATMG ( imgfil, iadir, ianav, imleft, imtop, imrght,
     +			  imbot, ier )
C
	IF ( ier .ne. 0 ) iret = -5
C
	RETURN
	END
