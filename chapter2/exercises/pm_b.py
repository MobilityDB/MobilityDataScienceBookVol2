exec(open("pm_a.py").read().split("for mmsi, row")[0])

sailing = ships["sog"].apply(
    lambda s: s.at(FloatSpan(lower=1, upper=200, lower_inc=False))).dropna()
count = TemporalPeriodCountAggregator.aggregate(sailing)
peak = count.max_value()
at_peak = count.at(peak).time()
print(peak, at_peak.num_spans(), at_peak.duration())
print(at_peak.start_timestamp(), at_peak.end_timestamp())
print(count.time().duration())
