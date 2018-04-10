from libc.stdio cimport FILE, fopen, fclose
from libc.stdlib cimport malloc, free, realloc


cdef extern from "msutil.h":
    ctypedef struct MEMREF:
        const char* ptr
        size_t len
    MEMREF  memref(const char* text, size_t len)


cdef extern from "_acism.h":
    cdef struct acism:
        pass

    ctypedef acism ACISM


cdef extern from "acism.h":
    ctypedef int (*ACISM_ACTION)(int strnum, int textpos, void *context)
    ACISM* acism_create(const MEMREF*, int)
    ACISM* acism_load(FILE*)
    ACISM* acism_mmap(FILE*)
    void   acism_destroy(ACISM*)
    void   acism_save(FILE*, const ACISM*)
    int    acism_scan(const ACISM* psp, const MEMREF text, ACISM_ACTION *fn, void *fndata)
    int    acism_more(const ACISM* psp, const MEMREF text, ACISM_ACTION *fn, void *fndata, int *state)


#
# Aho-Corasick structure building
#

cdef AhoCorasick _compile(list strings):
    """Build PyAho from a list of strings. """
    # Prepare C-data
    cdef size_t number_of_strings = len(strings)
    cdef MEMREF* memrefs = <MEMREF *>malloc(number_of_strings * sizeof (MEMREF))
    cdef size_t* sizes = <size_t*>malloc(number_of_strings * sizeof (size_t))
    cdef bytes string

    # TODO - how to disable None checks on `strings[i]`?
    for i in range(number_of_strings):
        string = strings[i]
        sizes[i] = len(string)
        memrefs[i].len = len(string)
        memrefs[i].ptr = string

    cdef ACISM* psp = acism_create(memrefs, number_of_strings)

    # Create AhoCorasick instance
    cdef AhoCorasick aho = AhoCorasick()
    aho.psp = psp
    aho.sizes = sizes
    free(memrefs)

    return aho


cdef FILE* _open_file(const char* path, const char* mode="r"):
    cdef FILE *pfp = fopen(path, mode)
    if not pfp:
        raise IOError("Unable to open file: %s" % path)
    return pfp

#
# Processing
#


ctypedef struct MATCH:
    int strnum
    int textpos


ctypedef struct CONTEXT:
    MATCH*  ptr
    size_t  size
    size_t  count


cdef int accumulate_match(int strnum, int textpos, CONTEXT* context):
    # Resize dynamically
    if context.count >= context.size:
        context.size = <size_t>(context.size * 2)
        context.ptr = <MATCH*>realloc(context.ptr, context.size * sizeof (MATCH))

    # Store new match
    context.ptr[context.count].strnum = strnum;
    context.ptr[context.count].textpos = textpos;
    context.count += 1

    return 0


cdef int accumulate_count(int strnum, int textpos, int* count):
    count[0] += 1;
    return 0


cdef list _scan(
        const size_t* sizes,
        const ACISM* psp,
        const char* text,
        size_t length,
        int* state,
):
    cdef MEMREF ctext = memref(text, length)

    # Init structure to store extracted words
    cdef CONTEXT context
    context.ptr = <MATCH*>malloc(64 * sizeof (MATCH))
    context.size = 64
    context.count = 0

    # Extract words
    acism_more(psp, ctext, <ACISM_ACTION*>&accumulate_match, &context, state)

    cdef list results = [
        (
            context.ptr[i].textpos - sizes[context.ptr[i].strnum],
            text[context.ptr[i].textpos - sizes[context.ptr[i].strnum]:context.ptr[i].textpos]
        ) for i in range(context.count)
    ]

    free(context.ptr)

    return results



cdef class AhoCorasick:
    cdef ACISM* psp
    # TODO - find a way to create `sizes` from `psp.
    # This will allow serialization.
    cdef size_t* sizes

    def __dealloc__(self):
        acism_destroy(self.psp)
        free(self.sizes)

    def iter_all(self, bytes text not None):
        cdef size_t length = len(text)
        cdef char* ctext = text
        cdef MEMREF mref
        cdef int state = 0

        cdef size_t chunk_size = 4096
        cdef size_t start = 0

        cdef list matches

        while (start + chunk_size) < length:
            # Scans next chunk of text
            matches = _scan(
                self.sizes,
                self.psp,
                ctext + start,
                chunk_size,
                &state
            )
            start += chunk_size

            # TODO - fix position in text
            for i in range(len(matches)):
                yield matches[i]

        # Process last chunk if total length of text was not a multiple of chunk_size
        if start < length:
            matches = _scan(
                self.sizes,
                self.psp,
                ctext + start,
                length - start,
                &state
            )

            # TODO - fix position in text
            for i in range(len(matches)):
                yield matches[i]

    def find_all(self, bytes text not None):
        cdef int state = 0
        return _scan(self.sizes, self.psp, text, len(text), &state)

    def count_occurrences(self, bytes text not None):
        cdef MEMREF ctext = memref(text, len(text))
        cdef int count = 0
        acism_scan(self.psp, ctext, <ACISM_ACTION*>&accumulate_count, &count)
        return count

    @staticmethod
    def from_iterable(strings not None):
        return _compile(strings)

    @staticmethod
    def from_string(string, sep='\n'):
        """Build string detector from `sep`-separated terms found in `string`."""
        strings = string.split(sep)
        return AhoCorasick.from_iterable(strings)

    @staticmethod
    def from_file(path):
        """Read a """
        with open(path, "rt") as input_dictionary:
            return AhoCorasick.from_string(input_dictionary.read())

    def dump(self, path):
        # We're not able to retrieve the original dictionary after it has
        # been dumped to disk so this feature is disabled at the moment.
        raise NotImplemented()

        cdef FILE* fp = _open_file(path, "w")
        acism_save(fp, self.psp)
        fclose(fp)

    def load(self, path):
        # We're not able to retrieve the original dictionary after it has
        # been dumped to disk so this feature is disabled at the moment.
        raise NotImplemented()

        cdef FILE* patterns_file = _open_file(path)
        # Load structure into memory
        self.psp = acism_load(patterns_file)
        fclose(patterns_file)

    def mmap(self, path):
        # We're not able to retrieve the original dictionary after it has
        # been dumped to disk so this feature is disabled at the moment.
        raise NotImplemented()

        cdef FILE* patterns_file = _open_file(path)
        # MMAP structure into memory
        self.psp = acism_mmap(patterns_file)
        fclose(patterns_file)
