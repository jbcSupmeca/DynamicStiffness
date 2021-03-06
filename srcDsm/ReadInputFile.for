************************************************************************
* This file is part of DynamicSiffness, a Fortran library that         * 
* implements the Dynamic Stiffness Method                              *
* Copyright (C) 2021 BEVANCON Tanguy,                                  *
* Quartz Laboratory - Supmeca                                          *
* 3 rue Ferand Hainaut                                                 *
* 93407 SAINT-OUEN - FRANCE                                            *
* tanguy.bevancon@supmeca.fr                                           *
*                                                                      *
* This program is free software: you can redistribute it and/or modify *
* it under the terms of the GNU General Public License as published by *
* the Free Software Foundation, either version 3 of the License, or    *
* (at your option) any later version.                                  *
*                                                                      *
* This program is distributed in the hope that it will be useful,      *
* but WITHOUT ANY WARRANTY; without even the implied warranty of       *
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        *
* GNU General Public License for more details.                         *
*                                                                      *
* You should have received a copy of the GNU General Public License    *
* along with this program.  If not, see <http://www.gnu.org/licenses/>.*
************************************************************************

************************************************************************
*     This subroutine reads input files built from abaqus that describe*
*     a 2D beam frame                                                  *
*     The file is a text file as described below                       *
*                                                                      *
*Heading
** Job name: TestInput Model name: Model-1
** Generated by: Abaqus/CAE 2019
*Preprint, echo=NO, model=NO, history=NO, contact=NO
**
** PARTS
**
*Part, name=Part-1
*End Part
**  
**
** ASSEMBLY
**
*Assembly, name=Assembly
**  
*Instance, name=Part-1-1, part=Part-1
*Node
*      1,          XN1,           YN1
*      2,          XN2,           YN2
*      3,          XN3,           YN3
*        ...
*Element, type=TI
*1, N11, N12
*2, N21, N22
*   ...
*Nset, nset=Set-1
* 1, 2
*Elset, elset=Set-1
* 1,                                             
** Section: Section-1  Profile: Profile-1
*Beam Section, elset=Set-1, material=Mat1, temperature=GRADIENTS, section=RECT
*L1, L2
*X,Y,Z
*Transverse Shear
*KY, KY, 
** MATERIALS
** 
*Material, name=Mat1
*Density
*R1,
*Elastic
* E1, NU1
*Material, name=Mat2
*Density
*R2,
*Elastic
* E2, NU2
*                                                                      *      
*     Where :                                                          *
*     ST : Type of structure (ONLY 2DFRAME)                            *
*     NN : Number of nodes                                             *
*     XNI,YNI : Coordinates of node I                                  *
*     NE : Number of elements                                          *
*     N1I,N2I : Node 1 and Node 2 of element I                         *
*     MI : Constitutive material of element I                          *
*     SI : Section of element I                                        *
*     TI : Type of element I (B23 =Bernoulli, B21 =Timoshenko)         *
*     NM : Number of materials                                         *
*     RI : Mass density of material I                                  *
*     EI : Young modulus of material I                                 *
*     DI : Damping (loss angle) of material I                          *
*     NU : Poisson's Ratio                                             *
*     NS : Number of sections                                          *
*     LI1,LI2 : Length sides of Area of section I                      *
*     IZI : Quadratic moment of inertia of section I                   *
*     KY : Timoshenko's Section Reduction                              *
*                                                                      *
*     Input Args :                                                     * 
*          FILENAME : The data filename                                *
*          NMAX : The leading dimension of array NODES                 *
*          EMAX : The leading dimension of array ELEMS                 *
*          MMAX : The leading dimension of array MATES                 *      
*          SMAX : The leading dimension of array SECTS                 *
*                                                                      *
*     Output Args :                                                    *
*          CAT :  Category of problem (ONLY 2DFRAME)                   *
*          NODES : Coordinates of nodes (XI,YI)                        *      
*          NN : number of nodes                                        *
*          ELEMS : Elements' table (N1I,N2I,SI,MI,TI)                  *
*          NE : number of elements                                     *
*          MATES : Materials' table (RI,EI,NU,DI)                      *
*          NM : number of materials                                    *
*          SECTS : Sections' table (SI,IZI,KY)                         *
*          NS : number of sections                                     *
************************************************************************ 

      SUBROUTINE READINPUTFILE(FILENAME,NMAX,EMAX,MMAX,SMAX,CAT,NODES,NN
     1                        ,ELEMS,NE,MATES,COUNTMAT,SECTS,COUNTSECT)
      IMPLICIT NONE
      
      INTEGER NMAX,EMAX,SMAX,MMAX
      CHARACTER (7) CAT
      DOUBLE PRECISION NODES(NMAX,*)
      INTEGER ELEMS(EMAX,*)
      DOUBLE PRECISION MATES(MMAX,*)
      DOUBLE PRECISION SECTS(SMAX,*)
      
* Local variables                                                      *
      CHARACTER(80) LIGNE, MOT
      INTEGER INDEX1,INDEX2,INDEX3,INDEXSECT
      CHARACTER(20) TAB(10,5),MATSECT(10,1)
      INTEGER I,J,K,N,O,X
      CHARACTER L,M
      CHARACTER(20) TESTSET
      INTEGER METHOD
      DOUBLE PRECISION PI,L1,L2,S1,IZ,KY
      DOUBLE PRECISION DENSITY1,E1,NU1
      INTEGER COUNTSECT,COUNTMAT
      
      INTEGER NN,NE
      
      CHARACTER*80 FILENAME
      
* For the moment, we consider only 2D frame                            *
      CAT = '2DFRAME'
      
*   We read in a first step the file in order to count the number of   *
*   nodes, elements, sections, materials and other parameters.         *
      
* Opening the datafile and reading until we reach the nodes            *
      OPEN(80,FILE=FILENAME)
      
      I=0
      
      DO WHILE (LIGNE.NE.'*Node')
          READ(80,*)LIGNE
          I=I+1
      ENDDO
      
*   Counting the number of nodes and stacking the value while also     *
*   reading the type of method used                                    *

      K=0
      DO WHILE(LIGNE.NE.'*Element')
      
          READ(80,*) LIGNE,MOT
          IF (MOT.EQ.'type=B23') THEN
              METHOD=1
          ELSEIF (MOT.EQ.'type=B21') THEN
              METHOD=3
          ENDIF
          K=K+1
      ENDDO
      
      NN=K-1

*   Counting the number of elements                                    *
      K=0
      DO WHILE (LIGNE.NE.'*Nset')
          READ(80,*) LIGNE
          K=K+1
      ENDDO
      NE=K-1
      
*   Counting the number of sections and stacking its parameters        *
*   (area, quadratic moment and Timoshenko's section reduction)        *
      X=1
      COUNTSECT=0
      
      DO WHILE (LIGNE.NE.'*End Instance')
          READ(80,"(a)") LIGNE
          INDEX1 = INDEX( LIGNE , "Section:" )
          IF (INDEX1.NE.0) THEN
*   The line countain several informations, we only need the third, the*
*   fourth and the sixth one which corresponds respectively to the     *
*   set selected for the section, the material and the type of section.*
*   We still have to read the other in order to have the ones we want  *
              READ(80,*) TAB(X,1),TAB(X,2),TAB(X,3),TAB(X,4),M,TAB(X,5)
              TAB(X,4) = TAB(X,4)(10:LEN_TRIM(TAB(X,4)))
*   We calculate the area and the quadratic moment                     *
              IF (M.EQ.'section=GENERAL') THEN
                    READ(80,*) S1,IZ
                    SECTS(X,1)=S1
                    SECTS(X,2)=IZ
              ELSEIF (TAB(X,5).EQ.'section=RECT') THEN
                    READ(80,*) L1,L2
                    S1=L1*L2
                    IZ=(L1**3*L2)/12
                    SECTS(X,1)=S1
                    SECTS(X,2)=IZ
              ELSEIF (TAB(X,5).EQ.'section=CIRC') THEN
                    READ(80,*) L1
*                   Defining Pi                                        *
                    PI = 4.D0*DATAN(1.D0)
                    S1 = PI*L1**2
                    IZ = (PI*(2*L1)**4)/64
                    SECTS(X,1)=S1
                    SECTS(X,2)=IZ
              ENDIF
              X=X+1
              COUNTSECT=COUNTSECT+1
          ENDIF
          
*   We read the Timoshenko's ratio only if it's needed                 *
          IF (METHOD.EQ.3) THEN
              IF (LIGNE.EQ.'*Transverse Shear') THEN
                  READ(80,*) KY
                  DO J=1, NE
                      SECTS(J,3)=KY
                  ENDDO
              ENDIF
          ENDIF
      ENDDO
      
      
*   Counting the number of materials                                   *
      COUNTMAT=0
      
      DO WHILE(LIGNE.NE.'** STEP: Step-1')
          READ(80,"(a)") LIGNE
          INDEX2 = INDEX( LIGNE , "*Material" )
          IF (INDEX2.NE.0) THEN
              MATSECT(COUNTMAT+1,1) = LIGNE(17:LEN_TRIM(LIGNE))
              COUNTMAT=COUNTMAT+1
          ENDIF
      ENDDO
      
      
      
* Read the file since the beginning                                    *
      REWIND(80)



* Skipping the lines we don't need                                     *      
      DO J=1, I
          READ(80,*)
      ENDDO
      
* Seeking and reading NN nodes                                         *
      DO I=1, NN
      
          READ(80,*) L,NODES(I,1),NODES(I,2)
      ENDDO
      
      
* Seeking and reading NE Elements                                      *
      DO WHILE(LIGNE.NE.'*Element')
      
          READ(80,*) LIGNE
      ENDDO
      
      DO I=1, NE
      
          READ(80,*) L,ELEMS(I,1),ELEMS(I,2)
* Write the method in the element's array                              *
          ELEMS(I,5) = METHOD
      ENDDO
      
* Build the column which corresponds to the sections                   *
      K = 1
      DO WHILE(K.LE.COUNTSECT)
            READ(80,*) LIGNE,TESTSET
            DO I=1, COUNTSECT
                IF (TESTSET.EQ.TAB(I,3)) THEN
                      READ(80,"(a)") LIGNE
*  For this part, because we don't know yet the lentgh of the line     *
*  which contains the elements, we will divide the ligne each time we  *
*  came across a coma.                                                 *
*  To run the good elements, we create two loops, one for the extreme  *
*  left value and another for the right one                            *
                      N=1
                      X=1
                      O=LEN_TRIM(LIGNE)
*   We do the action until we reach the end of the line                *                      
                      DO WHILE(X.LE.O+1)
*                    We detect if there is a coma at the exact location*
                            J=INDEX(LIGNE(X:X),',')
                            IF (J.EQ.0) THEN
*                           In the case we are at the end of the line  *
                                    IF (X.EQ.O) THEN
                                          READ(LIGNE(N:X),'(i3)')
     1                                    INDEXSECT
                                          ELEMS(INDEXSECT,4)=I
                                    ENDIF
                                    X=X+1
                            ELSE
                                    READ(LIGNE(N:X-1),'(i3)') INDEXSECT
                                    ELEMS(INDEXSECT,4)=I
                                    X=X+1
                                    N=X
                            ENDIF
*   The length of the line in the abaqus file is limited to 64 columns,*
*   after that, the section are defined on the next line               *
                            IF (X.EQ.64) THEN
                                READ(80,"(a)") LIGNE
                                        N=1
                                        X=1
                                        O=LEN_TRIM(LIGNE)
                            ENDIF
                      ENDDO
                      K=K+1
                ENDIF
            ENDDO
      ENDDO
      
* Build the column which corresponds to the materials in elements      *

      DO K=1, NE
            I = ELEMS(K,4)
            DO J=1, COUNTMAT
                  IF (TAB(I,4).EQ.MATSECT(J,1)) THEN
                      ELEMS(K,3)=J
                  ENDIF
            ENDDO
      ENDDO
      
* Seeking and reading NM Materials                                     *
      I=0
      
      DO WHILE (I.NE.COUNTMAT)
          READ(80,"(a)") LIGNE
          INDEX3 = INDEX( LIGNE , "*Material" )
          IF (INDEX3.NE.0) THEN
              READ(80,*)
              READ(80,*) DENSITY1
              READ(80,*)
              READ(80,*)E1,NU1
              MATES(I+1,1)=DENSITY1
              MATES(I+1,2)=E1
              MATES(I+1,3)=0
              MATES(I+1,4)=NU1
              I=I+1
          ENDIF
      ENDDO
      
      
      CLOSE(80)
      
      END
