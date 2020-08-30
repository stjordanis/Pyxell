
import argparse
import os
import json
import platform
import re
import subprocess
import sys
from pathlib import Path
from timeit import default_timer as timer

from .errors import NotSupportedError, PyxellError
from .indentation import transform_indented_code
from .parsing import parse_program
from .transpiler import PyxellTranspiler
from .version import __version__

abspath = Path(__file__).parents[1]


units = {}
for name in ['std', 'math', 'random']:
    try:
        unit = json.load(open(abspath/f'lib/{name}.json'))
    except FileNotFoundError:
        unit = None
    units[name] = unit


def build_ast(path):
    code = transform_indented_code(path.read_text())
    return parse_program(code)


def build_libs():
    for name in units:
        path = abspath/f'lib/{name}.px'
        units[name] = build_ast(path)
        json.dump(units[name], open(str(path).replace('.px', '.json'), 'w'), indent='\t')


def cpp_flags(cpp_compiler, opt_level):
    flags = [f'-O{opt_level}', '-std=c++17']
    if 'clang' in cpp_compiler:
        flags.append('-fcoroutines-ts')
    return flags


def resolve_local_includes(path):
    code = path.read_text().replace('#pragma once', '')

    def replacer(match):
        return resolve_local_includes(path.parents[0]/match.group(1))

    return re.sub(r'#include "(.+?)"', replacer, code)


def run_cpp_compiler(cpp_compiler, cpp_filename, exe_filename, opt_level, verbose=False, disable_warnings=False):
    command = [cpp_compiler, cpp_filename, '-include', str(abspath/'lib/base.hpp'), '-o', exe_filename, *cpp_flags(cpp_compiler, opt_level), '-lstdc++']
    if disable_warnings:
        command.append('-w')
    if platform.system() != 'Windows':
        command.append('-lm')

    if verbose:
        print(f"running {' '.join(command)}")

    try:
        if verbose:
            subprocess.call(command, stderr=subprocess.STDOUT)
        else:
            subprocess.check_output(command, stderr=subprocess.STDOUT)
    except FileNotFoundError:
        print(f"command not found: {cpp_compiler}")
        sys.exit(1)


def compile(filepath, cpp_compiler, opt_level, verbose=False, mode='executable'):
    filepath = Path(filepath)
    filename, ext = os.path.splitext(filepath)
    cpp_filename = f'{filename}.cpp'
    exe_filename = f'{filename}.exe'

    if verbose:
        print(f"transpiling {filepath} to {cpp_filename}")

    t1 = timer()
    transpiler = PyxellTranspiler(cpp_compiler)

    for name, ast in units.items():
        transpiler.run(ast, name)

    ast = build_ast(filepath)
    code = transpiler.run_main(ast)

    with open(cpp_filename, 'w') as file:
        file.write(f"/*\n"
                   f"Generated by Pyxell {__version__}.\n"
                   f"https://github.com/adamsol/Pyxell\n"
                   f"*/\n\n")

        if mode == 'standalone-cpp':
            file.write(resolve_local_includes(abspath/'lib/base.hpp'))
            file.write("\n\n/* Program */\n\n")

        file.write(code)

    t2 = timer()
    global transpilation_time
    transpilation_time = t2 - t1

    if mode != 'executable':
        return

    t1 = timer()
    run_cpp_compiler(cpp_compiler, cpp_filename, exe_filename, opt_level, verbose)
    t2 = timer()
    global compilation_time
    compilation_time = t2 - t1

    return exe_filename


def main():
    parser = argparse.ArgumentParser(prog='pyxell', description="Run Pyxell compiler.")
    parser.add_argument('filepath', nargs=argparse.OPTIONAL, help="source file path")
    parser.add_argument('-c', '--cpp-compiler', default='clang', help="C++ compiler command (default: clang)")
    parser.add_argument('-l', '--libs', action='store_true', help="build libraries and exit")
    parser.add_argument('-n', '--dont-run', action='store_true', help="don't run the program after compilation")
    parser.add_argument('-O', '--opt-level', default='2', help="compiler optimization level (default: 2)")
    parser.add_argument('-s', '--standalone-cpp', action='store_true', help="save transpiled C++ code with all libraries and exit")
    parser.add_argument('-t', '--time', action='store_true', help="measure time of program compilation and execution")
    parser.add_argument('-v', '--verbose', action='store_true', help="output diagnostic information")
    parser.add_argument('-V', '--version', action='store_true', help="print version number and exit")
    args = parser.parse_args()

    if args.version:
        print(f"Pyxell {__version__}")
        sys.exit(0)

    if args.libs:
        build_libs()
        sys.exit(0)

    if not args.filepath:
        parser.error("filepath is required")

    try:
        mode = 'standalone-cpp' if args.standalone_cpp else 'executable'
        exe_filename = compile(args.filepath, args.cpp_compiler, args.opt_level, args.verbose, mode)
    except FileNotFoundError:
        print(f"file not found: {args.filepath}")
        sys.exit(1)
    except (NotSupportedError, PyxellError) as e:
        print(str(e))
        sys.exit(1)

    if exe_filename and not args.dont_run:
        if '/' not in exe_filename and '\\' not in exe_filename:
            exe_filename = './' + exe_filename

        if args.verbose:
            print(f"executing {exe_filename}")

        t1 = timer()
        subprocess.call(exe_filename)
        t2 = timer()
        execution_time = t2 - t1

    if args.time:
        print("---")
        print(f"transpilation: {transpilation_time:.3f}s")
        if exe_filename:
            print(f"compilation: {compilation_time:.3f}s")
            if not args.dont_run:
                print(f"execution: {execution_time:.3f}s")
