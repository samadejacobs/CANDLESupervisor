
#include <errno.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "util.h"

const int buffer_size = 1024*1024;

static void usage(void);
static bool convert(const char* input, const char* output);

static char* program_name = "csv2f64";

int
main(int argc, char* argv[])
{
  if (argc != 3)
  {
    usage();
    exit(EXIT_FAILURE);
  }
  char* input  = argv[1];
  char* output = argv[2];

  bool result = convert(input, output);
  if (!result)
  {
    MESSAGE("conversion failed!");
    return EXIT_FAILURE;
  }

  return EXIT_SUCCESS;
}

static void
usage()
{
  printf("usage: csv2f64 <input.csv> <output.data>\n");
}

static bool convert_fps(FILE* fp_i, FILE* fp_o);

static bool
convert(const char* input, const char* output)
{
  FILE* fp_i = fopen(input, "r");
  CHECK(fp_i != NULL, "could not read: %s", input);
  FILE* fp_o = fopen(output, "w");
  CHECK(fp_o != NULL, "could not write: %s", output);

  bool result = convert_fps(fp_i, fp_o);

  fclose(fp_i);
  fclose(fp_o);

  return result;
}

static inline bool read_text(char* data, size_t count, FILE* fp,
			     size_t* actual_r);
static inline bool convert_word(int rows, const char* word_start,
				double* floats, int* f, FILE* fp);
static inline bool update_rows_cols(char c, int* cols, int* cols_last,
				    int* rows, bool* data_on_line);

static bool
convert_fps(FILE* fp_i, FILE* fp_o)
{
  size_t bytes_c = buffer_size * sizeof(char);
  char* chars = malloc(bytes_c); // the input buffer
  CHECK(chars != NULL, "could not allocate memory: %zi", bytes_c);
  size_t bytes_f = buffer_size * sizeof(double);
  double* floats = malloc(bytes_f); // the output buffer
  CHECK(floats != NULL, "could not allocate memory: %zi", bytes_f);

  int cols_last = -1; // number of columns in last row
  int cols = 1; // current column counter
  int rows = 1; // current row counter
  int f = 0; // index in floats[]
  int offset = 0; // starting offset in chars due to chars from last read
  size_t actual_r = 0; // actual number of items read at last fread
  int length = 0; // the length of our current data (offset+actual_r)
  int w = 0; // index of word start
  bool data_on_line = false; // is there good data on this line?
  bool b;
  int i = 0;
  while (true)
  {
    b = read_text(&chars[offset], bytes_c-offset, fp_i, &actual_r);
    CHECK(b, "read_text() failed!");
    if (actual_r == 0) break;
    length = offset + actual_r;
    for (i = 0; i < length; i++)
    {
      if (chars[i] == ' ' || chars[i] == '\t') continue; // ignore WS
      if (chars[i] == '\n' && ! data_on_line) continue; // blank line
      data_on_line = true; // found good data - not a blank line
      if (chars[i] == ',' || chars[i] == '\n') // end of word
      {
	// If word length is 0 and not a blank line: fail
        CHECK(i-w > 0, "bad text on line: %i column: %i", rows, i-offset+1);
        b = convert_word(rows, &chars[w], floats, &f, fp_o);
        w = i+1;
      }
      b = update_rows_cols(chars[i], &cols, &cols_last, &rows, &data_on_line);
      CHECK(b, "bad input!");
    }
    // Out of space in chars: copy partial words to front of buffer
    offset = length - w;
    memcpy(chars, &chars[w], offset);
    w = 0;
  }

  // Write out any data left in the buffer
  size_t actual_w = fwrite(floats, sizeof(double), f, fp_o);
  CHECK(actual_w == f, "write failed!\n");

  // Fix row and column counts
  if (i == 0 || chars[i-1] == '\n') rows--; // file ended on newline
  if (cols_last == -1) cols_last = 0; // file was empty
  MESSAGE("converted: rows: %i cols: %i", rows, cols_last);

  free(chars);
  free(floats);
  return true;
}

/** Read the next chunk of CSV text
    @param actual_r: OUT actual characters read
    @return True on success, else false
 */
static inline bool
read_text(char* data, size_t count, FILE* fp, size_t* actual_r)
{
  size_t actual = fread(data, sizeof(char), count, fp);
  if (actual == 0)
    CHECK(!ferror(fp), "read failed!");
  *actual_r = actual;
  return true;
}

/** Convert the word (word_start) into a double and possibly write it out
    @param floats IN/OUT Where to add the converted double
    @param f IN/OUT The working index into floats
    @return True on success, else false
*/
static inline bool
convert_word(int rows, const char* word_start,
	     double* floats, int* f, FILE* fp)
{
  int fi = *f;
  errno = 0;
  floats[fi] = strtod(word_start, NULL);
  CHECK(errno == 0, "bad number on line: %i", rows);
  fi++;

  if (fi == buffer_size)
  {
    size_t actual = fwrite(floats, sizeof(double), buffer_size, fp);
    CHECK(actual == buffer_size, "write failed!");
    fi = 0;
  }
  *f = fi;
  return true;
}

/** Update the row and column counters
    All pointer parameters are IN/OUT
    @return True on success, else false
 */
static inline bool
update_rows_cols(char c, int* cols, int* cols_last,
		 int* rows, bool* data_on_line)
{
  if (c == ',')
    (*cols)++;
  if (c == '\n')
  {
    (*rows)++;
    CHECK(*cols == *cols_last || *cols_last == -1,
          "bad column count on line: %i cols=%i cols_last=%i",
          *rows, *cols, *cols_last);
    *cols_last = *cols;
    *cols = 1;
    *data_on_line = false;
  }
  return true;
}
