/*****************************************************************************\
 *  $Id$
 *****************************************************************************
 *  Copyright (C) 2001-2002 The Regents of the University of California.
 *  Produced at Lawrence Livermore National Laboratory (cf, DISCLAIMER).
 *  Written by Andrew Uselton (uselton2@llnl.gov>
 *  UCRL-CODE-2002-008.
 *  
 *  This file is part of PowerMan, a remote power management program.
 *  For details, see <http://www.llnl.gov/linux/powerman/>.
 *  
 *  PowerMan is free software; you can redistribute it and/or modify it under
 *  the terms of the GNU General Public License as published by the Free
 *  Software Foundation; either version 2 of the License, or (at your option)
 *  any later version.
 *  
 *  PowerMan is distributed in the hope that it will be useful, but WITHOUT 
 *  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
 *  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License 
 *  for more details.
 *  
 *  You should have received a copy of the GNU General Public License along
 *  with PowerMan; if not, write to the Free Software Foundation, Inc.,
 *  59 Temple Place, Suite 330, Boston, MA  02111-1307  USA.
\*****************************************************************************/

%{

#define YYSTYPE char *  /*  The generic type returned by all parse matches */
#undef YYDEBUG          /* no debug code plese */
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>       /* for HUGE_VAL and trunc */
#include <assert.h>
#include <stdio.h>

#include "powerman.h"
#include "list.h"
#include "parse_util.h"
#include "device.h"
#include "client.h"
#include "error.h"
#include "string.h"
#include "wrappers.h"

/* prototypes for parse handler routines */
static char *makeNode(char *s2, char *s3, char *s4);
static char *makeDevice(char *s2, char *s3, char *s4, char *s5);
static char *makePlugNameLine(char *s2);

static char *makeScriptSec(char *s2, int com);

static Interp *makeMapLine(char *s2, char *s3);
static List makeMapSecHead(Interp *s1);
static List makeMapSec(List s1, Interp *s2);
static char *makeStmt(StmtType mode, char *s2, List s3);

static char *makeSpecSize(char *s2);
static char *makeSpecAll(char *s2);
static char *makeSpecOn(char *s2);
static char *makeSpecOff(char *s2);
static char *makeSpecType(char *s2);
static char *makeSpecName(char *s2);
static Spec *check_Spec();
static char *makeClientPort(char *s2);
static char *makeDevTimeout(char *s2);
static char *makePingPeriod(char *s2);
static char *makeTCPWrappers();
static char *makeGlobalSec(char *s2);

extern int yylex();
void yyerror();
static void _errormsg(char *msg);
static long _strtolong(char *str);
static double _strtodouble(char *str);
static void _doubletotv(struct timeval *tv, double val);

 Spec *current_spec = NULL;  /* Holds a Spec as it is built */
 Script current_script = NULL; /* Holds a script as it is built */
%}

/* BISON Declatrations */

%token TOK_B_GLOBAL
%token TOK_TCP_WRAPPERS
%token TOK_TIMEOUT
%token TOK_INTERDEV
%token TOK_UPDATE
%token TOK_DEV_TIMEOUT
%token TOK_PING_PERIOD
%token TOK_CLIENT_PORT
%token TOK_B_SPEC
%token TOK_SPEC_NAME
%token TOK_SPEC_TYPE
%token TOK_OFF_STRING
%token TOK_ON_STRING
%token TOK_ALL_STRING
%token TOK_PLUG_COUNT
%token TOK_B_LOGIN
%token TOK_EXPECT
%token TOK_MAP
%token TOK_SEND
%token TOK_DELAY
%token TOK_E_LOGIN
%token TOK_B_LOGOUT
%token TOK_E_LOGOUT
%token TOK_B_STATUS
%token TOK_E_STATUS
%token TOK_B_STATUS_SOFT
%token TOK_E_STATUS_SOFT
%token TOK_B_STATUS_TEMP
%token TOK_E_STATUS_TEMP
%token TOK_B_STATUS_BEACON
%token TOK_E_STATUS_BEACON
%token TOK_B_BEACON_ON
%token TOK_E_BEACON_ON
%token TOK_B_BEACON_OFF
%token TOK_E_BEACON_OFF
%token TOK_B_ON
%token TOK_E_ON
%token TOK_B_ON_ALL
%token TOK_E_ON_ALL
%token TOK_B_OFF
%token TOK_E_OFF
%token TOK_B_OFF_ALL
%token TOK_E_OFF_ALL
%token TOK_B_CYCLE
%token TOK_E_CYCLE
%token TOK_B_CYCLE_ALL
%token TOK_E_CYCLE_ALL
%token TOK_B_RESET
%token TOK_E_RESET
%token TOK_B_RESET_ALL
%token TOK_E_RESET_ALL
%token TOK_B_PING
%token TOK_E_PING
%token TOK_E_SPEC
%right TOK_DEVICE
%token TOK_E_GLOBAL
%token TOK_B_NODES
%token TOK_PLUG_NAME
%token TOK_NODE
%token TOK_E_NODES
%token TOK_STRING_VAL
%token TOK_MATCHPOS
%token TOK_NUMERIC_VAL
%token TOK_TELNET
%token TOK_UNRECOGNIZED




%%
/* Grammar Rules */

configuration_file : configuration_sec node_sec {
    /* conf = $1; */
}
;
configuration_sec : properties_sec devices_sec 
;
properties_sec : specifications_sec global_sec 
;
/* The above rules specify a four section grammar: */
/* 1) Spec list (device specifications) */
/* 2) global Config variables and properties */
/* 3) Devices list */
/* 4) Cluster (nodes list) */

/**************************************************************/
/* Section 1) Specifications                                  */
/**************************************************************/
specifications_sec : specifications_sec specification
        | specification
;
specification   : TOK_B_SPEC spec_name_line specification_item_list spec_script_list plug_name_sec TOK_E_SPEC {
    $$ = (char *)check_Spec();
}
;
spec_name_line  : TOK_SPEC_NAME TOK_STRING_VAL {
    $$ = (char *)makeSpecName($2);
}
;
specification_item_list : specification_item_list specification_item 
        | specification_item
;
specification_item : spec_type_line 
        | off_string_line 
        | on_string_line 
        | all_string_line 
        | spec_size_line 
        | dev_timeout
;
spec_type_line    : TOK_SPEC_TYPE TOK_STRING_VAL {
    $$ = (char *)makeSpecType($2);
}
;
off_string_line : TOK_OFF_STRING TOK_STRING_VAL {
    $$ = (char *)makeSpecOff($2);
}
;
on_string_line    : TOK_ON_STRING TOK_STRING_VAL {
    $$ = (char *)makeSpecOn($2);
}
;
all_string_line : TOK_ALL_STRING TOK_STRING_VAL {
    $$ = (char *)makeSpecAll($2);
}
;
spec_size_line    : TOK_PLUG_COUNT TOK_NUMERIC_VAL {
    $$ = (char *)makeSpecSize($2);
}
;
dev_timeout    : TOK_DEV_TIMEOUT TOK_NUMERIC_VAL {
    $$ = (char *)makeDevTimeout($2);
}
;
dev_timeout    : TOK_PING_PERIOD TOK_NUMERIC_VAL {
    $$ = (char *)makePingPeriod($2);
}
;
spec_script_list : spec_script_list spec_script 
                | spec_script 
;
spec_script    : TOK_B_LOGIN script_list TOK_E_LOGIN {
    $$ = (char *)makeScriptSec($2, PM_LOG_IN);
}
        | TOK_B_LOGOUT script_list TOK_E_LOGOUT {
    $$ = (char *)makeScriptSec($2, PM_LOG_OUT);
}
        | TOK_B_STATUS script_list TOK_E_STATUS {
    $$ = (char *)makeScriptSec($2, PM_STATUS_PLUGS);
} 
        | TOK_B_STATUS_SOFT script_list TOK_E_STATUS_SOFT {
    $$ = (char *)makeScriptSec($2, PM_STATUS_NODES);
}
        | TOK_B_STATUS_TEMP script_list TOK_E_STATUS_TEMP {
    $$ = (char *)makeScriptSec($2, PM_STATUS_TEMP);
}
        | TOK_B_STATUS_BEACON script_list TOK_E_STATUS_BEACON {
    $$ = (char *)makeScriptSec($2, PM_STATUS_BEACON);
}
        | TOK_B_BEACON_ON script_list TOK_E_BEACON_ON {
    $$ = (char *)makeScriptSec($2, PM_BEACON_ON);
}
        | TOK_B_BEACON_OFF script_list TOK_E_BEACON_OFF {
    $$ = (char *)makeScriptSec($2, PM_BEACON_OFF);
}
        | TOK_B_ON script_list TOK_E_ON {
    $$ = (char *)makeScriptSec($2, PM_POWER_ON);
}
        | TOK_B_ON_ALL script_list TOK_E_ON_ALL {
    $$ = (char *)makeScriptSec($2, PM_POWER_ON_ALL);
}
        | TOK_B_OFF script_list TOK_E_OFF {
    $$ = (char *)makeScriptSec($2, PM_POWER_OFF);
}
        | TOK_B_OFF_ALL script_list TOK_E_OFF_ALL {
    $$ = (char *)makeScriptSec($2, PM_POWER_OFF_ALL);
}
        | TOK_B_CYCLE script_list TOK_E_CYCLE {
    $$ = (char *)makeScriptSec($2, PM_POWER_CYCLE);
}
        | TOK_B_CYCLE_ALL script_list TOK_E_CYCLE_ALL {
    $$ = (char *)makeScriptSec($2, PM_POWER_CYCLE_ALL);
}
        | TOK_B_RESET script_list TOK_E_RESET {
    $$ = (char *)makeScriptSec($2, PM_RESET);
}
        | TOK_B_RESET_ALL script_list TOK_E_RESET_ALL {
    $$ = (char *)makeScriptSec($2, PM_RESET_ALL);
}
        | TOK_B_PING script_list TOK_E_PING {
    $$ = (char *)makeScriptSec($2, PM_PING);
}
;
script_list    : script_list stmt
        | stmt
;
stmt    : TOK_EXPECT TOK_STRING_VAL {
    $$ = (char *)makeStmt(STMT_EXPECT, $2, NULL);
}
        | TOK_EXPECT TOK_STRING_VAL map_sec {
    $$ = (char *)makeStmt(STMT_EXPECT, $2, (List)$3);
}
        | TOK_SEND TOK_STRING_VAL {
    $$ = (char *)makeStmt(STMT_SEND, $2, NULL);
}
        | TOK_DELAY TOK_NUMERIC_VAL {
    $$ = (char *)makeStmt(STMT_DELAY, $2, NULL);
}
;
map_sec        : map_sec map_line {
    $$ = (char *)makeMapSec((List)$1, (Interp *)$2);
}
        | map_line {
    $$ = (char *)makeMapSecHead((Interp *)$1);
}
;
map_line : TOK_MAP TOK_MATCHPOS TOK_NUMERIC_VAL TOK_STRING_VAL {
    $$ = (char *)makeMapLine($3, $4);
}
;
plug_name_sec    : plug_name_sec plug_name_line 
        | /* empty */
;
plug_name_line    : TOK_PLUG_NAME TOK_STRING_VAL {
    $$ = (char *)makePlugNameLine($2);
}
;
/**************************************************************/
/* Section 2) Global Config variables and properties          */
/**************************************************************/
global_sec : TOK_B_GLOBAL global_item_list TOK_E_GLOBAL {
    $$ = makeGlobalSec($2);
}
;
global_item_list : global_item_list global_item 
        | global_item
;
global_item    : TCP_wrappers
        | client_port 
;
TCP_wrappers    : TOK_TCP_WRAPPERS {
    $$ = (char *)makeTCPWrappers();
}
;
client_port    : TOK_CLIENT_PORT TOK_NUMERIC_VAL {
    $$ = (char *)makeClientPort($2);
}
;
/**************************************************************/
/* 3) Devices list                          */
/**************************************************************/
devices_sec    : devices_sec device_line
        | device_line
;
device_line    : TOK_DEVICE TOK_STRING_VAL TOK_STRING_VAL TOK_STRING_VAL TOK_STRING_VAL %prec TOK_DEVICE {
    $$ = (char *)makeDevice($2, $3, $4, $5);
}
;
/**************************************************************/
/* 4) Cluster (nodes list)                      */
/**************************************************************/
node_sec    : TOK_B_NODES node_list TOK_E_NODES 
;
node_list    : node_list node_line  
        | node_line 
;
node_line    : TOK_NODE TOK_STRING_VAL TOK_STRING_VAL TOK_STRING_VAL {
    $$ = (char *)makeNode($2, $3, $4);
}
;

%%

void scanner_init(char *filename);
void scanner_fini(void);
int scanner_line(void);
char *scanner_file(void);

/*
 * Entry point into the yacc/lex parser.
 */
int parse_config_file (char *filename)
{
    extern FILE *yyin; /* part of lexer */

    scanner_init(filename);

    yyin = fopen(filename, "r");
    if (!yyin)
        err_exit(TRUE, "%s", filename);
    yyparse();
    fclose(yyin);

    scanner_fini();
    return 0;
} 

static char *makeGlobalSec(char *s2)
{
    if (conf_get_listen_port() == NO_PORT)
        _errormsg("global stanza missing client listener port");
    return NULL;
}

static char *makeTCPWrappers()
{
    conf_set_use_tcp_wrappers(TRUE);
    return NULL;
}

static char *makeClientPort(char *s2)
{
    int port = _strtolong(s2);

    if (conf_get_listen_port() != NO_PORT)
        _errormsg("duplicate client listener port");
    if (port < 1)
        _errormsg("bogus client listener port");
    conf_set_listen_port(port); 
    return s2;
}

static void _spec_missing(char *msg)
{
    err_exit(FALSE, "protocol specification missing %s: %s::%d\n",
            msg, scanner_file(), scanner_line());
}

/*
 * We've got a whole Spec now so do some sanity checks.
 */
static Spec *check_Spec()
{
    Spec *this_spec;
    char *name;
    int i;

    name = current_spec->name;
    if( current_spec->type == NO_DEV )
        _spec_missing("specification type");
    if( current_spec->off == NULL )
        _spec_missing("off string");
    if( current_spec->on == NULL )
        _spec_missing("on string");
    /*if( current_spec->all == NULL )
    _spec_missing("all string");*/ /* this is optional */
    if( (current_spec->size == 0) )
        _spec_missing("size");
    for (i = 0; i < current_spec->size; i++) 
        if (current_spec->plugname[i] == NULL)
            _spec_missing("plug name(s)");

    /* Store the spec in list internal to config.c */
    conf_add_spec(current_spec);
    this_spec = current_spec;
    current_spec = NULL;
    /* I haven't set up a good way to sanity check struct timeval fields */
    /* I don't yet use the return value. */
    return this_spec;
}

static char *makeSpecName(char *s2)
{
    /* 
     *   N.B. The Specification's name line must be before all other
     * specification info.
     */
    if( current_spec != NULL )
        _errormsg("specification name must be first");
    current_spec = conf_spec_create(s2);
    return s2;
}

static char *makeSpecType(char *s2)
{
    int n;

    if( current_spec->type != NO_DEV )
        _errormsg("duplicate specification type");
    if( (n = strncmp(s2, "TCP", 3)) == 0)
        current_spec->type = TCP_DEV;
    else if ( (n = strncmp(s2, "serial", 6)) == 0)
        current_spec->type = SERIAL_DEV;
    return s2;
}

static char *makeSpecOff(char *s2)
{
    if( current_spec->off != NULL )
        _errormsg("duplicate off string");
    current_spec->off = Strdup(s2);
    return s2;
}

static char *makeSpecOn(char *s2)
{
    if( current_spec->on != NULL )
        _errormsg("duplicate on string");
    current_spec->on = Strdup(s2);
    return s2;
}

static char *makeSpecAll(char *s2)
{
    if( current_spec->all != NULL )
        _errormsg("duplicate all string");
    current_spec->all = Strdup(s2);
    return s2;
}

static char *makeSpecSize(char *s2)
{
    int size = _strtolong(s2);
    int i;

    if( current_spec->size != 0 )
        _errormsg("duplicate plug count");
    if (size < 1)
        _errormsg("invalid plug count");
    current_spec->size = size;
    current_spec->plugname = (char **)Malloc(size * sizeof(char *));
    for (i = 0; i < size; i++)
        current_spec->plugname[i] = NULL;
    return s2;
}

static char *makeDevTimeout(char *s2)
{
    _doubletotv(&current_spec->timeout, _strtodouble(s2));
    return s2;
}

static char *makePingPeriod(char *s2)
{
    _doubletotv(&current_spec->ping_period, _strtodouble(s2));
    return s2;
}

static char *makeStmt(StmtType mode, char *s2, List s3)
{
    PreStmt *specl;
    struct timeval tv;

    /*
     * Four kinds of thing could be arriving.  
     * - EXPECT with an interpretation (s2, s3)
     * - EXPECT without an interpretation (s2, NULL)
     * - SEND (s2, NULL)   (s2 may contain a "%s") 
     * - DELAY (s2, NULL)
     */
    if (mode == STMT_DELAY) {
        _doubletotv(&tv, _strtodouble(s2));
        specl = conf_prestmt_create(mode, NULL, &tv, s3);
    } else {
        specl = conf_prestmt_create(mode, s2, NULL, s3);
    }
    if (current_script == NULL)
        current_script = list_create((ListDelF) conf_prestmt_destroy);
    list_append(current_script, specl);
    return s2;
}

static List makeMapSec(List s1, Interp *s2)
{
    list_append(s1, s2);
    return s1;
}

static List makeMapSecHead(Interp *s1)
{
    List map;

    map = list_create((ListDelF) conf_interp_destroy);
    list_append(map, s1);
    return map;
}

static Interp *makeMapLine(char *s3, char *s4)
{
    Interp *interp;

    interp = conf_interp_create(s4);
    interp->match_pos = _strtolong(s3);
    if (interp->match_pos < 1 || interp->match_pos >= MAX_MATCH_POS)
        _errormsg("invalid match position value");
    return interp;
}

static char *makeScriptSec(char *s2, int com)
{
    if( current_spec->prescripts[com] != NULL )
        _errormsg("duplicate script");
    current_spec->prescripts[com] = current_script;
    current_script = NULL;
    return s2;
}
    


static char *makePlugNameLine(char *s2)
{
    int i = 0;

    if( current_spec == NULL ) 
        _errormsg("plug name outside of protocol specification");
    if( current_spec->plugname == NULL ) 
        _errormsg("plug name line does not preceded by size line");
    if( current_spec->size <= 0 ) 
        _errormsg("invalid size");
    while( (current_spec->plugname[i] != NULL) && (i < current_spec->size) )
        i++;
    if( i == current_spec->size )
        _errormsg("too many plug names lines");
    current_spec->plugname[i] = Strdup(s2);
    return s2;
}

/*
 * We've hit a Device line.  
 * s2: proper name for the Device
 * s3: name of the Spec to use
 * s4: the internet host name of the Device or special file name
 * s5: the TCP port on which it is listening or serial flags (e.g. 9600,8n1)
 * From this information we can build a complete Device structure.
 */   
static char *makeDevice(char *s2, char *s3, char *s4, char *s5)
{
    Device *dev;
    Spec *spec;
    reg_syntax_t cflags = REG_EXTENDED;
    int i;
    Plug *plug;

    /* find that spec */
    spec = conf_find_spec(s3);
    if ( spec == NULL ) 
    _errormsg("device specification not found");

    /* make the Device */
    dev = dev_create(s2);
    dev->specname = Strdup(s3);
    dev->type = spec->type;
    dev->timeout = spec->timeout;
    dev->ping_period = spec->ping_period;
    /* set up the host name and port */
    switch(dev->type) {
    case TCP_DEV :
        dev->devu.tcp.host = Strdup(s4);
        dev->devu.tcp.service = Strdup(s5);
        break;
    case SERIAL_DEV :
        dev->devu.serial.special = Strdup(s4);
        dev->devu.serial.flags = Strdup(s5);
        break;
    default :
        _errormsg("unimplemented device type");
    }
    for (i = 0; i < spec->size; i++) {
        plug = dev_plug_create(spec->plugname[i]);
        list_append(dev->plugs, plug);
    }
    /* begin transfering info from the Spec to the Device */
    dev->all = spec->all ? Strdup(spec->all) : NULL;
    re_syntax_options = RE_SYNTAX_POSIX_EXTENDED;
    Regcomp( &(dev->on_re), spec->on, cflags);
    Regcomp( &(dev->off_re), spec->off, cflags);
    
    /* 
     * Each script needs to be transferred and any Interps need to 
     * be set up.  The conf_stmt_create() call transforms the EXPECT 
     * strings into compiled RegEx recognizers. 
     */
    for (i = 0; i < NUM_SCRIPTS; i++) {
        ListIterator script;
        PreStmt *specl;
        Stmt *stmt;
        Interp *interp;
        Interp *new;
        List map;
        ListIterator map_i;

        if (spec->prescripts[i] == NULL) {
            dev->scripts[i] = NULL;
            continue; /* unimplemented */
        }

        dev->scripts[i] = list_create((ListDelF) conf_stmt_destroy);
        script = list_iterator_create(spec->prescripts[i]);
        while( (specl = list_next(script)) ) {
            if( specl->map == NULL )
                map = NULL;
            else {
                map = list_create((ListDelF) conf_interp_destroy);
                map_i = list_iterator_create(specl->map);
                while( (interp = list_next(map_i)) ) {
                    new = conf_interp_create(interp->plug_name);
                    new->match_pos = interp->match_pos;
                    list_append(map, new);
                }
                list_iterator_destroy(map_i);
            }
            stmt = conf_stmt_create(specl->type, specl->string1, 
                                          map, specl->tv);
            list_append(dev->scripts[i], stmt);
        }
    }

    dev_add(dev);
    return s2;
}

/*
 * s1 : literal "node"
 * s2 : node name
 * s3 : device name
 * s4 : plug name
 */
static char *makeNode(char *s2, char *s3, char *s4)
{
    int i;
    Interp *interp;
    List script;
    ListIterator itr;
    Stmt *stmt;
    Plug *plug;
    Device *dev;

    if (!conf_addnode(s2))
        _errormsg("duplicate node");
    /* find the device controlling this nodes plug */
    dev = dev_findbyname(s3);
    if(dev == NULL) 
        _errormsg("unknown device");
    /*
     * Plugs are defined in Spec, and they must be searched to match the node
     */
    plug = list_find_first(dev->plugs, (ListFindF) dev_plug_match, s4);
    if( plug == NULL )  {
        fprintf(stderr, "%s\n", s4);
        _errormsg("unknown plug");
    }
    plug->node = Strdup(s2);
    /*
     * Finally an exhaustive search of the Interps in a device
     * is required because this node will be the target of some
     */
    for (i = 0; i < NUM_SCRIPTS; i++) {
    if ((script = dev->scripts[i]) == NULL)
        continue; /* unimplemented */
    itr = list_iterator_create(script);
    while( (stmt = list_next(itr)) ) {
        switch( stmt->type ) {
        case STMT_SEND :
        case STMT_DELAY :
            break;
        case STMT_EXPECT :
            if( stmt->u.expect.map == NULL ) 
                continue;
            interp = list_find_first(stmt->u.expect.map, 
                                     (ListFindF) conf_interp_match, s4);
            if( interp != NULL )
                interp->node = Strdup(s2);
            break;
        default :
        }
    }
    list_iterator_destroy(itr);
    }
    return s2;
}

static double _strtodouble(char *str)
{
    char *endptr;
    double val = strtod(str, &endptr);

    if (val == 0.0 && endptr == str)
        _errormsg("error parsing double value");
    if ((val == HUGE_VAL || val == -HUGE_VAL) && errno == ERANGE)
        _errormsg("double value would cause overflow");
    return val;
}

static long _strtolong(char *str)
{
    char *endptr;
    long val = strtol(str, &endptr, 0);

    if (val == 0 && endptr == str)
        _errormsg("error parsing long integer value");
    if ((val == LONG_MIN || val == LONG_MAX) && errno == ERANGE)
        _errormsg("long integer value would cause under/overflow");
    return val;
}

static void _doubletotv(struct timeval *tv, double val)
{
    tv->tv_sec = (val * 10.0)/10; /* crude round-down without -lm */
    tv->tv_usec = ((val - tv->tv_sec) * 1000000.0);
}

static void _errormsg(char *msg)
{
    err_exit(FALSE, "%s: %s::%d\n", msg, scanner_file(), scanner_line());
}

void yyerror()
{
    _errormsg("parse error");
}

/*
 * vi:tabstop=4 shiftwidth=4 expandtab
 */
