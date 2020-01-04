"""Functions for converting between fixed and floating point formats."""

import math
from random import randint

import numpy as np


# TODO: add tests

def py3round(val: float) -> float:
    """Get rounding behaviour of python3 in python2 (round to nearest even)."""
    if abs(round(val) - val) == 0.5:
        return 2.0 * round(val / 2.0)
    return round(val)


def float2fixed(number: float, int_bits: int, frac_bits: int) -> str:
    """Convert a float number to binary fixed string."""
    if number < 0:
        if number < -2 ** (int_bits - 1):
            return "1" + "0" * (int_bits + frac_bits - 1)
        fixed_nr = bin(int(
            2**(int_bits + frac_bits) - py3round(abs(number)* 2**frac_bits)))
        return fixed_nr[-(int_bits + frac_bits):].zfill(int_bits + frac_bits)
    else:
        if number > 2 ** (int_bits - 1) - 2 ** -frac_bits:
            return "0" + "1" * (int_bits + frac_bits - 1)
        return bin(int(
            py3round(number * 2**frac_bits)))[2:].zfill(int_bits+frac_bits)


def float2fixedint(number: float, int_bits: int, frac_bits: int) -> int:
    """Convert float to fixed. The representation of the fixed number is an
    unsigned integer of the binary value. Useful if there are only integers as
    input allowed."""
    return int(float2fixed(number, int_bits, frac_bits), 2)


def v_float2fixedint(array, int_bits: int, frac_bits: int):
    """Vectorized float2fixedint function."""
    vector_float2fixedint = np.vectorize(float2fixedint, otypes=[np.int])
    return vector_float2fixedint(array, int_bits, frac_bits)


def fixedint2ffloat(number: float, int_bits: int, frac_bits: int) -> float:
    """Convert a binary fixed string to a fixed float number."""
    return fixed2float(bin(int(number))[2:].zfill(int_bits + frac_bits),
                       int_bits, frac_bits)


def v_fixedint2ffloat(array, int_bits: int, frac_bits: int):
    """Vectorized fixedint2ffloat function."""
    vector_fixedint2ffloat = np.vectorize(fixedint2ffloat, otypes=[np.float])
    return vector_fixedint2ffloat(array, int_bits, frac_bits)


def fixed2float(number: str, int_bits: int, frac_bits: int) -> float:
    """Convert binary signed fixed point to floating point number."""
    if number[0] == "1":
        return (- 1.0 * (2 ** (int_bits + frac_bits) - int(number, 2)) *
                2 ** -frac_bits)
    return int(number, 2)*2**-frac_bits


def float2ffloat(number: float, int_bits: int, frac_bits: int) -> float:
    """Convert floating point to fixed point number, stored as float."""
    return max(min(
        py3round(number * 2**frac_bits) / 2**frac_bits,
        2 ** (int_bits - 1) - 2 ** -frac_bits), -2 ** (int_bits - 1))


def v_float2ffloat(array, int_bits: int, frac_bits: int):
    """Vectorized float2ffloat function."""
    vector_float2ffloat = np.vectorize(float2ffloat, otypes=[np.float])
    return vector_float2ffloat(array, int_bits, frac_bits)


def float2pow2(number: float, min_exp: int, max_exp: int) -> str:
    """Convert floating point to power-of-two number."""
    if number == 0:
        exp_rounded = min_exp
    else:
        exp = math.log2(abs(number))
        exp_rounded = int(max(min(py3round(exp), max_exp), min_exp))

    sign = "1" if number < 0 else "0"
    return sign + bin(abs(exp_rounded) - 1)[2:].zfill(3)


def random_fixed_array(size: tuple, int_bits: int, frac_bits: int,
                       signed: bool = True):
    """Generate an array with random fixed point numbers."""
    arr = np.random.randint(2 ** (int_bits + frac_bits),
                            size=size, dtype=np.int)
    # manually extend the bitwidth to implicitly create unsigned values
    int_bits_sign = 0 if signed else 1
    return v_fixedint2ffloat(arr, int_bits + int_bits_sign, frac_bits)


def random_bw(max_bw: int = 16):
    """Generate a random bitwidth."""
    bits = randint(1, max_bw)
    int_bits = randint(1, bits)
    frac_bits = bits - int_bits
    return bits, frac_bits
