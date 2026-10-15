package book.examples;

import static functions.functions.*;

import java.util.ArrayList;
import java.util.List;
import java.util.TreeMap;

import book.examples.utils.BerlinmodTripRecord;
import book.examples.utils.CSVRecords;
import book.examples.utils.SizeOfBox;
import book.examples.utils.SizeOfBox.option;
import functions.MeosErrorHandler;
import functions.functions;
import jnr.ffi.Memory;
import jnr.ffi.Pointer;
import jnr.ffi.Runtime;
import types.boxes.STBox;

// Exercise: spatiotemporal tiles of 5 km x 5 km x 1 day, and for each day
// the tile in which the trips traveled the longest distance
public class JMEOS10 {

	public static void main(String[] args) throws Exception {
		functions.meos_initialize();
		functions.meos_initialize_timezone("UTC");
		functions.meos_initialize_error_handler(new MeosErrorHandler());

		CSVRecords.setSkipHeaderLines(1);
		ArrayList<BerlinmodTripRecord> dataTrips =
				CSVRecords.readRecords(args.length > 0 ? args[0] : "/data/berlinmod_trips.csv",
				List.of(0,1,2,3,4),
				BerlinmodTripRecord::builder);

		// Spatiotemporal extent of the trips and the bounding box of each trip
		Pointer extent = null;
		ArrayList<Pointer> tripBoxes = new ArrayList<>();
		for (BerlinmodTripRecord tripRec : dataTrips) {
			extent = tspatial_extent_transfn(extent, tripRec.getTrip());
			tripBoxes.add(tspatial_to_stbox(tripRec.getTrip()));
		}

		Pointer sOrigin = geom_in("SRID=3857;Point(0 0)", -1);
		Pointer duration = pg_interval_in("1 day", -1);
		Runtime runtime = Runtime.getSystemRuntime();
		Pointer tilesQtyPtr = Memory.allocate(runtime, Integer.BYTES);
		Pointer tiles = stbox_space_time_tiles(extent, 5000.0, 5000.0, 0.0,
				duration, sOrigin, pg_timestamptz_in("2020-06-01", -1), true, tilesQtyPtr);
		int tilesQty = tilesQtyPtr.getInt(0);
		System.out.printf("Created %d spatiotemporal tiles%n", tilesQty);

		final long STBOX_SIZE = SizeOfBox.calculate(STBox.class, option.sizeof);
		// For each day, the tile with the longest distance and that distance
		TreeMap<String, String> bestTile = new TreeMap<>();
		TreeMap<String, Double> bestKm = new TreeMap<>();
		for (int i = 0; i < tilesQty; i++) {
			Pointer tile = tiles.slice((long) i * STBOX_SIZE);
			double km = 0;
			for (int j = 0; j < dataTrips.size(); j++) {
				// Skip the trips whose bounding box does not overlap the tile
				if (! overlaps_stbox_stbox(tile, tripBoxes.get(j)))
					continue;
				Pointer split = tgeo_at_stbox(dataTrips.get(j).getTrip(), tile, false);
				if (split != null)
					km += tpoint_length(split) / 1000.0;
			}
			String tileStr = stbox_out(tile, 0);
			String day = tileStr.replaceAll(".*\\[(\\d{4}-\\d{2}-\\d{2}).*", "$1");
			if (km > bestKm.getOrDefault(day, 0.0)) {
				bestKm.put(day, km);
				bestTile.put(day, tileStr);
			}
		}
		for (String day : bestKm.keySet())
			System.out.printf("%s: %.1f km in %s%n", day, bestKm.get(day), bestTile.get(day));
		functions.meos_finalize();
	}
}
