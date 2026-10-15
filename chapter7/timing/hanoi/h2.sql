select municipalityid, municipalityname,
  COUNT(*) as intersectCount
from trips t, municipalities m
where eintersects(t.trip, m.municipalitygeo)
group by municipalityid, municipalityname
order by intersectCount desc;
