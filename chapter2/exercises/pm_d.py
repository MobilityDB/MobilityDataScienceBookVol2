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

"""Exercise 2.5: the design of the MEOS bindings, seen from PyMEOS."""
from datetime import datetime, timezone
from pymeos import *
pymeos_initialize("UTC")
seq = TFloatSeq("[1@2020-01-01, 3@2020-01-03]")
print(seq._inner)
# <cdata 'TSequence *' 0x...>
print(seq.value_at_timestamp(datetime(2020, 1, 2, tzinfo=timezone.utc)))
# 2.0
ss = TFloatSeqSet("{[1@2020-01-01, 3@2020-01-03], [5@2020-01-05, 6@2020-01-06]}")
print([type(s).__name__ for s in ss.sequences()])
# ['TFloatSeq', 'TFloatSeq']
print([type(i).__name__ for i in ss.sequences()[0].instants()])
# ['TFloatInst', 'TFloatInst']
print(ss.num_instants(), ss.max_value(), ss.duration())
# 4 6.0 3 days, 0:00:00
pymeos_finalize()
