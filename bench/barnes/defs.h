#line 95 "./null_macros/c.m4.null"

#line 1 "defs.H"
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

#ifndef _DEFS_H_
#define _DEFS_H_

#include "stdinc.h"
#include <assert.h>

//#include <ulocks.h>

#include "vectmath.h"

#define MAX_PROC 128
#define MAX_BODIES_PER_LEAF 10
#define MAXLOCK 2048            	/* maximum number of locks on DASH */
#define PAGE_SIZE 4096			/* in bytes */

#define NSUB (1 << NDIM)        /* subcells per cell */

/* The more complicated 3D case */
#define NUM_DIRECTIONS 32
#define BRC_FUC 0
#define BRC_FRA 1
#define BRA_FDA 2
#define BRA_FRC 3
#define BLC_FDC 4
#define BLC_FLA 5
#define BLA_FUA 6
#define BLA_FLC 7
#define BUC_FUA 8
#define BUC_FLC 9
#define BUA_FUC 10
#define BUA_FRA 11
#define BDC_FDA 12
#define BDC_FRC 13
#define BDA_FDC 14
#define BDA_FLA 15

#define FRC_BUC 16
#define FRC_BRA 17
#define FRA_BDA 18
#define FRA_BRC 19
#define FLC_BDC 20
#define FLC_BLA 21
#define FLA_BUA 22
#define FLA_BLC 23
#define FUC_BUA 24
#define FUC_BLC 25
#define FUA_BUC 26
#define FUA_BRA 27
#define FDC_BDA 28
#define FDC_BRC 29
#define FDA_BDC 30
#define FDA_BLA 31

static int Child_Sequence[NUM_DIRECTIONS][NSUB] =
{
  { 2, 5, 6, 1, 0, 3, 4, 7},  /* BRC_FUC */
  { 2, 5, 6, 1, 0, 7, 4, 3},  /* BRC_FRA */
  { 1, 6, 5, 2, 3, 0, 7, 4},  /* BRA_FDA */
  { 1, 6, 5, 2, 3, 4, 7, 0},  /* BRA_FRC */
  { 6, 1, 2, 5, 4, 7, 0, 3},  /* BLC_FDC */
  { 6, 1, 2, 5, 4, 3, 0, 7},  /* BLC_FLA */
  { 5, 2, 1, 6, 7, 4, 3, 0},  /* BLA_FUA */
  { 5, 2, 1, 6, 7, 0, 3, 4},  /* BLA_FLC */
  { 1, 2, 5, 6, 7, 4, 3, 0},  /* BUC_FUA */
  { 1, 2, 5, 6, 7, 0, 3, 4},  /* BUC_FLC */
  { 6, 5, 2, 1, 0, 3, 4, 7},  /* BUA_FUC */
  { 6, 5, 2, 1, 0, 7, 4, 3},  /* BUA_FRA */
  { 5, 6, 1, 2, 3, 0, 7, 4},  /* BDC_FDA */
  { 5, 6, 1, 2, 3, 4, 7, 0},  /* BDC_FRC */
  { 2, 1, 6, 5, 4, 7, 0, 3},  /* BDA_FDC */
  { 2, 1, 6, 5, 4, 3, 0, 7},  /* BDA_FLA */

  { 3, 4, 7, 0, 1, 2, 5, 6},  /* FRC_BUC */
  { 3, 4, 7, 0, 1, 6, 5, 2},  /* FRC_BRA */
  { 0, 7, 4, 3, 2, 1, 6, 5},  /* FRA_BDA */
  { 0, 7, 4, 3, 2, 5, 6, 1},  /* FRA_BRC */
  { 7, 0, 3, 4, 5, 6, 1, 2},  /* FLC_BDC */
  { 7, 0, 3, 4, 5, 2, 1, 6},  /* FLC_BLA */
  { 4, 3, 0, 7, 6, 5, 2, 1},  /* FLA_BUA */
  { 4, 3, 0, 7, 6, 1, 2, 5},  /* FLA_BLC */
  { 0, 3, 4, 7, 6, 5, 2, 1},  /* FUC_BUA */
  { 0, 3, 4, 7, 6, 1, 2, 5},  /* FUC_BLC */
  { 7, 4, 3, 0, 1, 2, 5, 6},  /* FUA_BUC */
  { 7, 4, 3, 0, 1, 6, 5, 2},  /* FUA_BRA */
  { 4, 7, 0, 3, 2, 1, 6, 5},  /* FDC_BDA */
  { 4, 7, 0, 3, 2, 5, 6, 1},  /* FDC_BRC */
  { 3, 0, 7, 4, 5, 6, 1, 2},  /* FDA_BDC */
  { 3, 0, 7, 4, 5, 2, 1, 6},  /* FDA_BLA */
};

static int Direction_Sequence[NUM_DIRECTIONS][NSUB] =
{
  { FRC_BUC, BRA_FRC, FDA_BDC, BLA_FUA, BUC_FLC, FUA_BUC, BRA_FRC, FDA_BLA },
 /* BRC_FUC */
  { FRC_BUC, BRA_FRC, FDA_BDC, BLA_FUA, BRA_FDA, FRC_BRA, BUC_FUA, FLC_BDC },
 /* BRC_FRA */
  { FRA_BDA, BRC_FRA, FUC_BUA, BLC_FDC, BDA_FLA, FDC_BDA, BRC_FRA, FUC_BLC },
 /* BRA_FDA */
  { FRA_BDA, BRC_FRA, FUC_BUA, BLC_FDC, BUC_FLC, FUA_BUC, BRA_FRC, FDA_BLA },
 /* BRA_FRC */
  { FLC_BDC, BLA_FLC, FUA_BUC, BRA_FDA, BDC_FRC, FDA_BDC, BLA_FLC, FUA_BRA },
 /* BLC_FDC */
  { FLC_BDC, BLA_FLC, FUA_BUC, BRA_FDA, BLA_FUA, FLC_BLA, BDC_FDA, FRC_BUC },
 /* BLC_FLA */
  { FLA_BUA, BLC_FLA, FDC_BDA, BRC_FUC, BUA_FRA, FUC_BUA, BLC_FLA, FDC_BRC },
 /* BLA_FUA */
  { FLA_BUA, BLC_FLA, FDC_BDA, BRC_FUC, BLC_FDC, FLA_BLC, BUA_FUC, FRA_BDA },
 /* BLA_FLC */
  { FUC_BLC, BUA_FUC, FRA_BRC, BDA_FLA, BUA_FRA, FUC_BUA, BLC_FLA, FDC_BRC },
 /* BUC_FUA */
  { FUC_BLC, BUA_FUC, FRA_BRC, BDA_FLA, BLC_FDC, FLA_BLC, BUA_FUC, FRA_BDA },
 /* BUC_FLC */
  { FUA_BRA, BUC_FUA, FLC_BLA, BDC_FRC, BUC_FLC, FUA_BUC, BRA_FRC, FDA_BLA },
 /* BUA_FUC */
  { FUA_BRA, BUC_FUA, FLC_BLA, BDC_FRC, BRA_FDA, FRC_BRA, BUC_FUA, FLC_BDC },
 /* BUA_FRA */
  { FDC_BRC, BDA_FDC, FLA_BLC, BUA_FRA, BDA_FLA, FDC_BDA, BRC_FRA, FUC_BLC },
 /* BDC_FDA */
  { FDC_BRC, BDA_FDC, FLA_BLC, BUA_FRA, BUC_FLC, FUA_BUC, BRA_FRC, FDA_BLA },
 /* BDC_FRC */
  { FDA_BLA, BDC_FDA, FRC_BRA, BUC_FLC, BDC_FRC, FDA_BDC, BLA_FLC, FUA_BRA },
 /* BDA_FDC */
  { FDA_BLA, BDC_FDA, FRC_BRA, BUC_FLC, BLA_FUA, FLC_BLA, BDC_FDA, FRC_BUC },
 /* BDA_FLA */

  { BUC_FLC, FUA_BUC, BRA_FRC, FDA_BLA, FUC_BLC, BUA_FUC, FRA_BRC, BDA_FLA },
 /* FRC_BUC */
  { BUC_FLC, FUA_BUC, BRA_FRC, FDA_BLA, FRA_BDA, BRC_FRA, FUC_BUA, BLC_FDC },
 /* FRC_BRA */
  { BRA_FDA, FRC_BRA, BUC_FUA, FLC_BDC, FDA_BLA, BDC_FDA, FRC_BRA, BUC_FLC },
 /* FRA_BDA */
  { BRA_FDA, FRC_BRA, BUC_FUA, FLC_BDC, FRC_BUC, BRA_FRC, FDA_BDC, BLA_FUA },
 /* FRA_BRC */
  { BLC_FDC, FLA_BLC, BUA_FUC, FRA_BDA, FDC_BRC, BDA_FDC, FLA_BLC, BUA_FRA },
 /* FLC_BDC */
  { BLC_FDC, FLA_BLC, BUA_FUC, FRA_BDA, FLA_BUA, BLC_FLA, FDC_BDA, BRC_FUC },
 /* FLC_BLA */
  { BLA_FUA, FLC_BLA, BDC_FDA, FRC_BUC, FUA_BRA, BUC_FUA, FLC_BLA, BDC_FRC },
 /* FLA_BUA */
  { BLA_FUA, FLC_BLA, BDC_FDA, FRC_BUC, FLC_BDC, BLA_FLC, FUA_BUC, BRA_FDA },
 /* FLA_BLC */
  { BUC_FLC, FUA_BUC, BRA_FRC, FDA_BLA, FUA_BRA, BUC_FUA, FLC_BLA, BDC_FRC },
 /* FUC_BUA */
  { BUC_FLC, FUA_BUC, BRA_FRC, FDA_BLA, FLC_BDC, BLA_FLC, FUA_BUC, BRA_FDA },
 /* FUC_BLC */
  { BUA_FRA, FUC_BUA, BLC_FLA, FDC_BRC, FUC_BLC, BUA_FUC, FRA_BRC, BDA_FLA },
 /* FUA_BUC */
  { BUA_FRA, FUC_BUA, BLC_FLA, FDC_BRC, FRA_BDA, BRC_FRA, FUC_BUA, BLC_FDC },
 /* FUA_BRA */
  { BDC_FRC, FDA_BDC, BLA_FLC, FUA_BRA, FDA_BLA, BDC_FDA, FRC_BRA, BUC_FLC },
 /* FDC_BDA */
  { BDC_FRC, FDA_BDC, BLA_FLC, FUA_BRA, FRC_BUC, BRA_FRC, FDA_BDC, BLA_FUA },
 /* FDC_BRC */
  { BDA_FLA, FDC_BDA, BRC_FRA, FUC_BLC, FDC_BRC, BDA_FDC, FLA_BLC, BUA_FRA },
 /* FDA_BDC */
  { BDA_FLA, FDC_BDA, BRC_FRA, FUC_BLC, FLA_BUA, BLC_FLA, FDC_BDA, BRC_FUC },
 /* FDA_BLA */
};

/*
 * BODY and CELL data structures are used to represent the tree:
 *
 *         +-----------------------------------------------------------+
 * root--> | CELL: mass, pos, cost, quad, /, o, /, /, /, /, o, /, done |
 *         +---------------------------------|--------------|----------+
 *                                           |              |
 *    +--------------------------------------+              |
 *    |                                                     |
 *    |    +--------------------------------------+         |
 *    +--> | BODY: mass, pos, cost, vel, acc, phi |         |
 *         +--------------------------------------+         |
 *                                                          |
 *    +-----------------------------------------------------+
 *    |
 *    |    +-----------------------------------------------------------+
 *    +--> | CELL: mass, pos, cost, quad, o, /, /, o, /, /, o, /, done |
 *         +------------------------------|--------|--------|----------+
 *                                       etc      etc      etc
 */

/*
 * NODE: data common to BODY and CELL structures.
 */

typedef struct _node {
   short type;                 /* code for node type: body or cell */
   real mass;                  /* total mass of node */
   vector pos;                 /* position of node */
   int cost;                   /* number of interactions computed */
   int level;
   struct _node *parent;       /* ptr to parent of this node in tree */
   int child_num;              /* Index that this node should be put
				  at in parent cell */
} node;

typedef node* nodeptr;

#define Type(x) (((nodeptr) (x))->type)
#define Mass(x) (((nodeptr) (x))->mass)
#define Pos(x)  (((nodeptr) (x))->pos)
#define Cost(x) (((nodeptr) (x))->cost)
#define Level(x) (((nodeptr) (x))->level)
#define Parent(x) (((nodeptr) (x))->parent)
#define ChildNum(x) (((nodeptr) (x))->child_num)

/*
 * BODY: data structure used to represent particles.
 */

typedef struct _body* bodyptr;
typedef struct _leaf* leafptr;
typedef struct _cell* cellptr;

#define BODY 01                 /* type code for bodies */

typedef struct _body {
   short type;
   real mass;                  /* mass of body */
   vector pos;                 /* position of body */
   int cost;                   /* number of interactions computed */
   int level;
   leafptr parent;		
   int child_num;              /* Index that this node should be put */
   vector vel;                 /* velocity of body */
   vector acc;                 /* acceleration of body */
   real phi;                   /* potential at body */
} body;

#define Vel(x)  (((bodyptr) (x))->vel)
#define Acc(x)  (((bodyptr) (x))->acc)
#define Phi(x)  (((bodyptr) (x))->phi)

/*
 * CELL: structure used to represent internal nodes of tree.
 */

#define CELL 02                 /* type code for cells */

typedef struct _cell {
   short type;
   real mass;                  /* total mass of cell */
   vector pos;                 /* cm. position of cell */
   int cost;                   /* number of interactions computed */
   int level;
   cellptr parent;		
   int child_num;              /* Index [0..8] that this node should be put */
   int processor;		/* Used by partition code */
   struct _cell *next, *prev;    /* Used in the partition array */
   unsigned long seqnum;
#ifdef QUADPOLE
   matrix quad;                /* quad. moment of cell */
#endif
   volatile short int done;    /* flag to tell when the c.of.m is ready */
   nodeptr subp[NSUB];         /* descendents of cell */
} cell;

#define Subp(x) (((cellptr) (x))->subp)

/*
 * LEAF: structure used to represent leaf nodes of tree.
 */

#define LEAF 03                 /* type code for leaves */

typedef struct _leaf {
   short type;
   real mass;                  /* total mass of leaf */
   vector pos;                 /* cm. position of leaf */
   int cost;                   /* number of interactions computed */
   int level;
   cellptr parent;		
   int child_num;              /* Index [0..8] that this node should be put */
   int processor;		/* Used by partition code */
   struct _leaf *next, *prev;    /* Used in the partition array */
   unsigned long seqnum;
#ifdef QUADPOLE
   matrix quad;                /* quad. moment of leaf */
#endif
   volatile short int done;    /* flag to tell when the c.of.m is ready */
   unsigned int num_bodies;
   bodyptr bodyp[MAX_BODIES_PER_LEAF];         /* bodies of leaf */
} leaf;

#define Bodyp(x)  (((leafptr) (x))->bodyp)

#ifdef QUADPOLE
#define Quad(x) (((cellptr) (x))->quad)
#endif
#define Done(x) (((cellptr) (x))->done)

/*
 * Integerized coordinates: used to mantain body-tree.
 */

#define MAXLEVEL (8*sizeof(int)-2)
#define IMAX  (1 << MAXLEVEL)    /* highest bit of int coord */

#endif

