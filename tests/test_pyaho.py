
import pytest
from pyaho import AhoCorasick


def test_from_iterable():
    aho = AhoCorasick.from_iterable([
        b'fu',
        b'bar',
        b'baz'
    ])

    assert aho.find_all(b"@('-')@ fu :-) bar baz!") == [
        (8, b'fu'),
        (15, b'bar'),
        (19, b'baz'),
    ]


def test_with_overlap():
    aho = AhoCorasick.from_iterable([b'a', b'aa', b'aaa'])
    result = [
        (0, b'a'),
        (0, b'aa'),
        (1, b'a'),
        (0, b'aaa'),
        (1, b'aa'),
        (2, b'a'),
    ]
    assert aho.find_all(b'aaa') == result
    assert list(aho.iter_all(b'aaa')) == result


def test_lots_of_matches():
    aho = AhoCorasick.from_iterable([
        ('foo_' + str(i)).encode('utf-8')
        for i in range(1000000)
    ] + [b'foo_bar'])

    text = b' foo_bar ' * 1000
    assert len(aho.find_all(text)) == 1000
    assert aho.count_occurrences(text) == 1000
    matches = aho.iter_all(text)
    for _ in range(1000):
        print(next(matches))

