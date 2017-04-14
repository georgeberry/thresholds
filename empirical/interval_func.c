#include <postgres.h>
#include <string.h>
#include <fmgr.h>
#include <utils/timestamp.h>
#include <utils/array.h>
#include <catalog/pg_type.h>

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif


/*
Important! You must sort both incoming arrays in descending order.

Check file located at https://github.com/postgres/postgres/blob/c29aff959dc64f7321062e7f33d8c6ec23db53d3/src/include/datatype/timestamp.h


Helpful:
http://stackoverflow.com/questions/16992339/why-is-postgresql-array-access-so-much-faster-in-c-than-in-pl-pgsql
http://stackoverflow.com/questions/23796712/how-to-sum-two-float4-arrays-values-into-a-datum-array-c-function-in-postgres
*/

/*
// How to register this with postgres

make, make install

then:

create or replace function
  activations_in_interval(timestamp, timestamp[], timestamp[])
returns int[]
as 'interval_func.so', 'activations_in_interval'
language c strict;

// How to test

create table timestamp_test (d timestamp, e timestamp);

insert into timestamp_test values ('2004-10-19 10:23:56', '2004-10-19 10:23:55'), ('2004-10-19 10:23:54', '2004-10-19 10:23:53');

select activations_in_interval(array_agg(d), array_agg(e)) from timestamp_test;

// Real world test

select
  a.src,
  activations_in_interval(a.ego_activation, b.ego_updates, a.alter_usages)
from AggregatedFirstUsages a
join EgoUpdates b
on a.src = b.src
where a.src in ARRAY[22167545, 23270835, 23349470, 27107246, 27578762, 30310944, 32480116, 33148717, 33700456, 33846841];


select
  a.src,
  a.ego_activation,
  array_length(b.ego_updates, 1),
  a.alter_usages
from AggregatedFirstUsages a
join EgoUpdates b
on a.src = b.src
limit 10;

*/

Datum activations_in_interval(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(activations_in_interval);

Datum
activations_in_interval(PG_FUNCTION_ARGS)
{
  /*
  Inputs:
    ego_first_usage: timestamp
    ego_updates: timestamp[]
    alter_updates: timestamp[]

  Outputs:
    n_in_most_recent_interval
    exposure_at_activation

  */

  /* We do about 50 lines of processing to translate Postgres arrays to C */
  // timestamp object
  Timestamp ego_update = PG_GETARG_TIMESTAMP(0);
  typedef int int4;

  // output is a 2-array
  // vals[0] = total exposure at activation time
  // vals[1] =
  Datum *vals = (Datum *) palloc(sizeof(Datum) * 2);

  // Array objects
  ArrayType *ego_arr, *alt_arr, *result;
  // Array element types
  Oid ego_arr_elem_type, alt_arr_elem_type;
  // Array element type widths
  int16 ego_arr_elem_type_width, alt_arr_elem_type_width;
  // Not used
  bool ego_arr_elem_type_by_val, alt_arr_elem_type_by_val;
  char ego_arr_elem_align_code, alt_arr_elem_align_code;
  // The data!
  Datum *ego_arr_content, *alt_arr_content;
  // Null flags
  bool *ego_arr_null_flags, *alt_arr_null_flags;
  // Array lengths
  int ego_arr_length, alt_arr_length;

  // Pull out the arrays from input
  ego_arr = PG_GETARG_ARRAYTYPE_P(1);
  alt_arr = PG_GETARG_ARRAYTYPE_P(2);

  // Preprocess and fill in variables above
  ego_arr_elem_type = ARR_ELEMTYPE(ego_arr);
  alt_arr_elem_type = ARR_ELEMTYPE(alt_arr);
  get_typlenbyvalalign(
    ego_arr_elem_type,
    &ego_arr_elem_type_width,
    &ego_arr_elem_type_by_val,
    &ego_arr_elem_align_code
  );
  get_typlenbyvalalign(
    alt_arr_elem_type,
    &alt_arr_elem_type_width,
    &alt_arr_elem_type_by_val,
    &alt_arr_elem_align_code
  );

  // Extract contents
  deconstruct_array(
    ego_arr,
    ego_arr_elem_type,
    ego_arr_elem_type_width,
    ego_arr_elem_type_by_val,
    ego_arr_elem_align_code,
    &ego_arr_content,
    &ego_arr_null_flags,
    &ego_arr_length
  );
  deconstruct_array(
    alt_arr,
    alt_arr_elem_type,
    alt_arr_elem_type_width,
    alt_arr_elem_type_by_val,
    alt_arr_elem_align_code,
    &alt_arr_content,
    &alt_arr_null_flags,
    &alt_arr_length
  );

  /*
   */

  // Declare output array of OID type INT4OID
  // OIDs are here
  // https://github.com/postgres/postgres/blob/
  // 9e3755ecb2d058f7d123dd35a2e1784006190962/src/
  // interfaces/ecpg/ecpglib/typename.c

  // Actual algorithm begins
  /*
  Intuition: assume both arrays are sorted by time, newest element first
  (e.g. descending)

  Then we want to go through pairs of items in the ego time array and check if
  any items in the alter time array are in the interval. If yes, return how many
  are in the *first* such interval, if no, return NULL

  Probably want to extend this to also return the total number of alter usages
  before ego first activation.
  */

  // Ego array too small
  if (ego_arr_length < 2) {
    vals[0] = -4;
    vals[1] = -4;
    result = construct_array(vals, 2, INT4OID, sizeof(int4), true, 'i');
    PG_RETURN_ARRAYTYPE_P(result);
  }

  Timestamp interval_min;
  int exposure, in_interval;
  int ego_idx, alt_idx;
  int i, j;

  ego_idx = 0;
  alt_idx = 0;
  in_interval = 0;

  // Move ego_idx to the first ego tag usage
  while (ego_arr_content[ego_idx] > ego_update) {
    ego_idx++;
    if (ego_idx == ego_arr_length) {
      vals[0] = -1;
      vals[1] = -1;
      result = construct_array(vals, 2, INT4OID, sizeof(int4), true, 'i');
      PG_RETURN_ARRAYTYPE_P(result);
    }
  }

  // Move alt_idx to the first ego tag usage
  while (alt_arr_content[alt_idx] > ego_update) {
    alt_idx++;
    if (alt_idx == alt_arr_length) {
      vals[0] = -2;
      vals[1] = -2;
      result = construct_array(vals, 2, INT4OID, sizeof(int4), true, 'i');
      PG_RETURN_ARRAYTYPE_P(result);
    }
  }

  exposure = alt_arr_length - alt_idx;

  for (i = ego_idx; i < ego_arr_length; i++){
    // Only care about interval min
    // We know that all alter usages are before ego first usage
    // Check if in_interval == 0 to go to next
    interval_min = ego_arr_content[i];

    for (j = alt_idx; j < alt_arr_length; j++){

      // increment
      if (alt_arr_content[j] > interval_min) {
        in_interval++;
        continue;
      }

      // If there was at least one activation, but we have moved past the window
      if (in_interval > 0 && interval_min > alt_arr_content[j]) {
        vals[0] = exposure;
        vals[1] = in_interval;
        result = construct_array(vals, 2, INT4OID, sizeof(int4), true, 'i');
        PG_RETURN_ARRAYTYPE_P(result);
      }

      // if no activations in interval, and alter usage is before interval min
      // update interval min
      if (in_interval == 0 && interval_min > alt_arr_content[j]) {
        alt_idx = j;
        break;
      }
    }
  }
  vals[0] = -3;
  vals[1] = -3;
  result = construct_array(vals, 2, INT4OID, sizeof(int4), true, 'i');
  PG_RETURN_ARRAYTYPE_P(result);
}
