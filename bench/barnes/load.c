#line 95 "./null_macros/c.m4.null"

#line 1 "load.C"
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

 
#define global extern

#include "code.h"
#include "defs.h"

bool intcoord();
cellptr makecell(unsigned int ProcessId);
leafptr makeleaf(unsigned int ProcessId);
cellptr SubdivideLeaf(leafptr le, cellptr parent, unsigned int l,
		      unsigned int ProcessId);

cellptr InitCell(cellptr parent, unsigned int ProcessId);
leafptr InitLeaf(cellptr parent, unsigned int ProcessId);
nodeptr loadtree(bodyptr p, cellptr root, unsigned int ProcessId);

/*
 * MAKETREE: initialize tree structure for hack force calculation.
 */

maketree(ProcessId)
   unsigned ProcessId;
{
   bodyptr p, *pp;

   Local[ProcessId].myncell = 0;
   Local[ProcessId].mynleaf = 0;
   if (ProcessId == 0) {
      Local[ProcessId].mycelltab[Local[ProcessId].myncell++] = Global->G_root; 
   }
   Local[ProcessId].Current_Root = (nodeptr) Global->G_root;
   for (pp = Local[ProcessId].mybodytab; 
	pp < Local[ProcessId].mybodytab+Local[ProcessId].mynbody; pp++) {
      p = *pp;
      if (Mass(p) != 0.0) {
	 Local[ProcessId].Current_Root 
	    = (nodeptr) loadtree(p, (cellptr) Local[ProcessId].Current_Root, 
				 ProcessId);
      }
      else {
	 {;};
	 fprintf(stderr, "Process %d found body %d to have zero mass\n",
		 ProcessId, (int) p);	
	 {;};
      }
   }
   {;};
   hackcofm( 0, ProcessId );
   {;};
}

cellptr InitCell(parent, ProcessId)
   cellptr parent;
   unsigned ProcessId;
{
   cellptr c;
   int i, Mycell;

   c = makecell(ProcessId);
   c->processor = ProcessId;
   c->next = NULL;
   c->prev = NULL;
   if (parent == NULL)
      Level(c) = IMAX >> 1;
   else
      Level(c) = Level(parent) >> 1;
   Parent(c) = (nodeptr) parent;
   ChildNum(c) = 0;
   return (c);
}

leafptr InitLeaf(parent, ProcessId)
   cellptr parent;
   unsigned ProcessId;
{
   leafptr l;
   int i, Mycell;

   l = makeleaf(ProcessId);
   l->processor = ProcessId;
   l->next = NULL;
   l->prev = NULL;
   if (parent==NULL)
      Level(l) = IMAX >> 1;
   else
      Level(l) = Level(parent) >> 1;
   Parent(l) = (nodeptr) parent;
   ChildNum(l) = 0;
   return (l);
}

printtree (n)
   nodeptr n;
{
   int k;
   cellptr c;
   leafptr l;
   bodyptr p;
   nodeptr tmp;
   unsigned long nseq;
   int xp[NDIM];

   switch (Type(n)) {
    case CELL:
      c = (cellptr) n;
      nseq = c->seqnum;
      printf("Cell : Cost = %d, ", Cost(c));
      PRTV("Pos", Pos(n));
      printf("\n");
      for (k = 0; k < NSUB; k++) {
	 printf("Child #%d: ", k);
	 if (Subp(c)[k] == NULL) {
	    printf("NONE");
	 }
	 else {
	    if (Type(Subp(c)[k]) == CELL) {
	       nseq = ((cellptr) Subp(c)[k])->seqnum;
	       printf("C: Cost = %d, ", Cost(Subp(c)[k]));
	    }
	    else {
	       nseq = ((leafptr) Subp(c)[k])->seqnum;
	       printf("L: # Bodies = %2d, Cost = %d, ", 
		      ((leafptr) Subp(c)[k])->num_bodies, Cost(Subp(c)[k]));
	    }	
	    tmp = Subp(c)[k];
	    PRTV("Pos", Pos(tmp));
	 }
	 printf("\n");
      }
      for (k=0;k<NSUB;k++) {
	 if (Subp(c)[k] != NULL) {	    
	    printtree(Subp(c)[k]);
	 }
      }      
      break;
    case LEAF:
      l = (leafptr) n;
      nseq = l->seqnum;
      printf("Leaf : # Bodies = %2d, Cost = %d, ", l->num_bodies, Cost(l));
      PRTV("Pos", Pos(n));
      printf("\n");
      for (k = 0; k < l->num_bodies; k++) {
	 p = Bodyp(l)[k];
	 printf("Body #%2d: Num = %2d, Level = %o, ",
		p - bodytab, k, Level(p));
	 PRTV("Pos",Pos(p));
	 printf("\n");
      }
      break;
    default:
      fprintf(stderr, "Bad type\n");
      exit(-1);
      break;
   }
   fflush(stdout);
}

/*
 * LOADTREE: descend tree and insert particle.
 */

nodeptr
loadtree(p, root, ProcessId)
   bodyptr p;                        /* body to load into tree */
   cellptr root;
   unsigned ProcessId;
{
   int l, xq[NDIM], xp[NDIM], xor[NDIM], subindex(), flag;
   int i, j, root_level;
   bool valid_root;
   int kidIndex;
   volatile nodeptr *volatile qptr, mynode;
   cellptr c;
   leafptr le;

   intcoord(xp, Pos(p));
   valid_root = TRUE;
   for (i = 0; i < NDIM; i++) {
      xor[i] = xp[i] ^ Local[ProcessId].Root_Coords[i];
   }
   for (i = IMAX >> 1; i > Level(root); i >>= 1) {
      for (j = 0; j < NDIM; j++) {
	 if (xor[j] & i) {
	    valid_root = FALSE;
	    break;
	 }
      }
      if (!valid_root) {
	 break;
      }
   }
   if (!valid_root) {
      if (root != Global->G_root) {
	 root_level = Level(root);
	 for (j = i; j > root_level; j >>= 1) {
	    root = (cellptr) Parent(root);
	 }
	 valid_root = TRUE;
	 for (i = IMAX >> 1; i > Level(root); i >>= 1) {
	    for (j = 0; j < NDIM; j++) {
	       if (xor[j] & i) {
		  valid_root = FALSE;
		  break;
	       }
	    }
	    if (!valid_root) {
	       printf("P%d body %d\n", ProcessId, p - bodytab);
	       root = Global->G_root;
	    }
	 }
      }
   }
   root = Global->G_root;
   mynode = (nodeptr) root;
   kidIndex = subindex(xp, Level(mynode));
   qptr = &Subp(mynode)[kidIndex];

   l = Level(mynode) >> 1;

   flag = TRUE;
   while (flag) {                           /* loop descending tree     */
      if (l == 0) {
	 error("not enough levels in tree\n");
      }
      if (*qptr == NULL) { 
	 /* lock the parent cell */
	 {;};
	 if (*qptr == NULL) {
	    le = InitLeaf((cellptr) mynode, ProcessId);
	    Parent(p) = (nodeptr) le;
	    Level(p) = l;
	    ChildNum(p) = le->num_bodies;
	    ChildNum(le) = kidIndex;
	    Bodyp(le)[le->num_bodies++] = p;
	    *qptr = (nodeptr) le;
	    flag = FALSE;
	 }
	 {;};
	 /* unlock the parent cell */
      }
      if (flag && *qptr && (Type(*qptr) == LEAF)) {
	 /*   reached a "leaf"?      */
	 {;};
	 /* lock the parent cell */
	 if (Type(*qptr) == LEAF) {             /* still a "leaf"?      */
	    le = (leafptr) *qptr;
	    if (le->num_bodies == MAX_BODIES_PER_LEAF) {
	       *qptr = (nodeptr) SubdivideLeaf(le, (cellptr) mynode, l,
						  ProcessId);
	    }
	    else {
	       Parent(p) = (nodeptr) le;
	       Level(p) = l;
	       ChildNum(p) = le->num_bodies;
	       Bodyp(le)[le->num_bodies++] = p;
	       flag = FALSE;
	    }
	 }
	 {;};
	 /* unlock the node           */
      }
      if (flag) {
	 mynode = *qptr;
         kidIndex = subindex(xp, l);
	 qptr = &Subp(*qptr)[kidIndex];  /* move down one level  */
	 l = l >> 1;                            /* and test next bit    */
      }
   }
   SETV(Local[ProcessId].Root_Coords, xp);
   return Parent((leafptr) *qptr);
}


/* * INTCOORD: compute integerized coordinates.  * Returns: TRUE
unless rp was out of bounds.  */

bool intcoord(xp, rp)
  int xp[NDIM];                  /* integerized coordinate vector [0,IMAX) */
  vector rp;                     /* real coordinate vector (system coords) */
{
   int k;
   bool inb;
   double xsc, floor();
    
   inb = TRUE;
   for (k = 0; k < NDIM; k++) {
      xsc = (rp[k] - Global->rmin[k]) / Global->rsize; 
      if (0.0 <= xsc && xsc < 1.0) {
	 xp[k] = floor(IMAX * xsc);
      }
      else {
	 inb = FALSE;
      }
   }
   return (inb);
}

/*
 * SUBINDEX: determine which subcell to select.
 */

int subindex(x, l)
  int x[NDIM];                       /* integerized coordinates of particle */
  int l;                             /* current level of tree */
{
   int i, k;
   int yes;
    
   i = 0;
   yes = FALSE;
   if (x[0] & l) {
      i += NSUB >> 1;
      yes = TRUE;
   }
   for (k = 1; k < NDIM; k++) {
      if (((x[k] & l) && !yes) || (!(x[k] & l) && yes)) { 
	 i += NSUB >> (k + 1);
	 yes = TRUE;
      }
      else yes = FALSE;
   }

   return (i);
}



/*
 * HACKCOFM: descend tree finding center-of-mass coordinates.
 */

hackcofm(nc, ProcessId)
  int nc;
  unsigned ProcessId;
{
   int i,Myindex;
   nodeptr r;
   leafptr l;
   leafptr* ll;
   bodyptr p;
   cellptr q;
   cellptr *cc;
   vector tmpv, dr;
   real drsq;
   matrix drdr, Idrsq, tmpm;

   /* get a cell using get*sub.  Cells are got in reverse of the order in */
   /* the cell array; i.e. reverse of the order in which they were created */
   /* this way, we look at child cells before parents			 */
    
   for (ll = Local[ProcessId].myleaftab + Local[ProcessId].mynleaf - 1; 
	ll >= Local[ProcessId].myleaftab; ll--) {
      l = *ll;
      Mass(l) = 0.0;
      Cost(l) = 0;
      CLRV(Pos(l));
      for (i = 0; i < l->num_bodies; i++) {
	 p = Bodyp(l)[i];
	 Mass(l) += Mass(p);
	 Cost(l) += Cost(p);
	 MULVS(tmpv, Pos(p), Mass(p));
	 ADDV(Pos(l), Pos(l), tmpv);
      }
      DIVVS(Pos(l), Pos(l), Mass(l));
#ifdef QUADPOLE
      CLRM(Quad(l));
      for (i = 0; i < l->num_bodies; i++) {
	 p = Bodyp(l)[i];
	 SUBV(dr, Pos(p), Pos(l));
	 OUTVP(drdr, dr, dr);
	 DOTVP(drsq, dr, dr);
	 SETMI(Idrsq);
	 MULMS(Idrsq, Idrsq, drsq);
	 MULMS(tmpm, drdr, 3.0);
	 SUBM(tmpm, tmpm, Idrsq);
	 MULMS(tmpm, tmpm, Mass(p));
	 ADDM(Quad(l), Quad(l), tmpm);
      }
#endif
      Done(l)=TRUE;
   }
   for (cc = Local[ProcessId].mycelltab+Local[ProcessId].myncell-1; 
	cc >= Local[ProcessId].mycelltab; cc--) {
      q = *cc;
      Mass(q) = 0.0;
      Cost(q) = 0;
      CLRV(Pos(q));
      for (i = 0; i < NSUB; i++) {
	 r = Subp(q)[i];
	 if (r != NULL) {
	    while(!Done(r)) {
	       /* wait */
	    }
	    Mass(q) += Mass(r);
	    Cost(q) += Cost(r);
	    MULVS(tmpv, Pos(r), Mass(r));
	    ADDV(Pos(q), Pos(q), tmpv);
	    Done(r) = FALSE;
	 }
      }
      DIVVS(Pos(q), Pos(q), Mass(q));
#ifdef QUADPOLE
      CLRM(Quad(q));
      for (i = 0; i < NSUB; i++) {
	 r = Subp(q)[i];
	 if (r != NULL) {
	    SUBV(dr, Pos(r), Pos(q));
	    OUTVP(drdr, dr, dr);
	    DOTVP(drsq, dr, dr);
	    SETMI(Idrsq);
	    MULMS(Idrsq, Idrsq, drsq);
	    MULMS(tmpm, drdr, 3.0);
	    SUBM(tmpm, tmpm, Idrsq);
	    MULMS(tmpm, tmpm, Mass(r));
	    ADDM(tmpm, tmpm, Quad(r));
	    ADDM(Quad(q), Quad(q), tmpm);
	 }
      }
#endif
      Done(q)=TRUE;
   }
}

cellptr
SubdivideLeaf (le, parent, l, ProcessId)
   leafptr le;
   cellptr parent;
   unsigned int l;
   unsigned int ProcessId;
{
   cellptr c;
   int i, index;
   int xp[NDIM];
   bodyptr bodies[MAX_BODIES_PER_LEAF];
   int num_bodies;
   bodyptr p;

   /* first copy leaf's bodies to temp array, so we can reuse the leaf */
   num_bodies = le->num_bodies;
   for (i = 0; i < num_bodies; i++) {
      bodies[i] = Bodyp(le)[i];
      Bodyp(le)[i] = NULL;
   }
   le->num_bodies = 0;
   /* create the parent cell for this subtree */
   c = InitCell(parent, ProcessId);
   ChildNum(c) = ChildNum(le);
   /* do first particle separately, so we can reuse le */
   p = bodies[0];
   intcoord(xp, Pos(p));
   index = subindex(xp, l);
   Subp(c)[index] = (nodeptr) le;
   ChildNum(le) = index;
   Parent(le) = (nodeptr) c;
   Level(le) = l >> 1;
   /* set stuff for body */
   Parent(p) = (nodeptr) le;
   ChildNum(p) = le->num_bodies;
   Level(p) = l >> 1;
   /* insert the body */
   Bodyp(le)[le->num_bodies++] = p;
   /* now handle the rest */
   for (i = 1; i < num_bodies; i++) {
      p = bodies[i];
      intcoord(xp, Pos(p));
      index = subindex(xp, l);
      if (!Subp(c)[index]) {
	 le = InitLeaf(c, ProcessId);
	 ChildNum(le) = index;
	 Subp(c)[index] = (nodeptr) le;
      }
      else {
	 le = (leafptr) Subp(c)[index];
      }
      Parent(p) = (nodeptr) le;
      ChildNum(p) = le->num_bodies;
      Level(p) = l >> 1;
      Bodyp(le)[le->num_bodies++] = p;
   }
   return c;
}

/*
 * MAKECELL: allocation routine for cells.
 */

cellptr makecell(ProcessId)
   unsigned ProcessId;
{
   cellptr c;
   int i, Mycell;
    
   if (Local[ProcessId].mynumcell == maxmycell) {
      error("makecell: Proc %d needs more than %d cells; increase fcells\n", 
	    ProcessId,maxmycell);
   }
   Mycell = Local[ProcessId].mynumcell++;
   c = Local[ProcessId].ctab + Mycell;
   c->seqnum = ProcessId*maxmycell+Mycell;
   Type(c) = CELL;
   Done(c) = FALSE;
   Mass(c) = 0.0;
   for (i = 0; i < NSUB; i++) {
      Subp(c)[i] = NULL;
   }
   Local[ProcessId].mycelltab[Local[ProcessId].myncell++] = c;
   return (c);
}

/*
 * MAKELEAF: allocation routine for leaves.
 */

leafptr makeleaf(ProcessId)
   unsigned ProcessId;
{
   leafptr le;
   int i, Myleaf;
    
   if (Local[ProcessId].mynumleaf == maxmyleaf) {
      error("makeleaf: Proc %d needs more than %d leaves; increase fleaves\n",
	    ProcessId,maxmyleaf);
   }
   Myleaf = Local[ProcessId].mynumleaf++;
   le = Local[ProcessId].ltab + Myleaf;
   le->seqnum = ProcessId * maxmyleaf + Myleaf;
   Type(le) = LEAF;
   Done(le) = FALSE;
   Mass(le) = 0.0;
   le->num_bodies = 0;
   for (i = 0; i < MAX_BODIES_PER_LEAF; i++) {
      Bodyp(le)[i] = NULL;
   }
   Local[ProcessId].myleaftab[Local[ProcessId].mynleaf++] = le;
   return (le);
}


