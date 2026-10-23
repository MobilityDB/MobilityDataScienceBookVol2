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

"""Exercise 2.6: the aggregation and the tiling of three trips, with pymeos==1.1.3 and
pymeos_cffi==1.1.3 (see the README)."""
from datetime import timedelta
from pymeos import *
pymeos_initialize("UTC")
trips = [TGeomPointSeq("[Point(1 2)@2020-06-01 08:00, Point(9 2)@2020-06-01 09:00]"),
    TGeomPointSeq("[Point(1 7)@2020-06-01 08:30, Point(9 7)@2020-06-01 10:00]"),
    TGeomPointSeq("[Point(7 1)@2020-06-01 09:30, Point(7 9)@2020-06-01 10:30]")]
extent = TemporalPointExtentAggregator.aggregate(trips)
print(extent)
aggregator = TemporalPointExtentAggregator.start_aggregation()
for trip in trips[:2]:
    aggregator.add(trip)
print(aggregator.aggregation())
tcount = TemporalPeriodCountAggregator.aggregate(trips)
print(tcount)
print(tcount.max_value(), tcount.at(2).duration())
for tile in extent.tile(5):
    inter = [i for i in (tr.at(tile) for tr in trips) if i is not None]
    if inter:
        print(tile.xmin(), tile.ymin(), len(inter),
            sum((i.duration() for i in inter), timedelta()),
            sum(i.length() for i in inter))
pymeos_finalize()
