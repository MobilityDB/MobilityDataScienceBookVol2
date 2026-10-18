package book.examples;

import static functions.GeneratedFunctions.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;

import book.examples.utils.BerlinmodTripRecord;
import book.examples.utils.CSVRecords;
import book.examples.utils.TripsInSpeedTimeTile;
import functions.MeosErrorHandler;
import functions.GeneratedFunctions;
import jnr.ffi.Pointer;

// Exercise: trips with speed in [23, 33] during a day, from the tile summaries only
public class JMEOS08a {

	public static void main(String[] args) throws Exception {
		GeneratedFunctions.meos_initialize();
		GeneratedFunctions.meos_initialize_timezone("UTC");
		GeneratedFunctions.meos_initialize_error_handler(new MeosErrorHandler());

		CSVRecords.setSkipHeaderLines(1);
		ArrayList<BerlinmodTripRecord> dataTrips =
				CSVRecords.readRecords(args.length > 0 ? args[0] : "/data/berlinmod_trips.csv",
				List.of(0,1,2,3,4),
				BerlinmodTripRecord::builder);

		ArrayList<TripsInSpeedTimeTile> tilePointers =
				SpeedTimeTiling.tiles(dataTrips, "1 day");

		// Query box: speed in [23, 33] during June 3 and 4, 2020
		Pointer query = tbox_in("TBOXFLOAT XT([23, 33],[2020-06-03, 2020-06-05))");
		Set<Integer> candidates = new TreeSet<>();
		for (TripsInSpeedTimeTile tilePointer : tilePointers) {
			if (tilePointer.getCount() > 0 &&
					overlaps_tbox_tbox(tilePointer.getTilePtr(), query)) {
				System.out.printf("Tile %d: %s, %d trips%n", tilePointer.getId(),
						tbox_out(tilePointer.getTilePtr(), 0), tilePointer.getTripIds().size());
				candidates.addAll(tilePointer.getTripIds());
			}
		}
		System.out.printf("%d candidate trips: %s%n", candidates.size(), candidates);

		// Candidates whose speed actually enters the query box
		int exact = 0;
		for (BerlinmodTripRecord tripRec : dataTrips)
			if (candidates.contains(tripRec.getId()) &&
					tnumber_at_tbox(tpoint_speed(tripRec.getTrip(), true), query) != null)
				exact++;
		System.out.printf("%d of them satisfy the query exactly%n", exact);
		GeneratedFunctions.meos_finalize();
	}
}
