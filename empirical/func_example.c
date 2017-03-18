#include "postgres.h"
#include <string.h>
#include "fmgr.h"
#include "utils/geo_decls.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

/*
CREATE OR REPLACE FUNCTION
  add_one( INT )
RETURNS INT
AS 'func_example.so', 'add_one'
LANGUAGE C STRICT IMMUTABLE;
 */

PG_FUNCTION_INFO_V1(add_one);

Datum
add_one(PG_FUNCTION_ARGS)
{
    int64   arg = PG_GETARG_INT64(0);

    PG_RETURN_INT64(arg + 1);
}
