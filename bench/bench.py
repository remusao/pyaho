#!/usr/bin/env python
# -*- coding: utf-8 -*-

from timeit import timeit
import random

# This implementation pyaho
import pyaho

with open('data/names.txt', 'rb') as names_file:
    names = [keyword for keyword in names_file]

with open('data/textblob.txt', 'rb') as text_file:
    text = text_file.read()

# TODO: make benchmark more realistic. Check with texts having different density
# of keywords uniformely distributed: 0% (no match), 1%, 10%, 50% and 100% (all
# words are a match).
# TODO: bench for different numbers of keywords.
# TODO: bench for different sizes of text.
# TODO: for each different setup, compute the throughput in GB/s

##############################################################################
# re module
##############################################################################

import re

def init_re(testcase):
    return re.compile('|'.join(testcase['names_str']))

def process_re(regex, testcase):
    return regex.findall(testcase['text_str'])



##############################################################################
# https://github.com/WojciechMula/pyahocorasick/
##############################################################################

import ahocorasick

def init_ahocorasick(testcase):
    automaton = ahocorasick.Automaton()
    for idx, key in enumerate(testcase['names_str']):
        automaton.add_word(key, (idx, key))
    automaton.make_automaton()
    return automaton

def process_ahocorasick(automaton, testcase):
    return list(automaton.iter(testcase['text_str']))


##############################################################################
# https://github.com/JanFan/py-aho-corasick
##############################################################################

from py_aho_corasick import py_aho_corasick

def init_py_aho_corasick(testcase):
    return py_aho_corasick.Automaton(testcase['names'])

def process_py_aho_corasick(automaton, testcase):
    return list(automaton.get_keywords_found(testcase['text']))


##############################################################################
# https://github.com/scoder/acora
##############################################################################

from acora import AcoraBuilder

def init_acora(testcase):
    builder = AcoraBuilder()
    builder.update(testcase['names'])
    return builder.build()

def process_acora(ac, testcase):
    return ac.findall(testcase['text'])


##############################################################################
# https://github.com/JDonner/NoAho
##############################################################################

from noaho import NoAho

def init_noaho(testcase):
    trie = NoAho()
    for name in testcase['names_str']:
        trie.add(name)
    trie.compile()
    return trie

def process_noaho(a, testcase):
    return list(a.findall_long(testcase['text_str']))


##############################################################################
# https://github.com/abusix/ahocorapy
##############################################################################

from ahocorapy.keywordtree import KeywordTree

def init_ahocorapy(testcase):
    kwtree = KeywordTree(case_insensitive=False)
    for name in testcase['names']:
        kwtree.add(name)
    kwtree.finalize()
    return kwtree

def process_ahocorapy(kwtree, testcase):
    return list(kwtree.search_all(testcase['text']))


##############################################################################
# pyaho
##############################################################################

from pyaho import AhoCorasick

def init_pyaho(testcase):
    return AhoCorasick.from_iterable(testcase['names'])

def process_pyaho(aho, testcase):
    return aho.count_occurrences(testcase['text'])


# Run benchmark
###############

def display_results(results):
    results.sort(key=lambda result: result[1])
    fastest = results[0][1]
    for i, (fun, t) in enumerate(results):
        print(f'{i + 1}. {fun} => {t} x{t / fastest}')


def run(testcase):
    init_functions = [
        init_acora,
        init_ahocorapy,
        init_ahocorasick,
        init_noaho,
        init_re,
        init_py_aho_corasick,
        init_pyaho,
    ]

    process_functions = [
        process_acora,
        process_ahocorapy,
        process_ahocorasick,
        process_noaho,
        process_re,
        process_py_aho_corasick,
        process_pyaho,
    ]

    iterations = 1

    print(f'Running with {len(testcase["text"])} bytes of text and {len(testcase["names"])} keywords')

    print('Bench init...')
    display_results([
        (
            init.__name__,
            timeit(
                f'{init.__name__}(testcase)',
                number=iterations,
                globals={**globals(), 'testcase': testcase})
        ) for init in init_functions
    ])

    print('Bench process...')
    display_results([
        (
            process.__name__,
            timeit(
                f'{process.__name__}(model, testcase)',
                number=iterations,
                globals={**globals(), 'model': init(testcase), 'testcase': testcase})
        ) for init, process in zip(init_functions, process_functions)
    ])


def generate_test_case(nkeywords, expected_matches, text_length):
    """Generate a test case with `nkeywords` keywords to build the Automaton and
    a text of size `text_length` where we expect `expected_matches` matches."""
    # TODO
    return {
        'names': names,
        'names_str': names_str,
        'text': text,
        'text_str': text_str
    }


def main():
    testcase = generate_test_case(None, None, None)
    run(testcase)


if __name__ == '__main__':
    main()
