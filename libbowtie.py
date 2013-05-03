import ctypes
import os
import tempfile

libbowtie_library_location = \
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "libbowtie2.so")
try:
    _libbowtie = ctypes.CDLL(libbowtie_library_location)
except OSError:
    try:
        _libbowtie = ctypes.CDLL(libbowtie_library_location)
    except OSError:
        _libbowtie = ctypes.CDLL("libbowtie2.so")
_bowtie_c_func = _libbowtie.bowtie

index_location = os.path.join(os.path.dirname(os.path.abspath(__file__)), "indexes", "")

def bowtie(index, outfile_name, unpaired=None, m1=None, m2=None,
           verbose=True, preset=None, threads=None,
           are_sequences=False,
           extra_arguments=[]):
    if unpaired is None and m1 is None and m2 is None:
        raise TypeError("unpaired, m1, and m2 cannot all be none")
    # create list of arguments
    arguments = ["python_bowtie_wrapper"]
    if preset is not None:
        if not preset.startswith("--"):
            preset = "--" + preset
        arguments.append(preset)
    if threads is not None:
        arguments.extend(["--threads", str(threads)])
    # index and input fastq arguments
    if not os.path.isfile(index + ".1.bt2"):
        if os.path.isfile(index_location + index + ".1.bt2"):
            index = index_location + index
        else:
            raise IOError("index %s not found" % index)
    arguments.extend(["-x", index])
    if unpaired is not None:
        if not are_sequences:
            if not os.path.isfile(unpaired):
                raise IOError("File %s not found" % unpaired)
        arguments.extend(["-U", unpaired])
    else:
        if not are_sequences:
            if not os.path.isfile(m1):
                raise IOError("File %s not found" % m1)
            if not os.path.isfile(m2):
                raise IOError("File %s not found" % m2)    
        arguments.extend(["-1", m1, "-2", m2])
    # output argument
    arguments.extend(["-S", outfile_name])
    
    if are_sequences:
        arguments.append("-c")
        
    # optional arguments
    arguments.extend(extra_arguments)
    print arguments

    # create ctypes argv
    argc = len(arguments)
    CSTR_ARRAY = ctypes.c_char_p * argc
    argv = CSTR_ARRAY(*arguments)
    
    # redirect stderr to a temporary file
    handle, filename = tempfile.mkstemp(text=True)
    os.dup2(handle, 2)
    
    # call the function
    result = _bowtie_c_func(argc, argv)

    # read the stdout from the temporary file and close it
    os.lseek(handle, 0, os.SEEK_SET)
    bowtie_stderr = os.read(handle, 1000)
    os.close(handle)
    
    if result:  # something went wrong
        raise Exception(bowtie_stderr)

    if verbose:
        print bowtie_stderr

