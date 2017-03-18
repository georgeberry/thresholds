#include <postgres.h>
#include <string.h>
#include <fmgr.h>
#include <utils/timestamp.h>
#include <utils/array.h>

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif


/*
File located at https://github.com/postgres/postgres/blob/c29aff959dc64f7321062e7f33d8c6ec23db53d3/src/include/datatype/timestamp.h

// helpful: http://stackoverflow.com/questions/16992339/why-is-postgresql-array-access-so-much-faster-in-c-than-in-pl-pgsql


Goal of function: take two arrays of timestamps
  - ego_update_arr
  - alt_htag_arr

Go through pairs of elements in ego_update_arr
See how many elements in alt_htag_arr are in each interval
If > 0, bail out and return the number
*/

/*
How to register this with postgres

create or replace function
  activations_in_interval(timestamp[], timestamp[])
returns int
as 'interval_func.so', 'activations_in_interval'
language c strict;

How to test


create table timestamp_test (d timestamp, e timestamp);

insert into timestamp_test values ('2004-10-19 10:23:56', '2004-10-19 10:23:55'), ('2004-10-19 10:23:54', '2004-10-19 10:23:53');

select activations_in_interval(array_agg(d), array_agg(e)) from timestamp_test;

*/

Datum activations_in_interval(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(activations_in_interval);

Datum
activations_in_interval(PG_FUNCTION_ARGS)
{

  /* This block is extracted with deconstruct_array */
  // Array objects
  ArrayType *ego_arr, *alt_arr;
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
  ego_arr = PG_GETARG_ARRAYTYPE_P(0);
  alt_arr = PG_GETARG_ARRAYTYPE_P(1);

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

  // Actual algorithm begins
  /*
  Intuition: assume both arrays are sorted by time, newest element first
  (e.g. descending)

  Then we want to go through pairs of items in the ego time array and check if
  any items in the alter time array are in the interval. If yes, return how many,
  if no, return a 0


  Pseudocode




  alt_usage_idx = 0
  counter = 0

  for intervals in zip(ego_update_arr[:-1], ego_update_arr[1:])
    t1, t2 = intervals # t1 > t2
    for alt_usage in alt_htag_arr
      if t1 > alt_usage > t2
        counter += 1
      if t2 > alt_usage # interval has ended
        if counter > 0
          return counter
  */

  // Ego array too small
  if (ego_arr_length < 2) {
    PG_RETURN_NULL();
  }

  Timestamp interval_min, interval_max, alt_timestamp;

  int count, alt_idx;
  int i, j;
  count = 0;
  alt_idx = 0;

  for (i = 0; i < ego_arr_length; i++){
    // Sorted in desc order, first element is newest
    interval_max = ego_arr_content[i];
    interval_min = ego_arr_content[i + 1];

    for (j = alt_idx; j < alt_arr_length + 1; j++){
      alt_timestamp = alt_arr_content[j];
      // If no elements are in interval and upper end of interval is less than
      // alt_timestamp, increment the counter and go to next interval
      if (alt_timestamp >= interval_max && count == 0){
        alt_idx++;
        break;
      }
      // If no elements in interval and lower end of interval is greater than
      // alt_timestamp, go to next interval. Don't update alt_idx, so we start
      // in the next interval with the same alt_timestamp.
      if (interval_min >= alt_timestamp && count == 0){
        break;
      }
      // If we're in the interval, increment both counters
      if (interval_max > alt_timestamp && alt_timestamp > interval_min){
        count++;
        alt_idx++;
      }
      // We have traversed all items in the interval, return the count
      if (count > 0 && interval_min >= alt_timestamp) {
        PG_RETURN_INT64(count);
      }
    }
  }
  PG_RETURN_NULL();
}
