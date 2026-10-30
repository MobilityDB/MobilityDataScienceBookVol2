#
# This MobilityDB code is provided under The PostgreSQL License.
# Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
# contributors
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose, without fee, and without a written
# agreement is hereby granted, provided that the above copyright notice and
# this paragraph and the following two paragraphs appear in all copies.
#
# IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
#
# UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
# AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
# PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
#

"""Map the Vietnamese letters of the T5 encoding of Latin Modern to their codes.

The tables of chapter 7 write a Vietnamese letter absent from the T1 encoding as
\\vnc{<code>}, its position in the font t5-lmr7. The positions are read from
lm-t5.enc, the encoding vector of that font in TeX Live
(fonts/enc/dvips/lm/lm-t5.enc), by the glyph name of each letter. No script of
this repository maps a letter to a font position; the nearest is #_tex of
chapter7/figures/vgprint.py, which escapes the text of the figure overlays, and
flock_tables.py calls the two. Run alone, the program checks the codes the
chapter uses against the encoding vector.
usage: python3 t5codes.py <lm-t5.enc>
"""
import re
import sys
import unicodedata

ACC = {'acute': '́', 'grave': '̀', 'hookabove': '̉', 'tilde': '̃',
       'dotbelow': '̣', 'circumflex': '̂', 'breve': '̆', 'horn': '̛'}
MARKS = r'acute|grave|hookabove|tilde|dotbelow|circumflex|breve|horn'


def glyph_char(name):
    """Return the letter a glyph name of the encoding vector draws, or None."""
    if name in ('Dcroat', 'Dbar', 'Dslash'):
        return 'Đ'
    if name in ('dcroat', 'dbar', 'dmacron'):
        return 'đ'
    m = re.fullmatch(rf'([A-Za-z])((?:{MARKS})+)', name)
    if not m:
        return None
    marks = re.findall(MARKS, m.group(2))
    # The vowel marks attach before the tone marks
    marks.sort(key=lambda a: 0 if a in ('circumflex', 'breve', 'horn') else 1)
    return unicodedata.normalize('NFC', m.group(1) + ''.join(ACC[a] for a in marks))


def codes(path):
    """Return the code of each letter of the encoding vector at the path."""
    text = open(path).read()
    body = text[text.index('[') + 1:text.index(']')]
    names = re.findall(r'/([A-Za-z0-9.]+)', body)
    out = {}
    for code, name in enumerate(names):
        c = glyph_char(name)
        if c and c not in out:
            out[c] = code
    return out


if __name__ == '__main__':
    t5 = codes(sys.argv[1])
    used = {'Đ': 30, 'ậ': 170, 'ắ': 173, 'ừ': 248, 'ầ': 166, 'ấ': 167, 'ố': 232, 'ư': 247,
            'ế': 184, 'ồ': 231, 'ị': 224, 'ơ': 236, 'ệ': 187, 'ỹ': 255, 'ộ': 235}
    bad = {c: (k, t5.get(c)) for c, k in used.items() if t5.get(c) != k}
    print(f'{len(t5)} letters; {len(used) - len(bad)} of {len(used)} codes of the chapter agree; '
          f'mismatches {bad}')
    sys.exit(1 if bad else 0)
