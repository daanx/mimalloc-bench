#line 95 "./null_macros/c.m4.null"

#line 1 "code.C"
/*************************************************************************/
/*                                                                       */
/*  Copyright (c) 1994 Stanford University                               */
/*                                                                       */
/*  All rights reserved.                                                 */
/*                                                                       */
/*  Permission is given to use, copy, and modify this software for any   */
/*  non-commercial purpose as long as this copyright notice is not       */
/*  removed.  All other uses, including redistribution in whole or in    */
/*  part, are forbidden without prior written permission.                */
/*                                                                       */
/*  This software is provided with absolutely no warranty and no         */
/*  support.                                                             */
/*                                                                       */
/*************************************************************************/
/*
Usage: BARNES <options> < inputfile

Command line options:

    -h : Print out input file description

    Input parameters should be placed in a file and redirected through
    standard input.  There are a total of twelve parameters, and all of 
    them have default values.

    1) infile (char*) : The name of an input file that contains particle
       data.

       The format of the file is:
         a) An int representing the number of particles in the distribution
         b) An int representing the dimensionality of the problem (3-D)
         c) A double representing the current time of the simulation
         d) Doubles representing the masses of all the particles
         e) A vector (length equal to the dimensionality) of doubles
            representing the positions of all the particles
         f) A vector (length equal to the dimensionality) of doubles
            representing the velocities of all the particles

       Each of these numbers can be separated by any amount of whitespace.
    2) nbody (int) : If no input file is specified (the first line is
       blank), this number specifies the number of particles to generate
       under a plummer model.  Default is 16384.
    3) seed (int) : The seed used by the random number generator.
       Default is 123.
    4) outfile (char*) : The name of the file that snapshots will be
       printed to. This feature has been disabled in the SPLASH release.
       Default is NULL.
    5) dtime (double) : The integration time-step.
       Default is 0.025.
    6) eps (double) : The usual potential softening
       Default is 0.05.
    7) tol (double) : The cell subdivision tolerance.
       Default is 1.0.
    8) fcells (double) : Number of cells created = fcells * number of 
       leaves.
       Default is 2.0.
    9) fleaves (double) : Number of leaves created = fleaves * nbody.
       Default is 0.5.
    10) tstop (double) : The time to stop integration.
       Default is 0.075.
    11) dtout (double) : The data-output interval.
       Default is 0.25.
    12) NPROC (int) : The number of processors.
       Default is 1.
*/

 

#define global  /* nada */

#include "code.h"
#include "defs.h"
#include <math.h>
#include <time.h>

string defv[] = {                 /* DEFAULT PARAMETER VALUES              */
    /* file names for input/output                                         */
    "in=",                        /* snapshot of initial conditions        */
    "out=",                       /* stream of output snapshots            */

    /* params, used if no input specified, to make a Plummer Model         */
    "nbody=16384",                /* number of particles to generate       */
    "seed=123",                   /* random number generator seed          */

    /* params to control N-body integration                                */
    "dtime=0.025",                /* integration time-step                 */
    "eps=0.05",                   /* usual potential softening             */
    "tol=1.0",                    /* cell subdivision tolerence            */
    "fcells=2.0",                 /* cell allocation parameter             */
    "fleaves=0.5",                 /* leaf allocation parameter             */

    "tstop=0.075",                 /* time to stop integration              */
    "dtout=0.25",                 /* data-output interval                  */

    "NPROC=1",                    /* number of processors                  */
};

void SlaveStart ();
void stepsystem (unsigned int ProcessId);
void ComputeForces ();
void Help();
FILE *fopen();

main(argc, argv)
int argc;
string argv[];
{
   unsigned ProcessId = 0;
   int c;
  printf("Run this as\n  BARNES < input \n for default values\n");
   while ((c = getopt(argc, argv, "h")) != -1) {
     switch(c) {
      case 'h': 
	Help(); 
	exit(-1); 
	break;
      default:
	fprintf(stderr, "Only valid option is \"-h\".\n");
	exit(-1);
	break;
     }
   }
   ANLinit();
   initparam(argv, defv);
   startrun();
   initoutput();
   tab_init();

   Global->tracktime = 0;
   Global->partitiontime = 0;
   Global->treebuildtime = 0;
   Global->forcecalctime = 0;

   /* Create the slave processes: number of processors less one,
      since the master will do work as well */
   Global->current_id = 0;
   for(ProcessId = 1; ProcessId < NPROC; ProcessId++) {
      {fprintf(stderr, "No more processors -- this is a uniprocessor version!\n"); exit(-1);};
   }

   /* Make the master do slave work so we don't waste the processor */
   {long time(); (Global->computestart) = time(0);};
   printf("COMPUTESTART  = %12u\n",Global->computestart);
   SlaveStart();

   {long time(); (Global->computeend) = time(0);};

   {;};

   printf("COMPUTEEND    = %12u\n",Global->computeend);
   printf("COMPUTETIME   = %12u\n",Global->computeend - Global->computestart);
   printf("TRACKTIME     = %12u\n",Global->tracktime); 
   printf("PARTITIONTIME = %12u\t%5.2f\n",Global->partitiontime,
	  ((float)Global->partitiontime)/Global->tracktime);
   printf("TREEBUILDTIME = %12u\t%5.2f\n",Global->treebuildtime, 
	  ((float)Global->treebuildtime)/Global->tracktime);
   printf("FORCECALCTIME = %12u\t%5.2f\n",Global->forcecalctime,
	  ((float)Global->forcecalctime)/Global->tracktime);
   printf("RESTTIME      = %12u\t%5.2f\n",
	  Global->tracktime - Global->partitiontime - 
	  Global->treebuildtime - Global->forcecalctime, 
	  ((float)(Global->tracktime-Global->partitiontime-
		   Global->treebuildtime-Global->forcecalctime))/
	  Global->tracktime);
   {exit(0);};
}

/*
 * ANLINIT : initialize ANL macros
 */
ANLinit()
{
   {;};
   /* Allocate global, shared memory */

   Global = (struct GlobalMemory *) malloc(sizeof(struct GlobalMemory));;
   if (Global==NULL) error("No initialization for Global\n");
    
   {;};
   {;};
   {;};
   {;};
   {;};
   {;};

   {;};
   {;};
}

/*
 * INIT_ROOT: Processor 0 reinitialize the global root at each time step
 */
init_root (ProcessId)
   unsigned int ProcessId;
{
   int i;

   Global->G_root=Local[0].ctab;
   Type(Global->G_root) = CELL;
   Done(Global->G_root) = FALSE;
   Level(Global->G_root) = IMAX >> 1;
   for (i = 0; i < NSUB; i++) {
      Subp(Global->G_root)[i] = NULL;
   }
   Local[0].mynumcell=1;
}

int Log_base_2(number)
int number;
{
   int cumulative;
   int out;

   cumulative = 1;
   for (out = 0; out < 20; out++) {
      if (cumulative == number) {
         return(out);
      }
      else {
         cumulative = cumulative * 2;
      }
   }

   fprintf(stderr,"Log_base_2: couldn't find log2 of %d\n", number);
   exit(-1);
}

/*
 * TAB_INIT : allocate body and cell data space
 */

tab_init()
{
   cellptr pc;
   int i;
   char *starting_address, *ending_address;

   /*allocate leaf/cell space */
   maxleaf = (int) ((double) fleaves * nbody);
   maxcell = fcells * maxleaf;
   for (i = 0; i < NPROC; ++i) {
      Local[i].ctab = (cellptr) malloc((maxcell / NPROC) * sizeof(cell));;
      Local[i].ltab = (leafptr) malloc((maxleaf / NPROC) * sizeof(leaf));;
   }

   /*allocate space for personal lists of body pointers */
   maxmybody = (nbody+maxleaf*MAX_BODIES_PER_LEAF)/NPROC; 
   Local[0].mybodytab = (bodyptr*) malloc(NPROC*maxmybody*sizeof(bodyptr));;
   /* space is allocated so that every */
   /* process can have a maximum of maxmybody pointers to bodies */ 
   /* then there is an array of bodies called bodytab which is  */
   /* allocated in the distribution generation or when the distr. */
   /* file is read */
   maxmycell = maxcell / NPROC;
   maxmyleaf = maxleaf / NPROC;
   Local[0].mycelltab = (cellptr*) malloc(NPROC*maxmycell*sizeof(cellptr));;
   Local[0].myleaftab = (leafptr*) malloc(NPROC*maxmyleaf*sizeof(leafptr));;

   CellLock = (struct CellLockType *) malloc(sizeof(struct CellLockType));;
   {;};
}

/*
 * SLAVESTART: main task for each processor
 */
void SlaveStart()
{
   unsigned int ProcessId;

   /* Get unique ProcessId */
   {;};
     ProcessId = Global->current_id++;
   {;};

/* POSSIBLE ENHANCEMENT:  Here is where one might pin processes to
   processors to avoid migration */

   /* initialize mybodytabs */
   Local[ProcessId].mybodytab = Local[0].mybodytab + (maxmybody * ProcessId);
   /* note that every process has its own copy   */
   /* of mybodytab, which was initialized to the */
   /* beginning of the whole array by proc. 0    */
   /* before create                              */
   Local[ProcessId].mycelltab = Local[0].mycelltab + (maxmycell * ProcessId);
   Local[ProcessId].myleaftab = Local[0].myleaftab + (maxmyleaf * ProcessId);
/* POSSIBLE ENHANCEMENT:  Here is where one might distribute the
   data across physically distributed memories as desired. 

   One way to do this is as follows:

   int i;

   if (ProcessId == 0) {
     for (i=0;i<NPROC;i++) {
       Place all addresses x such that 
         &(Local[i]) <= x < &(Local[i])+
           sizeof(struct local_memory) on node i
       Place all addresses x such that 
         &(Local[i].mybodytab) <= x < &(Local[i].mybodytab)+
           maxmybody * sizeof(bodyptr) - 1 on node i
       Place all addresses x such that 
         &(Local[i].mycelltab) <= x < &(Local[i].mycelltab)+
           maxmycell * sizeof(cellptr) - 1 on node i
       Place all addresses x such that 
         &(Local[i].myleaftab) <= x < &(Local[i].myleaftab)+
           maxmyleaf * sizeof(leafptr) - 1 on node i
     }
   }

   barrier(Global->Barstart,NPROC);

*/

   Local[ProcessId].tout = Local[0].tout;
   Local[ProcessId].tnow = Local[0].tnow;
   Local[ProcessId].nstep = Local[0].nstep;

   find_my_initial_bodies(bodytab, nbody, ProcessId);

   /* main loop */
   while (Local[ProcessId].tnow < tstop + 0.1 * dtime) {
      stepsystem(ProcessId);
   }
}


/*
 * STARTRUN: startup hierarchical N-body code.
 */

startrun()
{
   string getparam();
   int getiparam();
   bool getbparam();
   double getdparam();
   int seed;
   infile = getparam("in");

   if (*infile != NULL) {
      inputdata();
   }
   else {
      nbody = getiparam("nbody");
      if (nbody < 1) {
	 error("startrun: absurd nbody\n");
      }
      seed = getiparam("seed");
   }
   outfile = getparam("out");
   dtime = getdparam("dtime");
   dthf = 0.5 * dtime;
   eps = getdparam("eps");
   epssq = eps*eps;
   tol = getdparam("tol");
   tolsq = tol*tol;
   fcells = getdparam("fcells");
   fleaves = getdparam("fleaves");
   tstop = getdparam("tstop");
   dtout = getdparam("dtout");
   NPROC = getiparam("NPROC");
   Local[0].nstep = 0;
   pranset(seed);
   testdata();
   setbound();
   Local[0].tout = Local[0].tnow + dtout;
}

/*
 * TESTDATA: generate Plummer model initial conditions for test runs,
 * scaled to units such that M = -4E = G = 1 (Henon, Hegge, etc).
 * See Aarseth, SJ, Henon, M, & Wielen, R (1974) Astr & Ap, 37, 183.
 */

#define MFRAC  0.999                /* mass cut off at MFRAC of total */

testdata()
{
   real rsc, vsc, sqrt(), xrand(), pow(), rsq, r, v, x, y;
   vector cmr, cmv;
   register bodyptr p;
   int rejects = 0;
   int k;
   int halfnbody, i;
   float offset;
   register bodyptr cp;
   double tmp;

   headline = "Hack code: Plummer model";
   Local[0].tnow = 0.0;
   bodytab = (bodyptr) malloc(nbody * sizeof(body));;
   if (bodytab == NULL) {
      error("testdata: not enuf memory\n");
   }
   rsc = 9 * PI / 16;
   vsc = sqrt(1.0 / rsc);

   CLRV(cmr);
   CLRV(cmv);

   halfnbody = nbody / 2;
   if (nbody % 2 != 0) halfnbody++;
   for (p = bodytab; p < bodytab+halfnbody; p++) {
      Type(p) = BODY;
      Mass(p) = 1.0 / nbody;
      Cost(p) = 1;

      r = 1 / sqrt(pow(xrand(0.0, MFRAC), -2.0/3.0) - 1);
      /*   reject radii greater than 10 */
      while (r > 9.0) {
	 rejects++;
	 r = 1 / sqrt(pow(xrand(0.0, MFRAC), -2.0/3.0) - 1);
      }        
      pickshell(Pos(p), rsc * r);
      ADDV(cmr, cmr, Pos(p));
      do {
	 x = xrand(0.0, 1.0);
	 y = xrand(0.0, 0.1);

      } while (y > x*x * pow(1 - x*x, 3.5));

      v = sqrt(2.0) * x / pow(1 + r*r, 0.25);
      pickshell(Vel(p), vsc * v);
      ADDV(cmv, cmv, Vel(p));
   }

   offset = 4.0;

   for (p = bodytab + halfnbody; p < bodytab+nbody; p++) {
      Type(p) = BODY;
      Mass(p) = 1.0 / nbody;
      Cost(p) = 1;

      cp = p - halfnbody;
      for (i = 0; i < NDIM; i++){
	 Pos(p)[i] = Pos(cp)[i] + offset; 
	 ADDV(cmr, cmr, Pos(p));
	 Vel(p)[i] = Vel(cp)[i];
	 ADDV(cmv, cmv, Vel(p));
      }
   }

   DIVVS(cmr, cmr, (real) nbody);
   DIVVS(cmv, cmv, (real) nbody);

   for (p = bodytab; p < bodytab+nbody; p++) {
      SUBV(Pos(p), Pos(p), cmr);
      SUBV(Vel(p), Vel(p), cmv);
   }
}

/*
 * PICKSHELL: pick a random point on a sphere of specified radius.
 */

pickshell(vec, rad)
   real vec[];                     /* coordinate vector chosen */
   real rad;                       /* radius of chosen point */
{
   register int k;
   double rsq, xrand(), sqrt(), rsc;

   do {
      for (k = 0; k < NDIM; k++) {
	 vec[k] = xrand(-1.0, 1.0);
      }
      DOTVP(rsq, vec, vec);
   } while (rsq > 1.0);

   rsc = rad / sqrt(rsq);
   MULVS(vec, vec, rsc);
}



int intpow(i,j)
  int i,j;
{   
    int k;
    int temp = 1;

    for (k = 0; k < j; k++)
        temp = temp*i;
    return temp;
}


/*
 * STEPSYSTEM: advance N-body system one time-step.
 */

void
stepsystem (ProcessId)
   unsigned int ProcessId;
{
    int i;
    real Cavg;
    bodyptr p,*pp;
    vector acc1, dacc, dvel, vel1, dpos;
    int intpow();
    unsigned int time;
    unsigned int trackstart, trackend;
    unsigned int partitionstart, partitionend;
    unsigned int treebuildstart, treebuildend;
    unsigned int forcecalcstart, forcecalcend;

    if (Local[ProcessId].nstep == 2) {
/* POSSIBLE ENHANCEMENT:  Here is where one might reset the
   statistics that one is measuring about the parallel execution */
    }

    if ((ProcessId == 0) && (Local[ProcessId].nstep >= 2)) {
        {long time(); (trackstart) = time(0);};
    }

    if (ProcessId == 0) {
       init_root(ProcessId);
    }
    else {
       Local[ProcessId].mynumcell = 0;
       Local[ProcessId].mynumleaf = 0;
    }


    /* start at same time */
    {;};

    if ((ProcessId == 0) && (Local[ProcessId].nstep >= 2)) {
        {long time(); (treebuildstart) = time(0);};
    }

    /* load bodies into tree   */
    maketree(ProcessId);

    if ((ProcessId == 0) && (Local[ProcessId].nstep >= 2)) {
        {long time(); (treebuildend) = time(0);};
        Global->treebuildtime += treebuildend - treebuildstart;
    }

    Housekeep(ProcessId);

    Cavg = (real) Cost(Global->G_root) / (real)NPROC ;
    Local[ProcessId].workMin = (int) (Cavg * ProcessId);
    Local[ProcessId].workMax = (int) (Cavg * (ProcessId + 1)
				      + (ProcessId == (NPROC - 1)));

    if ((ProcessId == 0) && (Local[ProcessId].nstep >= 2)) {
        {long time(); (partitionstart) = time(0);};
    }

    Local[ProcessId].mynbody = 0;
    find_my_bodies(Global->G_root, 0, BRC_FUC, ProcessId );

/*     B*RRIER(Global->Barcom,NPROC); */
    if ((ProcessId == 0) && (Local[ProcessId].nstep >= 2)) {
        {long time(); (partitionend) = time(0);};
        Global->partitiontime += partitionend - partitionstart;
    }

    if ((ProcessId == 0) && (Local[ProcessId].nstep >= 2)) {
        {long time(); (forcecalcstart) = time(0);};
    }

    ComputeForces(ProcessId);

    if ((ProcessId == 0) && (Local[ProcessId].nstep >= 2)) {
        {long time(); (forcecalcend) = time(0);};
        Global->forcecalctime += forcecalcend - forcecalcstart;
    }

    /* advance my bodies */
    for (pp = Local[ProcessId].mybodytab;
	 pp < Local[ProcessId].mybodytab+Local[ProcessId].mynbody; pp++) {
       p = *pp;
       MULVS(dvel, Acc(p), dthf);              
       ADDV(vel1, Vel(p), dvel);               
       MULVS(dpos, vel1, dtime);               
       ADDV(Pos(p), Pos(p), dpos);             
       ADDV(Vel(p), vel1, dvel);               
        
       for (i = 0; i < NDIM; i++) {
          if (Pos(p)[i]<Local[ProcessId].min[i]) {
	     Local[ProcessId].min[i]=Pos(p)[i];
	  }
          if (Pos(p)[i]>Local[ProcessId].max[i]) {
	     Local[ProcessId].max[i]=Pos(p)[i] ;
	  }
       }
    }
    {;};
    for (i = 0; i < NDIM; i++) {
       if (Global->min[i] > Local[ProcessId].min[i]) {
	  Global->min[i] = Local[ProcessId].min[i];
       }
       if (Global->max[i] < Local[ProcessId].max[i]) {
	  Global->max[i] = Local[ProcessId].max[i];
       }
    }
    {;};

    /* bar needed to make sure that every process has computed its min */
    /* and max coordinates, and has accumulated them into the global   */
    /* min and max, before the new dimensions are computed	       */
    {;};

    if ((ProcessId == 0) && (Local[ProcessId].nstep >= 2)) {
        {long time(); (trackend) = time(0);};
        Global->tracktime += trackend - trackstart;
    }
    if (ProcessId==0) {
      Global->rsize=0;
      SUBV(Global->max,Global->max,Global->min);
      for (i = 0; i < NDIM; i++) {
	if (Global->rsize < Global->max[i]) {
	   Global->rsize = Global->max[i];
	}
      }
      ADDVS(Global->rmin,Global->min,-Global->rsize/100000.0);
      Global->rsize = 1.00002*Global->rsize;
      SETVS(Global->min,1E99);
      SETVS(Global->max,-1E99);
    }
    Local[ProcessId].nstep++;
    Local[ProcessId].tnow = Local[ProcessId].tnow + dtime;
}



void
ComputeForces (ProcessId)
   unsigned int ProcessId;
{
   bodyptr p,*pp;
   vector acc1, dacc, dvel, vel1, dpos;

   for (pp = Local[ProcessId].mybodytab;
	pp < Local[ProcessId].mybodytab+Local[ProcessId].mynbody;pp++) {  
      p = *pp;
      SETV(acc1, Acc(p));
      Cost(p)=0;
      hackgrav(p,ProcessId);
      Local[ProcessId].myn2bcalc += Local[ProcessId].myn2bterm; 
      Local[ProcessId].mynbccalc += Local[ProcessId].mynbcterm;
      if (!Local[ProcessId].skipself) {       /*   did we miss self-int?  */
	 Local[ProcessId].myselfint++;        /*   count another goofup   */
      }
      if (Local[ProcessId].nstep > 0) {
	 /*   use change in accel to make 2nd order correction to vel      */
	 SUBV(dacc, Acc(p), acc1);
	 MULVS(dvel, dacc, dthf);
	 ADDV(Vel(p), Vel(p), dvel);
      }
   }
}

/* 
 * FIND_MY_INITIAL_BODIES: puts into mybodytab the initial list of bodies 
 * assigned to the processor.  
 */

find_my_initial_bodies(btab, nbody, ProcessId)
bodyptr btab;
int nbody;
unsigned int ProcessId;
{
  int Myindex;
  int intpow();
  int equalbodies;
  int extra,offset,i;

  Local[ProcessId].mynbody = nbody / NPROC;
  extra = nbody % NPROC;
  if (ProcessId < extra) {
    Local[ProcessId].mynbody++;    
    offset = Local[ProcessId].mynbody * ProcessId;
  }
  if (ProcessId >= extra) {
    offset = (Local[ProcessId].mynbody+1) * extra + (ProcessId - extra) 
       * Local[ProcessId].mynbody; 
  }
  for (i=0; i < Local[ProcessId].mynbody; i++) {
     Local[ProcessId].mybodytab[i] = &(btab[offset+i]);
  }
  {;};
}


find_my_bodies(mycell, work, direction, ProcessId)
  nodeptr mycell;
  int work;
  int direction;
  unsigned ProcessId;
{
   int i;
   leafptr l;
   nodeptr qptr;

   if (Type(mycell) == LEAF) {
      l = (leafptr) mycell;
      for (i = 0; i < l->num_bodies; i++) {
	 if (work >= Local[ProcessId].workMin - .1) {
	    if((Local[ProcessId].mynbody+2) > maxmybody) {
	       error("find_my_bodies: Processor %d needs more than %d bodies; increase fleaves\n",ProcessId, maxmybody); 
	    }
	    Local[ProcessId].mybodytab[Local[ProcessId].mynbody++] = 
	       Bodyp(l)[i];
	 }
	 work += Cost(Bodyp(l)[i]);
	 if (work >= Local[ProcessId].workMax-.1) {
	    break;
	 }
      }
   }
   else {
      for(i = 0; (i < NSUB) && (work < (Local[ProcessId].workMax - .1)); i++){
	 qptr = Subp(mycell)[Child_Sequence[direction][i]];
	 if (qptr!=NULL) {
	    if ((work+Cost(qptr)) >= (Local[ProcessId].workMin -.1)) {
	       find_my_bodies(qptr,work, Direction_Sequence[direction][i],
			      ProcessId);
	    }
	    work += Cost(qptr);
	 }
      }
   }
}

/*
 * HOUSEKEEP: reinitialize the different variables (in particular global
 * variables) between each time step.
 */

Housekeep(ProcessId)
unsigned ProcessId;
{
   Local[ProcessId].myn2bcalc = Local[ProcessId].mynbccalc 
      = Local[ProcessId].myselfint = 0;
   SETVS(Local[ProcessId].min,1E99);
   SETVS(Local[ProcessId].max,-1E99);
}

/*
 * SETBOUND: Compute the initial size of the root of the tree; only done
 * before first time step, and only processor 0 does it
 */
setbound()
{
   int i;
   real side ;
   bodyptr p;

   SETVS(Local[0].min,1E99);
   SETVS(Local[0].max,-1E99);
   side=0;

   for (p = bodytab; p < bodytab+nbody; p++) {
      for (i=0; i<NDIM;i++) {
	 if (Pos(p)[i]<Local[0].min[i]) Local[0].min[i]=Pos(p)[i] ;
	 if (Pos(p)[i]>Local[0].max[i])  Local[0].max[i]=Pos(p)[i] ;
      }
   }
    
   SUBV(Local[0].max,Local[0].max,Local[0].min);
   for (i=0; i<NDIM;i++) if (side<Local[0].max[i]) side=Local[0].max[i];
   ADDVS(Global->rmin,Local[0].min,-side/100000.0);
   Global->rsize = 1.00002*side;
   SETVS(Global->max,-1E99);
   SETVS(Global->min,1E99);
}

void
Help () 
{
   printf("There are a total of twelve parameters, and all of them have default values.\n");
   printf("\n");
   printf("1) infile (char*) : The name of an input file that contains particle data.  \n");
   printf("    The format of the file is:\n");
   printf("\ta) An int representing the number of particles in the distribution\n");
   printf("\tb) An int representing the dimensionality of the problem (3-D)\n");
   printf("\tc) A double representing the current time of the simulation\n");
   printf("\td) Doubles representing the masses of all the particles\n");
   printf("\te) A vector (length equal to the dimensionality) of doubles\n");
   printf("\t   representing the positions of all the particles\n");
   printf("\tf) A vector (length equal to the dimensionality) of doubles\n");
   printf("\t   representing the velocities of all the particles\n");
   printf("\n");
   printf("    Each of these numbers can be separated by any amount of whitespace.\n");
   printf("\n");
   printf("2) nbody (int) : If no input file is specified (the first line is blank), this\n");
   printf("    number specifies the number of particles to generate under a plummer model.\n");
   printf("    Default is 16384.\n");
   printf("\n");
   printf("3) seed (int) : The seed used by the random number generator.\n");
   printf("    Default is 123.\n");
   printf("\n");
   printf("4) outfile (char*) : The name of the file that snapshots will be printed to. \n");
   printf("    This feature has been disabled in the SPLASH release.\n");
   printf("    Default is NULL.\n");
   printf("\n");
   printf("5) dtime (double) : The integration time-step.\n");
   printf("    Default is 0.025.\n");
   printf("\n");
   printf("6) eps (double) : The usual potential softening\n");
   printf("    Default is 0.05.\n");
   printf("\n");
   printf("7) tol (double) : The cell subdivision tolerance.\n");
   printf("    Default is 1.0.\n");
   printf("\n");
   printf("8) fcells (double) : The total number of cells created is equal to \n");
   printf("    fcells * number of leaves.\n");
   printf("    Default is 2.0.\n");
   printf("\n");
   printf("9) fleaves (double) : The total number of leaves created is equal to  \n");
   printf("    fleaves * nbody.\n");
   printf("    Default is 0.5.\n");
   printf("\n");
   printf("10) tstop (double) : The time to stop integration.\n");
   printf("    Default is 0.075.\n");
   printf("\n");
   printf("11) dtout (double) : The data-output interval.\n");
   printf("    Default is 0.25.\n");
   printf("\n");
   printf("12) NPROC (int) : The number of processors.\n");
   printf("    Default is 1.\n");
}
