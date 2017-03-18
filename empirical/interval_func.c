#include "postgres.h"
#include <string.h>
#include "fmgr.h"
#include "utils/timestamp.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif


/*
File located at https://github.com/postgres/postgres/blob/c29aff959dc64f7321062e7f33d8c6ec23db53d3/src/include/datatype/timestamp.h

Goal of function: take two arrays of timestamps
  - ego_update_arr
  - alt_htag_arr

Go through pairs of elements in ego_update_arr
See how many elements in alt_htag_arr are in each interval
If > 0, bail out and return the number
*/

/*
Pseudocode

Given
- ego_update_arr
- alt_htag_arr

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

Datum activations_in_interval(PG_FUNCTION_ARGS){

  // helpful: http://stackoverflow.com/questions/16992339/why-is-postgresql-array-access-so-much-faster-in-c-than-in-pl-pgsql

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
  bool ego_arr_null_flags, alt_arr_null_flags;
  // Array lengths
  int ego_arr_lenth, alt_arr_length;

  // Preprocess and fill in variables above
  ego_arr_type = ARR_ELEMTYPE(ego_arr);
  alt_arr_type = ARR_ELEMTYPE(alt_arr);
  get_typlenbyvalalign(
    ego_arr_type,
    &ego_arr_elem_type_width,
    &ego_arr_elem_type_by_val,
    &ego_arr_elem_align_code
  );
  get_typlenbyvalalign(
    alt_arr_type,
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
    ego_arr_elem_align_code
    &ego_arr_content,
    &ego_arr_null_flags,
    &ego_arr_length
  );
  deconstruct_array(
    alt_arr,
    alt_arr_elem_type,
    alt_arr_elem_type_width,
    alt_arr_elem_type_by_val,
    alt_arr_elem_align_code
    &alt_arr_content,
    &alt_arr_null_flags,
    &alt_arr_length
  );

  // Actual algorithm begins

  int n;
  n = ego_arr_content[1];
  return PG_RETURN_INT64(n);
}
